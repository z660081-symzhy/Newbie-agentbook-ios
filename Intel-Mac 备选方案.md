# Intel Mac 上怎么用上方案 B

## 先把事实说清楚

你这台机器的实际情况（我直接查的）：

| 项目 | 值 |
| --- | --- |
| 机型 | MacBook Pro 13" 2020（四雷雳口），Intel Core i5 1.4GHz，8GB 内存 |
| 系统 | macOS **15.7.7** |
| App Store 里的 Xcode | 版本 **27.0**，最低要求 **macOS 26.6** |

**结论：从 App Store 装不了 Xcode —— 但不是因为 Intel，是因为系统版本不够。**
App Store 只提供最新版，而最新版要求 macOS 26.6。

不过方案 B 还有三条路，我按推荐顺序排：

---

## 路 1：装旧版 Xcode 16.x（最接近原计划，推荐先试）

旧版 Xcode 不走 App Store，而是去苹果开发者网站免费下载。
**Xcode 16 支持 macOS 14.5 以上 + Intel 芯片**，你这台机器正好在范围内。

### 前提条件（必须先确认）

**你的 iPhone 系统版本必须 ≤ iOS 18.x。**

因为 Xcode 16 带的是 iOS 18 SDK，如果你的 iPhone 已经升到 iOS 26，
Xcode 16 会拒绝往它上面装，报「iPhone is running a newer version of iOS」。

查看方法：iPhone → 设置 → 通用 → 关于本机 → 软件版本。

| 你的 iPhone 系统 | 能不能走路 1 |
| --- | --- |
| iOS 18.x 或更低 | ✅ 可以 |
| iOS 26.x | ❌ 不行，走 路 2 或 路 3 |

### 步骤

1. 浏览器打开 `https://developer.apple.com/download/all/`
2. 用你的 Apple ID 登录（免费账号就行，不用开发者账号）
3. 搜索框输入 `Xcode 16`，找到 **Xcode 16.4**（或列表里最新的 16.x），下载 `.xip`（约 10 GB）
4. 下载完双击解压，把解压出的 `Xcode.app` 拖进 `/Applications`
5. 终端里执行一次，让系统把命令行工具指向它：

       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

6. 打开 Xcode，同意许可协议，等它装完附加组件
7. 然后照 [安装说明.md](安装说明.md) 的第 2 步往下走

### 注意

- 8GB 内存跑 Xcode 16 会很吃力。建议：编译时关掉浏览器、微信等其他占内存的程序；第一次编译慢（十几分钟），之后增量编译快。
- 首次打开工程，Xcode 会提示更新项目设置，**一路点「Perform Changes」就行**，不用手动改。

---

## 路 2：云端编译 + 侧载（不依赖你 Mac 的性能，也不依赖系统版本）

思路：让 GitHub 的云端 Mac（Apple 芯片、配置很好）帮你编译出一个 `.ipa`，
然后用侧载工具装到 iPhone 上。**你这台 Intel Mac 只需要跑一个小工具，不需要 Xcode。**

我已经把编译流水线写好了：`.github/workflows/build-ipa.yml`

### 你需要准备

- 一个 GitHub 账号（免费）
- AltServer（免费，Mac / Windows 都能装，Intel 完全没问题）
- iPhone 上的 AltStore（免费）

### 步骤一：把工程传上 GitHub

1. 在 GitHub 新建一个仓库，勾 **Public**（私有仓库的 Actions 有额度限制，公开的完全免费）
2. 把 `ios` 文件夹里的内容传上去。**注意 `.github` 是隐藏文件夹**，
   Finder 里按 `⌘⇧.` 可以显示隐藏文件；
   或者干脆用终端推（在 `outputs/ios` 目录下执行）：

       git init
       git add -A
       git commit -m "Agent 就业教材 iOS 版"
       git branch -M main
       git remote add origin https://github.com/你的用户名/仓库名.git
       git push -u origin main

### 步骤二：等云端编译

推送完成后：

1. 打开仓库页面 → 上方 **Actions** 标签
2. 会看到「云端编译 IPA」这个任务在跑，**第一次大约 3-6 分钟**
3. 跑完点进去，页面底部 **Artifacts** 里下载 `AgentBook-ipa.zip`，解压得到 `AgentBook.ipa`

如果编译失败，把 Actions 里的红色日志发我，我来改代码。

### 步骤三：侧载到 iPhone

1. 电脑上装 **AltServer**（官网 `altstore.io`，Mac 版支持 Intel）
2. iPhone 连上同一个 Wi-Fi
3. iPhone 上用 Safari 打开 `altstore.io` → 下载安装 AltStore（首次需要 AltServer 在电脑上配合）
4. 把上一步下载的 `AgentBook.ipa` 拖给 AltStore（或用「My Apps → +」选择文件）
5. AltStore 会用你的 Apple ID 为它签名并安装

### 这条路的好处

- **不需要 Xcode**，不需要你的 Mac 有性能
- **不需要每周手动操作**：AltStore 会在后台自动续签（同一 Wi-Fi 下有 AltServer 在跑就行），
  比手动 ⌘R 还省事

### 限制（免费 Apple ID 的通用限制）

| 限制 | 说明 |
| --- | --- |
| 最多 3 个 App | 免费账号同时只能装 3 个自签 App，超了要删掉旧的 |
| 7 天有效期 | 由 AltStore 自动续签，但需要电脑上的 AltServer 在线（或者用 SideStore，配置更复杂但不需要常开电脑） |
| 必须开双重认证 | 你的 Apple ID 需要开启两步验证，这是 AltStore 的硬性要求 |

---

## 路 3：PWA（永远能用，配合任何设备）

不管上面两条路走不走得通，这条路都成立：把 `web/` 里的 6 个文件传到任意静态托管，
iPhone 用 Safari 打开、等 3 秒、添加到主屏幕。**完全离线、永不过期、不需要 Mac。**

详细步骤见 [安装说明.md](安装说明.md) 的「方案 A」一节。

---

## 三条路对比

| | 路 1 旧版 Xcode | 路 2 云端编译 | 路 3 PWA |
| --- | --- | --- | --- |
| 需要你的 Mac 装 Xcode | 要（旧版，10GB） | **不要** | 不要 |
| 需要 iPhone ≤ iOS 18 | **要** | 不要 | 不要 |
| 每周手动续签 | 要（⌘R） | 不要（自动） | 不需要 |
| 需要额外账号 | Apple ID | Apple ID + GitHub | 无 |
| 8GB 内存够用吗 | 勉强 | **完全够** | 完全够 |
| 上手难度 | 中 | 中偏上 | 低 |

**我的建议**：

- 你的 iPhone 是 iOS 18 或更低 → 先试 **路 1**，最快看到效果
- 你的 iPhone 是 iOS 26 → 走 **路 2**（我已经把流水线写好了），或者干脆用 **路 3**
- 想省事、想分享给别人 → **路 3**
