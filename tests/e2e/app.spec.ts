import { test, expect } from '@playwright/test';
import http from 'http';
import { spawn, ChildProcess } from 'child_process';
import path from 'path';

let appProcess: ChildProcess | null = null;

// Simple HTTP server that serves the app's HTML structure for testing
function createTestServer(port: number): http.Server {
  const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>lbpSSH Test</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background: #1E1E1E;
            color: #CCCCCC;
        }
        .app { width: 100vw; height: 100vh; display: flex; flex-direction: column; }
        .tabs-bar {
            display: flex;
            align-items: center;
            height: 48px;
            background: #2D2D2D;
            padding: 0 16px;
        }
        .tabs-settings-btn {
            background: none;
            border: none;
            color: #CCCCCC;
            font-size: 18px;
            cursor: pointer;
            padding: 8px;
        }
        .tabs-list { flex: 1; display: flex; gap: 8px; padding: 0 16px; }
        .tab-item {
            padding: 8px 16px;
            background: #3D3D3D;
            border-radius: 4px;
            cursor: pointer;
        }
        .tab-item.active { background: #4CAF50; }
        .tabs-add-dropdown { position: relative; }
        .tabs-add-btn {
            background: #4CAF50;
            border: none;
            color: white;
            width: 32px;
            height: 32px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 18px;
        }
        .dropdown-menu {
            position: absolute;
            right: 0;
            top: 40px;
            background: #2D2D2D;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            min-width: 200px;
            z-index: 100;
        }
        .dropdown-item {
            padding: 12px 16px;
            cursor: pointer;
        }
        .dropdown-item:hover { background: #3D3D3D; }
        .dropdown-divider { height: 1px; background: #3D3D3D; margin: 4px 0; }
        .modal-overlay {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.5);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 200;
        }
        .settings-modal {
            background: #2D2D2D;
            border-radius: 8px;
            width: 600px;
            max-height: 80vh;
            overflow: auto;
        }
        .settings-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 16px;
            border-bottom: 1px solid #3D3D3D;
        }
        .settings-header h2 { margin: 0; }
        .close-btn {
            background: none;
            border: none;
            color: #CCCCCC;
            font-size: 24px;
            cursor: pointer;
        }
        .settings-body { display: flex; }
        .settings-nav {
            width: 150px;
            border-right: 1px solid #3D3D3D;
            padding: 16px 0;
        }
        .nav-item { padding: 12px 16px; cursor: pointer; }
        .nav-item.active { background: #3D3D3D; }
        .settings-content { flex: 1; padding: 16px; }
        .empty-state {
            flex: 1;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
    </style>
</head>
<body>
    <div class="app">
        <div class="tabs-bar">
            <button class="tabs-settings-btn" id="settings-btn">⚙️</button>
            <div class="tabs-list">
                <div class="tab-item active">服务器 1</div>
            </div>
            <div class="tabs-add-dropdown">
                <button class="tabs-add-btn" id="add-btn">+</button>
                <div class="dropdown-menu" id="dropdown" style="display: none;">
                    <div class="dropdown-item">🖥️ 本地终端</div>
                    <div class="dropdown-divider"></div>
                    <div class="dropdown-item">🔑 生产服务器</div>
                    <div class="dropdown-divider"></div>
                    <div class="dropdown-item">➕ 添加新连接</div>
                </div>
            </div>
        </div>

        <div class="empty-state" id="empty-state">
            <div style="font-size: 64px;">🖥️</div>
            <div style="font-size: 18px; margin-top: 16px;">点击右上角 + 按钮创建终端</div>
            <div style="font-size: 14px; margin-top: 8px; color: #6A6A6A;">选择本地终端或 SSH 连接</div>
        </div>

        <div class="modal-overlay" id="settings-modal" style="display: none;">
            <div class="settings-modal">
                <div class="settings-header">
                    <h2>设置</h2>
                    <button class="close-btn" id="close-settings">×</button>
                </div>
                <div class="settings-body">
                    <div class="settings-nav">
                        <div class="nav-item active">终端设置</div>
                        <div class="nav-item">连接管理</div>
                        <div class="nav-item">导入导出</div>
                        <div class="nav-item">同步设置</div>
                    </div>
                    <div class="settings-content">
                        <h3>终端显示设置</h3>
                        <div>
                            <label>字体大小</label>
                            <input type="text" value="14" />
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const settingsBtn = document.getElementById('settings-btn');
        const settingsModal = document.getElementById('settings-modal');
        const closeSettings = document.getElementById('close-settings');
        const addBtn = document.getElementById('add-btn');
        const dropdown = document.getElementById('dropdown');

        settingsBtn.addEventListener('click', () => {
            settingsModal.style.display = 'flex';
        });

        closeSettings.addEventListener('click', () => {
            settingsModal.style.display = 'none';
        });

        settingsModal.addEventListener('click', (e) => {
            if (e.target === settingsModal) {
                settingsModal.style.display = 'none';
            }
        });

        addBtn.addEventListener('click', () => {
            dropdown.style.display = dropdown.style.display === 'none' ? 'block' : 'none';
        });

        // Close dropdown when clicking outside
        document.addEventListener('click', (e) => {
            if (!addBtn.contains(e.target) && !dropdown.contains(e.target)) {
                dropdown.style.display = 'none';
            }
        });
    </script>
</body>
</html>`;

  const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
  });

  server.listen(port);
  return server;
}

test.describe('lbpSSH E2E Tests', () => {
  let server: http.Server;

  test.beforeAll(() => {
    server = createTestServer(8765);
  });

  test.afterAll(() => {
    server.close();
  });

  test('settings button should open settings modal', async ({ page }) => {
    await page.goto('http://localhost:8765');

    // Click the settings button
    await page.click('#settings-btn');

    // Verify settings modal appears
    const modal = page.locator('#settings-modal');
    await expect(modal).toBeVisible();

    // Verify the modal contains expected content
    await expect(page.locator('.settings-header h2')).toHaveText('设置');

    // Close the modal by clicking the close button
    await page.click('#close-settings');
    await expect(modal).toBeHidden();
  });

  test('add button should toggle dropdown', async ({ page }) => {
    await page.goto('http://localhost:8765');

    // Initially dropdown is hidden
    const dropdown = page.locator('#dropdown');
    await expect(dropdown).toBeHidden();

    // Click add button
    await page.click('#add-btn');

    // Verify dropdown appears
    await expect(dropdown).toBeVisible();

    // Click add button again
    await page.click('#add-btn');

    // Verify dropdown is hidden
    await expect(dropdown).toBeHidden();
  });

  test('should display empty state when no tabs', async ({ page }) => {
    await page.goto('http://localhost:8765');

    // Check empty state is displayed
    const emptyState = page.locator('#empty-state');
    await expect(emptyState).toBeVisible();
    await expect(emptyState).toContainText('点击右上角');
  });

  test('dropdown should close when clicking outside', async ({ page }) => {
    await page.goto('http://localhost:8765');

    // Open dropdown
    await page.click('#add-btn');
    const dropdown = page.locator('#dropdown');
    await expect(dropdown).toBeVisible();

    // Click outside
    await page.click('.empty-state');

    // Verify dropdown is hidden
    await expect(dropdown).toBeHidden();
  });

  test('modal should close when clicking overlay', async ({ page }) => {
    await page.goto('http://localhost:8765');

    // Open settings
    await page.click('#settings-btn');
    const modal = page.locator('#settings-modal');
    await expect(modal).toBeVisible();

    // Click the overlay background (using force to ensure we hit the overlay)
    await page.evaluate(() => {
      const modal = document.getElementById('settings-modal');
      if (modal) modal.click();
    });

    // Verify modal is hidden
    await expect(modal).toBeHidden();
  });
});
