# DeepSeek Harness macOS 版 1.0.0

首个公开版本把 Dock 启动入口、菜单栏小鲸鱼、服务控制和可选的应用内窗口合并为一个原生双语 macOS 应用。

## 主要特性

- 在所选浏览器可检测时，优先复用已有 Harness 页面或窗口。
- 记住浏览器或应用内模式，点击 Dock 不再反复询问。
- 关闭应用内窗口后，菜单栏控制器继续保留。
- 同时检查端口监听和 HTTP 响应，再判断服务是否健康。
- 保护 3080 端口上的无关进程，并在操作外部启动的服务前确认。
- 支持英文和简体中文，自动跟随 macOS 亮色/深色外观。
- 同一个通用包支持 Apple 芯片和 Intel Mac。

## 安装

从本 Release 下载 `DeepSeek-Harness-1.0.0-macOS.zip` 和校验文件。解压完整文件夹，按住 Control 点击 `install.command`，选择**打开**。

需要 macOS 13 或更高版本；首次安装时需要联网。

## 签名提示

本版本使用 ad-hoc 临时签名，尚未经过 Apple 公证。macOS 可能提示“无法验证开发者”。请使用 Control 点击**打开**，或前往**系统设置 → 隐私与安全性 → 仍要打开**。不要全局关闭 Gatekeeper。

## 完整性校验

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.0-macOS.zip.sha256
```

这是独立社区项目，不隶属于 DeepSeek。

