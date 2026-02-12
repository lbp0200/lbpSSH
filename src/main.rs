use dioxus::prelude::*;
use dioxus_desktop::{Config, WindowBuilder};
use dioxus_desktop::launch::launch;
use dioxus_desktop::LogicalSize;
use std::sync::Arc;
use std::sync::atomic::{AtomicPtr, Ordering};
use std::sync::RwLock;

mod app;
mod models;
mod components;
mod ssh;
mod utils;

#[cfg(test)]
mod tests;

use app::App;
use models::config::ConfigModel;

// Global config storage
static CONFIG_PTR: AtomicPtr<Arc<RwLock<ConfigModel>>> = AtomicPtr::new(std::ptr::null_mut());

/// Initialize global config
fn init_config(config: Arc<RwLock<ConfigModel>>) {
    let boxed = Box::into_raw(Box::new(config));
    CONFIG_PTR.store(boxed, Ordering::Relaxed);
}

/// Get config from global storage
pub fn get_config() -> Arc<RwLock<ConfigModel>> {
    let ptr = CONFIG_PTR.load(Ordering::Relaxed);
    if ptr.is_null() {
        panic!("Config not initialized");
    }
    unsafe { Arc::clone(&*ptr) }
}

/// Provider component for config context
#[component]
fn ConfigProvider(children: Element) -> Element {
    let config = get_config();
    provide_context(config);
    children
}

fn main() {
    env_logger::init();
    let config = Arc::new(RwLock::new(ConfigModel::load().unwrap_or_default()));

    // Initialize global config
    init_config(config.clone());

    // Read CSS file
    let css = std::fs::read_to_string("src/components/terminal.css")
        .unwrap_or_else(|_| String::new());

    // Get window config
    let window_config = {
        let config_guard = config.read().unwrap_or_else(|_| {
            panic!("Failed to lock config for reading");
        });
        config_guard.window.clone()
    };

    // Create window builder with saved settings
    let window_builder = WindowBuilder::default()
        .with_title("lbpSSH")
        .with_inner_size(LogicalSize::new(
            window_config.width as f64,
            window_config.height as f64,
        ))
        .with_maximized(window_config.maximized);

    launch(
        || {
            rsx! {
                ConfigProvider {
                    App {}
                }
            }
        },
        vec![],
        vec![
            Box::new(
                Config::default()
                    .with_window(window_builder)
                    .with_custom_head(format!(r#"<style>{}</style>"#, css)),
            ) as Box<dyn std::any::Any>
        ],
    );
}
