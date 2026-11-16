# 桌面浏览器 for iPhone

一个 iPhone 上的桌面端浏览器，内核是系统 WebKit（`WKWebView`）。

iOS 规定所有浏览器都必须用 WebKit，不能换 Chromium / Gecko 内核，
所以“桌面端”靠 macOS Safari 的桌面 UA 实现：网站看到桌面 UA
就会返回桌面版页面。默认就是桌面模式，也可以一键切回手机版。

- 目标设备：iPhone 18 Pro（iOS 17.0+，在 iOS 26/27 上可运行）
- 内核：WebKit `WKWebView`
- 默认 UA：`Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15`
- 功能：地址栏（输网址直达、输关键词搜 DuckDuckGo）、前进 / 后退 / 刷新 / 主页、
  加载进度条、桌面版 ↔ 手机版切换、分享、`target=_blank` 在本页打开、
  JS 弹窗、登录态 / Cookie 保留

## 安装（IPA 是未签名的）

GitHub Actions 打出来的 IPA **没有 Apple 签名**，不能直接在 iPhone 上点开安装，
这是没有付费开发者证书时的正常做法。装法二选一：

1. **AltStore / SideStore**：把 IPA 导入，用自己的免费 Apple ID 签名安装，
   7 天续签一次。
2. **有开发者证书时**：在仓库 Settings → Secrets 里配好证书再改 workflow 走签名构建，
   或在自己 Mac 上用 Xcode 打开项目直接跑到真机。

## 本地构建（Mac + Xcode）

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project DesktopBrowser.xcodeproj -scheme DesktopBrowser \
  -configuration Release -destination 'generic/platform=iOS' archive \
  -archivePath build/DesktopBrowser.xcarchive \
  CODE_SIGNING_ALLOWED=NO
```

## GitHub Actions 自动构建

- 每次 push 到 `main` 会构建一次，产物在 Actions 页下载。
- 打 tag `v1.0.0` 这样的版本就会自动创建 GitHub Release 并附上 IPA：

```bash
git tag v1.0.0
git push origin v1.0.0
```

Bundle ID：`xyz.zongtech.DesktopBrowser`，显示名：桌面浏览器。
