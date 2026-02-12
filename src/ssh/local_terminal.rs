use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use thiserror::Error;

/// 本地终端错误
#[derive(Debug, Error)]
pub enum LocalTerminalError {
    #[error("无法创建 PTY: {0}")]
    PtyCreationFailed(String),

    #[error("无法启动 shell: {0}")]
    ShellStartupFailed(String),

    #[error("发送输入失败: {0}")]
    SendInputFailed(String),

    #[error("读取输出失败: {0}")]
    ReadOutputFailed(String),

    #[error("停止终端失败: {0}")]
    StopFailed(String),

    #[error("IO 错误: {0}")]
    IoError(#[from] std::io::Error),
}

/// 本地终端服务
pub struct LocalTerminalService {
    shell_path: String,
    #[allow(dead_code)]
    child: Option<std::process::Child>,
    sender: mpsc::Sender<String>,
    #[allow(dead_code)]
    receiver: mpsc::Receiver<String>,
    #[allow(dead_code)]
    output_thread: Option<thread::JoinHandle<()>>,
}

impl LocalTerminalService {
    /// 检测默认 shell 路径
    pub fn detect_shell() -> String {
        std::env::var("SHELL").unwrap_or_else(|_| {
            #[cfg(target_os = "macos")]
            {
                "/bin/zsh".to_string()
            }
            #[cfg(target_os = "linux")]
            {
                if std::path::Path::new("/bin/bash").exists() {
                    "/bin/bash".to_string()
                } else if std::path::Path::new("/bin/sh").exists() {
                    "/bin/sh".to_string()
                } else {
                    "/bin/bash".to_string()
                }
            }
            #[cfg(target_os = "windows")]
            {
                "powershell.exe".to_string()
            }
        })
    }

    /// 创建新的本地终端服务
    pub fn new(shell_path: Option<String>) -> Result<Self, LocalTerminalError> {
        let shell = shell_path.unwrap_or_else(|| Self::detect_shell());

        // 创建管道用于进程间通信
        let (sender, receiver) = mpsc::channel();
        let (child_stdout_sender, _) = mpsc::channel();

        // 启动 shell 进程
        let mut child = Command::new(&shell)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| LocalTerminalError::ShellStartupFailed(e.to_string()))?;

        // 读取输出的线程
        let output_thread = {
            let mut child_stdout = child.stdout.take().unwrap();
            let sender = child_stdout_sender;

            thread::spawn(move || {
                let mut buffer = [0u8; 1024];
                loop {
                    match child_stdout.read(&mut buffer) {
                        Ok(0) => break, // EOF
                        Ok(n) => {
                            let s = String::from_utf8_lossy(&buffer[..n]).into_owned();
                            if sender.send(s).is_err() {
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                }
            })
        };

        Ok(Self {
            shell_path: shell,
            child: Some(child),
            sender,
            receiver,
            output_thread: Some(output_thread),
        })
    }

    /// 发送输入到终端
    pub fn send_input(&mut self, input: &str) -> Result<(), LocalTerminalError> {
        if let Some(ref mut child) = self.child {
            if let Some(ref mut stdin) = child.stdin {
                stdin.write_all(input.as_bytes())
                    .map_err(|e| LocalTerminalError::SendInputFailed(e.to_string()))?;
                stdin.flush()
                    .map_err(|e| LocalTerminalError::SendInputFailed(e.to_string()))?;
                Ok(())
            } else {
                Err(LocalTerminalError::SendInputFailed("stdin not available".to_string()))
            }
        } else {
            Err(LocalTerminalError::SendInputFailed("process not running".to_string()))
        }
    }

    /// 发送回车键
    pub fn send_enter(&mut self) -> Result<(), LocalTerminalError> {
        self.send_input("\n")
    }

    /// 发送 Ctrl+C
    pub fn send_ctrl_c(&mut self) -> Result<(), LocalTerminalError> {
        self.send_input("\x03") // ETX
    }

    /// 尝试读取输出
    pub fn try_read_output(&mut self) -> Option<String> {
        self.receiver.try_recv().ok()
    }

    /// 检查进程是否还在运行
    #[allow(dead_code)]
    pub fn is_running(&mut self) -> bool {
        if let Some(ref mut child) = self.child {
            child.try_wait().unwrap_or(None).is_none()
        } else {
            false
        }
    }

    /// 停止终端
    pub fn stop(&mut self) -> Result<(), LocalTerminalError> {
        // 先尝试发送 Ctrl+C
        let _ = self.send_ctrl_c();

        if let Some(mut child) = self.child.take() {
            // 强制终止进程
            child.kill()
                .map_err(|e| LocalTerminalError::StopFailed(e.to_string()))?;
            child.wait()
                .map_err(|e| LocalTerminalError::StopFailed(e.to_string()))?;
        }

        // 等待输出线程结束
        if let Some(thread) = self.output_thread.take() {
            let _ = thread.join();
        }

        Ok(())
    }

    /// 获取 shell 路径
    pub fn shell_path(&self) -> &str {
        &self.shell_path
    }
}

impl Drop for LocalTerminalService {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

/// 简单的终端模拟器（不依赖 PTY）
pub struct SimpleTerminal {
    shell_path: String,
    #[allow(dead_code)]
    child: Option<std::process::Child>,
}

impl SimpleTerminal {
    /// 创建新的简单终端
    pub fn new(shell_path: Option<String>) -> Result<Self, LocalTerminalError> {
        let shell = shell_path.unwrap_or_else(|| LocalTerminalService::detect_shell());

        // 使用 shell -c 启动一个简单的交互式会话
        let child = Command::new(&shell)
            .args(&["-i", "-l"]) // 交互式登录 shell
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| LocalTerminalError::ShellStartupFailed(e.to_string()))?;

        Ok(Self {
            shell_path: shell,
            child: Some(child),
        })
    }

    /// 发送命令并读取输出
    pub fn execute_command(&mut self, command: &str) -> Result<String, LocalTerminalError> {
        if let Some(ref mut child) = self.child {
            // 发送命令
            if let Some(ref mut stdin) = child.stdin {
                stdin.write_all(command.as_bytes())?;
                stdin.write_all(b"\n")?;
                stdin.flush()?;
            }

            // 读取输出
            let mut output = String::new();
            if let Some(ref mut stdout) = child.stdout {
                stdout.read_to_string(&mut output)?;
            }

            Ok(output)
        } else {
            Err(LocalTerminalError::ShellStartupFailed("process not running".to_string()))
        }
    }

    /// 获取 shell 路径
    pub fn shell_path(&self) -> &str {
        &self.shell_path
    }

    /// 停止终端
    pub fn stop(&mut self) -> Result<(), LocalTerminalError> {
        if let Some(mut child) = self.child.take() {
            child.kill()?;
            child.wait()?;
        }
        Ok(())
    }
}

impl Drop for SimpleTerminal {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}
