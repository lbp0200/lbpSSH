# SSH 输入字符重复问题记录

## 问题现象

连接远程服务器后，输入 `ls` 终端显示 `lls`（`l` 被重复一次），本地终端正常。

## 根因

macOS 上 Flutter 对每次物理键盘按键同时触发**两条独立输入路径**：

| 路径 | 触发机制 | 终端处理 | 效果 |
|------|---------|---------|------|
| **Focus 系统** | macOS KeyDown 事件 | `_handleKeyEvent` → `keyInput()` → `onOutput` | 处理特殊键（方向键、Ctrl+U 等） |
| **TextInput 系统** | macOS `insertText:` | `updateEditingValue` → `_onInsert()` → `textInput()` → `onOutput` | 处理文本字符 |

kterm 的 `CustomTextEdit` 同时建立了这两条路径。对于字母键（如 `l`）：
- `_handleKeyEvent` 返回 `ignored`（keytab 不处理字母）→ 不走 `keyInput`
- `_onInsert` 执行 → `keyInput` 失败 → 回退 `textInput` → 发一次 `l`

所以**字母键本身不会重复**。重复发生在**特殊键**（Backspace 等）上：
- `_handleKeyEvent` 处理成功 → `keyInput` → `onOutput("\x7f")`
- `onDelete` 回调也调用 `keyInput(backspace)` → `onOutput("\x7f")` 又发一次

对于 SSH 远程服务器，每次 `\x7f` 都被 shell 处理并回显 → 用户看到两次字符效果。

## 修复方案

`hardwareKeyboardOnly: true` — 使用 `CustomKeyboardListener` 替代 `CustomTextEdit`。

`CustomKeyboardListener` 的 `_onKeyEvent` 有正确的守卫逻辑：
```
onKeyEvent 返回 handled → 不触发 onInsert（特��键）
onKeyEvent 返回 ignored → 回退 onInsert（字母键）
```

只有**一条路径**，字符只发一次。

### 副作用

IME（中文输入法）在终端内失效。因为 `CustomKeyboardListener` 不建立 `TextInputClient` 连接，`updateEditingValue` 不会触发。

## 尝试过但失败的方案

### ❌ 方案1: 修改 CustomTextEditState 添加 `_lastKeyEventHandled` 标记

在 `_onKeyEvent` 中记录按键是否被处理，`updateEditingValue` 中跳过已处理的键。

失败原因：标记状态在事件时序交错时不可靠，导致本地终端也出现字符重复。

### ❌ 方案2: 在 onOutput 回调做 5ms 去重

过滤 5ms 内相同的重复 `onOutput` 数据。

失败原因：误杀正常快速输入，backspace 失效。

## 测试局限性

这类 bug 无法通过自动化测试保证质量，原因：

1. **Flutter widget test** — headless 模式没有 `TextInputClient` 连接，不触发 `updateEditingValue`
2. **Flutter integration test** — `testDriver.enterText()` 走虚拟键盘路径，不是物理键盘
3. **macOS 嵌入层行为** — `insertText:` + KeyDown 的并行触发时序只有真实 macOS + 物理键盘才能复现

能做的防御手段：
- 代码审查时注意 `_onInsert` 和 `_handleKeyEvent` 是否覆盖同一组按键
- macOS 上 Focus 和 TextInput 是两套独立路径，同时走两条路的代码要警惕
- 架构上切断不可控路径（`hardwareKeyboardOnly: true`），而非在数据层修补

## 后续方向

- 给 `hardwareKeyboardOnly` 加个配置开关，让需要 IME 的用户可以切换
- 或者修复 kterm 的 `_onInsert` 方法，使其不再重复调用 `keyInput`/`textInput`

## 核心教训

这类问题的根治思路：**在架构层堵死不可控路径，而非在数据层修补。**

| 方案 | 拦截位置 | 可靠性 | 备注 |
|------|---------|--------|------|
| `hardwareKeyboardOnly: true` | 上游 — 不建立 TextInputClient | ✅ 彻底 | 牺牲 IME |
| 嵌入层拦截 `insertText:` | 上游 — macOS 插件层 | ✅ 彻底 | 需改 Flutter 插件 |
| `_lastKeyEventHandled` 标记 | 中游 — kterm 逻辑 | ❌ 时序不可靠 | 试过，失败 |
| 5ms 去重 | 下游 — onOutput 回调 | ❌ 误杀 | 试过，失败 |

