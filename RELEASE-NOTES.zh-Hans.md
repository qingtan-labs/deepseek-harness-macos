# DeepSeek Harness macOS 版 1.0.3

此兼容性版本让轻量 macOS 控制器适配官方 DSH 0.2 自带的鉴权 Web 客户端。

## 已修复

- 在检查或打开客户端前，读取并严格校验 DSH 0.2 为当前服务生成的本机鉴权地址。
- DSH 服务令牌变化时，对复用的 Safari 或 Chromium 标签完成一次重新鉴权；之后点击 Dock 仍只聚焦现有标签，不重复新建。
- 应用内 WebKit 窗口使用相同的鉴权交接，并正确处理服务重启后的新令牌。
- 运行环境候选版本检查支持 DSH 0.2 令牌握手、本机 Cookie，以及绝对和相对两种插件资源路径。
- 源码目录安装器会分别校验 Apple 芯片和 Intel 二进制切片。

## 更新基线

- 全新安装或恢复安装现在使用官方 `@deepseek-ai/dsh@0.2.0-rc.2`。
- 已有兼容的 DSH `0.2.0-rc.2` 或更高版本、Node.js `22.19.0` 或更高版本仍会直接复用，不重复替换。
- 控制器继续保持轻量：完整客户端由 `dsh web` 提供，不内置另一套或经过修改的 Web 客户端。

控制器升级不会替换 App 包外 `~/.dsh` 中的 Profile、会话、插件和凭据。

## 兼容基线

- macOS 13 或更高版本，支持 Apple 芯片和 Intel Mac。
- 可复用 Node.js：`22.19.0` 或更高版本。
- 私有备用 Node.js：`22.21.1`。
- 已验证 DSH 全新安装与恢复基线：`0.2.0-rc.2`。

## 安装

下载 `DeepSeek-Harness-1.0.3-macOS.dmg`，打开后把 **DeepSeek Harness** 拖到 **Applications**。出现提示时替换旧版本。

此版本使用 ad-hoc 临时签名，尚未经过 Apple 公证。请按住 Control 点击已安装的 App 并选择**打开**，或前往**系统设置 → 隐私与安全性 → 仍要打开**。不要全局关闭 Gatekeeper。

## 完整性校验

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.3-macOS.dmg.sha256
```

这是独立社区项目，与 DeepSeek 无隶属或合作关系。
