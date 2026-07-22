# 全文复制助手（macOS）v0.2

这是一个本机运行的 macOS 应用，用于在任意应用中读取选中文本或当前文档全文，并写入系统剪贴板。

## v0.2 修复

第一版被配置成纯菜单栏应用，双击后不会弹窗口，也不会出现在 Dock。菜单栏图标如果被隐藏，会让人误以为没有启动。

v0.2 改为：

- 双击后一定显示“全文复制助手”控制面板；
- 同时显示 Dock 图标和菜单栏剪贴板图标；
- 再次点击 Dock 图标会重新显示控制面板；
- 控制面板直接显示辅助功能权限状态和快捷键；
- 保留菜单栏常驻能力。

## 构建与安装

```bash
cd FullCopyMac
chmod +x build.sh install.sh run-debug.sh
./build.sh
./install.sh
```

生成位置：

```text
dist/全文复制助手.app
```

安装位置：

```text
/Applications/全文复制助手.app
```

## 首次授权

1. 双击打开“全文复制助手”。
2. 在控制面板点击“申请辅助功能权限”。
3. 进入“系统设置 → 隐私与安全性 → 辅助功能”。
4. 打开“全文复制助手”。
5. 退出应用后重新打开一次。

## 快捷键

- `Control + Option + C`：复制当前选中文本。
- `Control + Option + A`：复制当前文档全文。

关闭控制面板不会退出程序。退出时点击菜单栏剪贴板图标，再选择“退出全文复制助手”。

## 点击后仍然没有窗口

在项目目录执行：

```bash
./run-debug.sh
```

该命令会以前台方式运行程序。若程序崩溃，终端会直接显示具体错误。

也可以检查进程：

```bash
pgrep -fl FullCopy
```

清理旧版本后重新安装：

```bash
pkill -x FullCopy 2>/dev/null || true
rm -rf "/Applications/全文复制助手.app"
./build.sh
./install.sh
```

## 系统要求

- macOS 13 或更高版本；
- Xcode Command Line Tools。

没有 Swift 环境时执行：

```bash
xcode-select --install
```

## 边界

应用可以在所有软件中触发，但目标软件不一定向 macOS 暴露完整文本。Canvas、图片、扫描 PDF、远程桌面和部分虚拟列表无法保证读取全文。剪贴板回读校验只证明已经完整写入“提取到的内容”，不能证明目标软件暴露了全部文档。
