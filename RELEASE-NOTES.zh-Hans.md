# DeepSeek Harness macOS 版 1.0.2

这是一个可靠性更新，防止不兼容的 DSH 或 Node.js 更新替换原本可用的托管运行环境。

## 已修复

- 将可复用 Node.js 的限制从简单的主版本判断改为完整的 `22.19.0` 最低版本，避免需要 Node.js 22.19+ 的 DSH 依赖被 Node.js 22.14 启动。
- 托管 DSH 更新在正式启用前，必须先使用当前 Profile 完成启动、返回本地 Harness 页面，并通过所有已声明插件资源检查。
- 如果检测到插件或 Profile API 不兼容，继续使用原有托管 DSH，不会把失败的候选版本设为当前环境。
- 除 Homebrew、npm、nvm、fnm、Volta、asdf、mise、nodenv 和 MacPorts 外，新增常见 DSH 私有 Node 运行时路径检测。

## 兼容基线

- macOS 13 或更高版本，支持 Apple 芯片和 Intel Mac。
- 可复用 Node.js：`22.19.0` 或更高版本。
- 私有备用 Node.js：`22.21.1`。
- 已验证 DSH 全新安装与恢复基线：`0.1.1-rc.2`。

菜单中的 DSH 更新检查仍然只由用户主动触发。不会后台静默安装 npm `latest`；无法使用当前 Profile 启动的候选版本不会被启用。

## 安装

下载 `DeepSeek-Harness-1.0.2-macOS.dmg`，打开后把 **DeepSeek Harness** 拖到 **Applications**。出现提示时替换旧版本。偏好设置、已选运行环境记录和 `~/.dsh` 数据都在 App 包外，会继续保留。

此版本使用 ad-hoc 临时签名，尚未经过 Apple 公证。请按住 Control 点击已安装的 App 并选择**打开**，或前往**系统设置 → 隐私与安全性 → 仍要打开**。不要全局关闭 Gatekeeper。

## 完整性校验

```sh
shasum -a 256 -c DeepSeek-Harness-1.0.2-macOS.dmg.sha256
```

这是独立社区项目，与 DeepSeek 无隶属或合作关系。
