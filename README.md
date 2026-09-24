# Agent 就业教材 · iOS 版

把整本教材封成一个离线 iOS App，用 GitHub 的云端 Mac 编译，再用 AltStore 装到 iPhone 上。
**不需要本地装 Xcode。**

## 这个仓库里有什么

| 目录 | 说明 |
| --- | --- |
| `AgentBook/` | SwiftUI 工程（教材本体打包在里面，离线可用） |
| `web/` | 同一个教材的网页版，可以托管成 PWA（备用方案） |
| `.github/workflows/build-ipa.yml` | 云端编译流水线：推送后自动产出 `.ipa` |
| `路2-云端编译与侧载.md` | 从零开始的操作步骤 |
| `安装说明.md` | 本地装 Xcode 的路线（有 Apple 芯片 Mac 时走这条更省事） |
| `Intel-Mac 备选方案.md` | 三条路的对比与选择 |

## 快速开始

1. 在 GitHub 新建仓库（Public 或 Private 都行），把本目录内容推上去
2. 打开仓库的 **Actions** 标签，等「云端编译 IPA」跑完（约 3-6 分钟）
3. 在该次运行的页面底部下载 **AgentBook-ipa** 产物，解压得到 `AgentBook.ipa`
4. 用 AltStore 把它装到 iPhone 上（详细步骤见 `路2-云端编译与侧载.md`）

## 为什么产物不需要签名

流水线里显式关掉了签名（`CODE_SIGNING_ALLOWED=NO`），产出的是**未签名 IPA**。
签名由 AltStore 在安装时用你自己的 Apple ID 完成——所以不需要开发者账号，也不需要证书。

## 免费 Apple ID 的限制

- 同时最多 3 个自签 App
- 7 天有效期，由 AltStore 自动续签（电脑上的 AltServer 在线即可）
- Apple ID 需要开启双重认证

## 内容

34 章正文 · 49 个可拖动旋转的三维演示 · 34 个交互动画 ·
324 道自测题（含答案与错题本）· 263 张术语闪卡 · 18 处面试话术演练
