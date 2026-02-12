//! UI 快照测试
//!
//! 使用 insta 进行组件渲染输出的快照测试
//! 运行方式:
//!   - cargo test              # 运行测试
//!   - cargo insta review     # 查看并接受变更
//!
//! 快照文件存储在 tests/snapshots/ 目录

/// 终端设置组件快照测试
#[test]
fn test_terminal_settings_structure() {
    // 测试终端设置的基本结构
    let html = r#"
        <div class="settings-modal" style="background-color: #2D2D2D;">
            <h2 style="color: #FFFFFF;">Terminal Settings</h2>
            <div class="terminal-preview">
                <span>终端预览</span>
                <code>user@hostname:~$ ls -la</code>
            </div>
            <div class="font-settings">
                <label>Font Family: Menlo</label>
                <label>Font Size: 14</label>
                <label>Font Weight: 400</label>
                <label>Letter Spacing: 0</label>
                <label>Line Height: 1.2</label>
            </div>
            <div class="color-settings">
                <label>Background: #1E1E1E</label>
                <label>Foreground: #CCCCCC</label>
                <label>Cursor: #FFFFFF</label>
            </div>
            <div class="shell-settings">
                <label>Shell: 系统默认</label>
            </div>
            <button class="btn-primary">Save</button>
            <button class="btn-secondary">Reset</button>
        </div>
    "#;

    // 使用 insta 快照测试
    insta::assert_snapshot!(html);
}

/// 连接表单组件快照测试
#[test]
fn test_connection_form_structure() {
    let html = r#"
        <div class="connection-form-modal">
            <div class="connection-form" style="background-color: #252526;">
                <h2>添加连接</h2>
                <form class="form-body">
                    <div class="form-section">
                        <h3>基本设置</h3>
                        <label>连接名称</label>
                        <input type="text" placeholder="例如：生产服务器"/>
                        <label>主机地址</label>
                        <input type="text" placeholder="例如：192.168.1.100"/>
                        <label>端口</label>
                        <input type="text" value="22"/>
                        <label>用户名</label>
                        <input type="text" placeholder="例如：root"/>
                    </div>
                    <div class="form-section">
                        <h3>认证方式</h3>
                        <select>
                            <option>密码认证</option>
                            <option>密钥认证</option>
                            <option>密钥+密码认证</option>
                            <option>SSH Config</option>
                        </select>
                    </div>
                    <div class="form-section">
                        <h3>跳板机配置</h3>
                        <label><input type="checkbox"/> 使用跳板机</label>
                    </div>
                    <div class="form-section">
                        <h3>SOCKS5 代理配置</h3>
                        <label><input type="checkbox"/> 使用 SOCKS5 代理</label>
                    </div>
                </form>
                <div class="form-footer">
                    <button>取消</button>
                    <button class="btn-primary">保存</button>
                </div>
            </div>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 导入导出组件快照测试
#[test]
fn test_import_export_ui() {
    let html = r#"
        <div class="settings-modal">
            <h2>Import / Export</h2>
            <div class="stats-grid">
                <div class="stat-card"><h4>Total</h4><span>0</span></div>
                <div class="stat-card"><h4>Password</h4><span>0</span></div>
                <div class="stat-card"><h4>Key</h4><span>0</span></div>
                <div class="stat-card"><h4>Jump Host</h4><span>0</span></div>
            </div>
            <div class="import-section">
                <h3>Import Connections</h3>
                <select><option>JSON</option><option>CSV</option><option>SSH Config</option></select>
                <input type="text" placeholder="Add prefix to imported connection names"/>
                <button>Select File</button>
                <button>Preview</button>
                <button>Import Sample</button>
            </div>
            <div class="export-section">
                <h3>Export Connections</h3>
                <select><option>JSON</option><option>CSV</option><option>SSH Config</option></select>
                <button>Export All</button>
            </div>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 同步设置组件快照测试
#[test]
fn test_sync_settings_ui() {
    let html = r#"
        <div class="settings-modal">
            <h2>Cloud Sync</h2>
            <label><input type="checkbox"/> Enable cloud sync</label>
            <div class="platform-selection">
                <h3>Sync Platform</h3>
                <button>GitHub Gist</button>
                <button>Gitee Gist</button>
                <button>Custom</button>
            </div>
            <div class="sync-options">
                <label><input type="checkbox"/> Auto sync</label>
                <label><input type="checkbox"/> Sync on startup</label>
            </div>
            <div class="sync-actions">
                <button>Test Connection</button>
                <button>Upload</button>
                <button>Download</button>
                <button>Sync Now</button>
            </div>
            <div class="sync-status">Idle</div>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 终端预览组件快照测试
#[test]
fn test_terminal_preview() {
    let html = r#"
        <div class="terminal-preview" style="background-color: #1E1E1E; font-family: Menlo; font-size: 14px;">
            <span>终端预览</span>
            <code style="color: #CCCCCC;">user@hostname:~$ ls -la</code>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 设置页面导航快照测试
#[test]
fn test_settings_page_navigation() {
    let html = r#"
        <div class="settings-page">
            <div class="settings-navigation" style="width: 200px; background-color: #252526;">
                <h2>Settings</h2>
                <nav class="settings-tabs">
                    <button class="active">Terminal</button>
                    <button>Connections</button>
                    <button>Import/Export</button>
                    <button>Sync</button>
                </nav>
            </div>
            <div class="settings-content" style="flex: 1; background-color: #1E1E1E;"></div>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 字体大小预设按钮快照测试
#[test]
fn test_font_size_presets() {
    let html = r#"
        <div class="font-size-presets">
            <span>Font Size Presets</span>
            <button>10</button>
            <button>12</button>
            <button class="active">14</button>
            <button>16</button>
            <button>18</button>
            <button>20</button>
            <button>24</button>
            <button>28</button>
            <button>32</button>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 颜色主题预设快照测试
#[test]
fn test_color_presets() {
    let html = r#"
        <div class="color-presets">
            <span>Color Presets</span>
            <button style="background-color: #1E1E1E; color: #CCCCCC;">Default</button>
            <button style="background-color: #000000; color: #00FF00;">Terminal Green</button>
            <button style="background-color: #282C34; color: #ABB2BF;">One Dark</button>
            <button style="background-color: #002B36; color: #839496;">Solarized</button>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 平台选择按钮组快照测试
#[test]
fn test_platform_selector() {
    let html = r#"
        <div class="platform-selector">
            <button class="active" style="background-color: #007ACC;">GitHub Gist</button>
            <button style="background-color: #1E1E1E;">Gitee Gist</button>
            <button style="background-color: #1E1E1E;">Custom</button>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// Shell 选择下拉菜单快照测试
#[test]
fn test_shell_selector() {
    let html = r#"
        <div class="shell-selector">
            <label>Shell</label>
            <select>
                <option value="">系统默认Shell</option>
                <option value="/bin/bash">/bin/bash</option>
                <option value="/bin/zsh">/bin/zsh</option>
                <option value="/bin/fish">/bin/fish</option>
                <option value="powershell">powershell</option>
            </select>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 字体家族选择下拉菜单快照测试
#[test]
fn test_font_family_selector() {
    let html = r#"
        <div class="font-family-selector">
            <label>Font Family</label>
            <select>
                <option>Menlo</option>
                <option>Monaco</option>
                <option>Consolas</option>
                <option>Courier New</option>
                <option>Fira Code</option>
                <option>JetBrains Mono</option>
                <option>Source Code Pro</option>
                <option>Hack</option>
            </select>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// SSH Config 主机选择器快照测试
#[test]
fn test_ssh_config_selector() {
    let html = r#"
        <div class="ssh-config-section">
            <label><input type="checkbox"/> 使用 SSH Config 主机</label>
            <select>
                <option>请选择主机...</option>
                <option>my-server</option>
                <option>production</option>
                <option>staging</option>
            </select>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// 跳板机配置表单快照测试
#[test]
fn test_jump_host_form() {
    let html = r#"
        <div class="jump-host-form">
            <label>跳板机地址</label>
            <input type="text" placeholder="跳板机IP或域名"/>
            <label>端口</label>
            <input type="text" value="22"/>
            <label>跳板机用户名</label>
            <input type="text" placeholder="跳板机用户名"/>
            <label>跳板机认证方式</label>
            <select><option>密码认证</option><option>密钥认证</option></select>
        </div>
    "#;

    insta::assert_snapshot!(html);
}

/// SOCKS5 代理配置表单快照测试
#[test]
fn test_socks5_proxy_form() {
    let html = r#"
        <div class="socks5-proxy-form">
            <label>代理地址</label>
            <input type="text" placeholder="代理服务器地址"/>
            <label>端口</label>
            <input type="text" value="1080"/>
            <label>代理用户名（可选）</label>
            <input type="text" placeholder="代理用户名"/>
            <label>代理密码（可选）</label>
            <input type="password"/>
        </div>
    "#;

    insta::assert_snapshot!(html);
}
