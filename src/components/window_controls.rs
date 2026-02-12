use dioxus::prelude::*;
use dioxus_desktop::use_window;

/// 窗口控制按钮组件（最小化、最大化、关闭）
#[component]
pub fn WindowControls() -> Element {
    let window = use_window();

    // 创建多个 clone 用于不同的闭包
    let window_minimize = window.clone();
    let window_maximize = window.clone();
    let window_close = window.clone();

    rsx! {
        div {
            class: "window-controls",
            button {
                class: "window-btn minimize",
                title: "最小化",
                onclick: move |_| {
                    let _ = window_minimize.set_minimized(true);
                },
                "─"
            },
            button {
                class: "window-btn maximize",
                title: "最大化",
                onclick: move |_| {
                    let _ = window_maximize.set_maximized(!window_maximize.is_maximized());
                },
                "□"
            },
            button {
                class: "window-btn close",
                title: "关闭",
                onclick: move |_| {
                    let _ = window_close.close();
                },
                "×"
            }
        }
    }
}
