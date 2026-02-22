# 可折叠连接列表侧边栏设计

## 背景

当前左侧连接列表固定 280px 宽度，用户认为文件传输（SFTP）不常用，不应占用这么多屏幕空间。需求将侧边栏改为可折叠形式。

## 设计目标

1. 侧边栏支持展开/折叠切换
2. 折叠状态下只显示图标，节省空间
3. 添加搜索功能，支持连接名称和 hostname/username

## UI/UX 设计

### 展开状态

- **宽度**：280px
- **布局**：
  - 顶部：搜索框 + 设置按钮
  - 中部：连接列表（可滚动）
  - 底部：折叠按钮（chevron_left）
- **搜索框**：
  - 支持模糊搜索
  - 搜索字段：连接名称、hostname、username
  - 无输入时显示完整列表

### 折叠状态

- **宽度**：60px
- **布局**：
  - 顶部：展开按钮（chevron_right）
  - 中部：连接图标列表（垂直排列，无文字）
  - 底部：搜索图标 + 设置图标
- **交互**：
  - 点击连接图标 → 打开终端
  - 点击文件夹图标 → 打开 SFTP（折叠状态显示在图标右侧，小尺寸）
  - 点击搜索图标 → 展开侧边栏并聚焦搜索框
  - 点击设置图标 → 展开侧边栏并打开设置

### 动画

- 展开/折叠使用 200ms ease-in-out 动画
- 宽度渐变，非瞬间切换

## 实现方案

### 组件修改

1. **新建 CollapsibleSidebar 组件**：封装展开/折叠逻辑
2. **修改 ConnectionList 组件**：支持紧凑模式（图标模式）
3. **添加搜索功能**：在 ConnectionProvider 中添加搜索过滤方法
4. **修改 MainScreen**：使用 CollapsibleSidebar 替代固定 SizedBox

### 状态管理

- 使用 StatefulWidget 内部状态管理展开/折叠
- 折叠状态可持久化到本地配置（非必须，首版可仅内存存储）

## 文件变更

1. `lib/presentation/widgets/collapsible_sidebar.dart` - 新建
2. `lib/presentation/widgets/connection_list.dart` - 修改，支持紧凑模式
3. `lib/presentation/screens/main_screen.dart` - 修改，使用新组件

## 验收标准

1. 侧边栏可以展开/折叠
2. 折叠状态只显示图标，宽度约 60px
3. 搜索可以过滤连接名称和 hostname/username
4. 设置按钮在展开和折叠状态下都可访问
