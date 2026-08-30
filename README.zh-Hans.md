<p align="center">
  <img src="assets/DeepSeekWhale.svg" width="128" alt="DeepSeek 小鲸鱼">
</p>

<h1 align="center">DeepSeek Harness macOS 版</h1>

<p align="center">把 DeepSeek Harness（DSH）的 Dock、菜单栏和本地服务合并成一个原生控制器。</p>

<p align="center">
  <a href="https://github.com/qingtan-labs/deepseek-harness-macos/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/qingtan-labs/deepseek-harness-macos?display_name=tag"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple">
  <img alt="Apple 芯片与 Intel" src="https://img.shields.io/badge/Mac-Apple%20silicon%20%7C%20Intel-111111">
  <a href="LICENSE"><img alt="MIT 协议" src="https://img.shields.io/badge/license-MIT-0b7285"></a>
</p>

<p align="center"><a href="README.md">English</a> · <strong>简体中文</strong></p>

<p align="center">
  <a href="https://github.com/qingtan-labs/deepseek-harness-macos/releases/latest/download/DeepSeek-Harness-1.0.0-macOS.zip"><strong>下载 DeepSeek Harness 1.0.0 macOS 版</strong></a>
</p>

DeepSeek Harness macOS 版是社区开发的辅助应用，把 Dock 启动入口、菜单栏控制、本地服务管理和可选的应用内窗口合并为一个程序。点击 Dock 时会优先聚焦已有 Harness 网页或窗口，而不是每次都故意新开一个标签页。

控制器只管理 `http://127.0.0.1:3080`，不会保存、转发或上传你的 DeepSeek 凭据。

> [!IMPORTANT]
> 这是独立社区项目，不是 DeepSeek 官方应用，也不隶属于 DeepSeek。DeepSeek 名称、标志和商标归其各自权利人所有。

## 可信项目入口

| 用途 | 地址 |
| --- | --- |
| 源代码 | [github.com/qingtan-labs/deepseek-harness-macos](https://github.com/qingtan-labs/deepseek-harness-macos) |
| 下载 | [GitHub Releases](https://github.com/qingtan-labs/deepseek-harness-macos/releases) |
| 帮助与问题反馈 | [GitHub Issues](https://github.com/qingtan-labs/deepseek-harness-macos/issues) |
| 安全问题 | [私密漏洞报告](https://github.com/qingtan-labs/deepseek-harness-macos/security/advisories/new) |

本项目完全免费且开源，绝不会要求你在 Issue 中发送 API Key、密码或登录验证码。

## 为什么使用它

- **一个程序、两个入口：** Dock 图标和菜单栏小鲸鱼属于同一个进程，不需要再启动第二个工具。
- **先复用、再新建：** 浏览器模式会在 Safari 和主流 Chromium 浏览器中查找已有本地标签；应用内模式会恢复同一个窗口和网页会话。
- **记住我的选择：** 浏览器或应用内窗口都可以保存为默认方式，并随时在菜单中修改。
- **理解服务状态：** HTTP 健康检查、端口冲突保护和服务所有权记录，可避免误停其他进程。
- **登录时静默启动：** 使用 macOS 登录项，只启动菜单栏控制器，不自动弹出页面。
- **原生双语与主题：** 支持英文和简体中文，界面自动跟随 Mac 的亮色/深色外观。
- **通用 Mac 包：** 同一个发布包支持 Apple 芯片和 Intel Mac。

## 系统要求

| 项目 | 要求 |
| --- | --- |
| macOS | 13 Ventura 或更高版本 |
| Mac | Apple 芯片或 Intel |
| 网络 | 首次安装时需要下载 Node.js 和 DSH |
| 本地地址 | `http://127.0.0.1:3080` |
| 运行时版本 | Node.js `22.21.1` |
| DSH 包版本 | `@deepseek-ai/dsh@0.1.1-rc.2` |

## 安装

1. 从 [GitHub Releases](https://github.com/qingtan-labs/deepseek-harness-macos/releases/latest) 下载最新 ZIP。
2. 解压完整文件夹，保持 `install.command` 与 `DeepSeek Harness.app` 在同一目录。
3. 按住 Control 点击 `install.command`，选择**打开**，再次确认**打开**，然后查看终端进度。
4. 全新安装会放到 `~/Applications`、加入 Dock 并启动同一个 Dock/菜单栏控制器；已有版本会在原位置升级。

安装器会校验应用，从 `nodejs.org` 下载 Node.js 并验证官方 SHA-256，再从 npm 安装固定版本的 DSH。正常的当前用户安装不会要求管理员权限。

### 1.0.0 的 Gatekeeper 提示

1.0.0 使用 ad-hoc 临时签名，尚未经过 Apple 公证，因此 macOS 可能提示“无法验证开发者”。请使用上面的 Control 点击**打开**流程；如果第一次已被拦截，也可以前往**系统设置 → 隐私与安全性 → 仍要打开**。

不要全局关闭 Gatekeeper。未来需要 Apple Developer ID 和公证，才能消除首次运行提示。

### 校验下载

下载 ZIP 旁边的 `.sha256` 文件，保持两者位于同一目录，然后执行：

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.0-macOS.zip.sha256
```

## 日常使用

- 点击 **Dock 图标**：按已保存的默认方式打开。
- 点击 **菜单栏小鲸鱼**：可以打开 Harness、仅本次使用备用方式、修改默认方式、查看服务状态、重启/停止服务、复制诊断信息或设置登录启动。
- **浏览器模式**：找到受支持的已有本地标签就聚焦，确认没有时才新建。
- **应用内模式**：关闭窗口只是隐藏窗口，菜单栏小鲸鱼和 Harness 服务继续保留。
- **退出 DeepSeek Harness**：退出控制器；服务启停是独立、明确的操作。

第一次复用浏览器时，macOS 可能请求“自动化”权限。它只用于查找并聚焦本机 `127.0.0.1:3080` 标签。如果某个浏览器无法可靠检测，请选择应用内窗口或保存程序提供的后备方案。

更多说明见[使用指南](docs/usage.md)、[安装说明](docs/installation.md)和[故障排查](docs/troubleshooting.md)。

## 隐私与安全

- 不包含分析统计、遥测、广告或自动更新追踪。
- 控制器只连接本地 Harness 地址；安装器只下载已声明的运行时依赖。
- 菜单复制的诊断信息包含运行状态，公开发布前请先检查。
- Harness 登录始终在本地 Harness 页面中完成，切勿把凭据粘贴到公开 Issue。

## 从源码构建

无需 Xcode 工程或第三方构建系统。macOS 13+ 安装 Command Line Tools 后执行：

```sh
git clone https://github.com/qingtan-labs/deepseek-harness-macos.git
cd deepseek-harness-macos
./scripts/build-release.command
```

通用、ad-hoc 签名的发布包与校验文件会生成到 `dist/`。构建过程会检查 plist、签名、CPU 架构和 ZIP 完整性。长期维护请阅读[架构说明](docs/architecture.md)、[维护指南](docs/maintenance.md)和[发布流程](docs/release-process.md)。

## 贡献与支持

欢迎通过 [GitHub Issues](https://github.com/qingtan-labs/deepseek-harness-macos/issues) 报告问题和提出需求。参与前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)、[SUPPORT.md](SUPPORT.md)、[行为准则](CODE_OF_CONDUCT.md)和[安全策略](SECURITY.md)。

Windows 版本计划放在独立仓库中，以保持不同平台的打包与交互边界清晰，目前不承诺发布日期。

## 开源协议

源代码使用 [MIT License](LICENSE)。第三方名称、标志、软件包与商标仍受其权利人的条款约束。

