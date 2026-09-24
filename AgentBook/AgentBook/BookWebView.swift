import SwiftUI
import WebKit

/// 用 WKWebView 加载打包进 App 的 book.html，并在原生和网页之间搭一座桥：
/// 网页滚动时告诉原生"我现在在哪一章"，原生把已读状态同步过来；
/// 原生点目录时反过来让网页滚过去。
struct BookWebView: UIViewRepresentable {
    @ObservedObject var store: BookStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.userContentController.addUserScript(
            WKUserScript(source: Self.bridge, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        config.userContentController.add(context.coordinator, name: "book")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.load(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.applyTheme(store.webTheme, to: webView)
        context.coordinator.applyPendingNavigation(store: store, in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "book")
    }

    // MARK: - 注入网页的桥接脚本

    private static let bridge = """
    (function () {
      if (window.__bookBridgeReady) return;
      window.__bookBridgeReady = true;
      // 告诉网页：我在原生 App 里。App 有自己的原生目录，
      // 所以网页自带的侧栏/抽屉要隐藏掉，正文占满整屏。
      document.documentElement.classList.add('in-app');
      function post(o) { try { window.webkit.messageHandlers.book.postMessage(o); } catch (e) {} }

      var jumping = null;   // 正在程序跳转的目标 id；跳转期间不上报"当前位置"
      function topOf(el) { return el.getBoundingClientRect().top + window.scrollY - 56; }

      // 原生点目录 → 网页滚过去并闪一下
      window.__bookJumpTo = function (id) {
        var el = document.getElementById(id);
        if (!el) return false;
        jumping = id;
        // 一律"瞬时跳"，不用 behavior:'smooth'。原因有两条，都是实测踩出来的：
        //   1. 平滑滚动在 WKWebView 里会被丢掉（5 次里丢 3 次），表现就是"点了目录没反应"；
        //   2. 如果在平滑滚动还在跑的时候再补一次硬跳，两段滚动会叠加，直接冲过头
        //      （实测想跳到 64051，结果停在了 97524 —— 也就是"跳到后面去了"）。
        // 网页自带的目录链接之所以每次都准，就是因为它走的是瞬时跳转。
        window.scrollTo({ top: topOf(el), behavior: 'auto' });
        // 再校正一帧：万一布局晚一拍（表格/图片把高度撑开），把位置纠回来。
        requestAnimationFrame(function () {
          var e2 = document.getElementById(id);
          if (e2 && Math.abs(e2.getBoundingClientRect().top - 56) > 40) {
            window.scrollTo({ top: topOf(e2), behavior: 'auto' });
          }
          setTimeout(function () { jumping = null; report(); }, 60);
        });
        var old = el.style.backgroundColor;
        el.style.transition = 'background-color .5s';
        el.style.backgroundColor = 'rgba(140,61,46,.16)';
        setTimeout(function () { el.style.backgroundColor = old || ''; }, 900);
        return true;
      };

      // 原生切主题 → 同时写回 localStorage，保持网页自己的开关同步
      window.__bookSetTheme = function (t) {
        if (t === 'system') {
          t = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
        }
        document.documentElement.dataset.theme = t;
        try {
          var raw = localStorage.getItem('agentbook_v1');
          var s = raw ? JSON.parse(raw) : {};
          s.theme = t;
          localStorage.setItem('agentbook_v1', JSON.stringify(s));
        } catch (e) {}
      };

      // 网页自己的已读集合（键就是 c1、c2…，和目录 id 一一对应）
      window.__bookReadSet = function () {
        try {
          var raw = localStorage.getItem('agentbook_v1');
          var s = raw ? JSON.parse(raw) : {};
          return Object.keys(s.read || {});
        } catch (e) { return []; }
      };

      // 滚动到哪一章就上报给原生（只报变化，不刷屏）
      //
      // 这里原来用 IntersectionObserver，有两个坑，实测都会踩到：
      //   1. 一次回调可能带多个条目，取"数组里最后一个"并不等于"最靠上的那个"，
      //      于是可能把很靠后的一章报成当前章节；
      //   2. 页面刚加载时它会先把所有 h2 的状态报一遍，最后一条往往是最末一节
      //      （附录 E）—— 原生拿到后会把"上次读到哪"写成附录 E，下次启动就跳到附录 E。
      // 现在改成按滚动位置直接算，并且"刚加载完不报"。
      var last = null;
      function currentId() {
        var hs = document.querySelectorAll('h2[id]'), best = null;
        for (var i = 0; i < hs.length; i++) {
          // 取"最后一个已经滚过视口顶部"的小节 —— 就是读者眼睛所在的那一节
          if (hs[i].getBoundingClientRect().top <= 120) best = hs[i].id; else break;
        }
        return best || (hs.length ? hs[0].id : null);
      }
      function report(force) {
        if (jumping) return;
        var id = currentId();
        if (!id) return;
        if (id === last && !force) return;
        last = id;
        post({ type: 'location', id: id, read: window.__bookReadSet() });
      }
      var ticking = false;
      window.addEventListener('scroll', function () {
        if (jumping || ticking) return;
        ticking = true;
        requestAnimationFrame(function () { ticking = false; report(false); });
      }, { passive: true });
      // 首次不上报：刚加载完时"当前位置"没有意义，报了反而会把 App 记住的位置覆盖错。
      last = currentId();

      post({ type: 'ready', total: document.querySelectorAll('h2[id]').length,
             read: window.__bookReadSet() });
    })();
    """

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let store: BookStore
        weak var webView: WKWebView?
        private var appliedTheme: String?
        private var lastThemeRequest: String?
        private(set) var isLoaded = false

        init(store: BookStore) { self.store = store }

        func load(into webView: WKWebView) {
            isLoaded = false
            guard let url = Bundle.main.url(forResource: "book", withExtension: "html") else {
                webView.loadHTMLString(
                    "<h3 style='font-family:-apple-system;padding:24px'>没有找到 book.html</h3>",
                    baseURL: nil)
                return
            }
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        func applyTheme(_ theme: String, to webView: WKWebView) {
            lastThemeRequest = theme
            guard appliedTheme != theme, isLoaded else { return }
            appliedTheme = theme
            webView.evaluateJavaScript("window.__bookSetTheme && window.__bookSetTheme('\(theme)')")
        }

        func applyPendingNavigation(store: BookStore, in webView: WKWebView) {
            guard isLoaded, let id = store.consumeJump() else { return }
            jump(to: id, in: webView)
        }

        func jump(to id: String, in webView: WKWebView) {
            guard isLoaded else { return }
            // 不依赖注入脚本：即使桥接脚本没跑起来，这段自带兜底也能滚过去
            let js = """
            (function () {
              var id = '\(id)';
              if (window.__bookJumpTo && window.__bookJumpTo(id)) return 'bridge';
              var el = document.getElementById(id);
              if (!el) return 'no-element';
              var top = el.getBoundingClientRect().top + window.scrollY - 56;
              // 兜底用硬跳：平滑滚动在 WKWebView 里会被丢掉，兜底就不要再冒险了
              window.scrollTo({ top: top, behavior: 'auto' });
              return 'inline';
            })();
            """
            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    NSLog("[BookWebView] 跳转失败 \(id)：\(error.localizedDescription)")
                }
            }
        }

        // MARK: - 网页加载完成：兜底把 isLoaded 打开

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 正常情况下桥接脚本会发 ready 消息；这里再兜一层，
            // 保证即使消息丢了，点目录依然能跳转。
            if !isLoaded {
                isLoaded = true
                if let t = lastThemeRequest {
                    appliedTheme = nil
                    applyTheme(t, to: webView)
                }
            }
            applyPendingNavigation(store: store, in: webView)
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            let ids = (body["read"] as? [String]) ?? []
            // WKScriptMessageHandler 的回调本来就在主线程，直接处理即可
            switch type {
            case "ready":
                isLoaded = true
                store.syncRead(ids)
                if let wv = webView {
                    // 页面刚加载完，把主题和"上次读到哪"补上
                    if let t = lastThemeRequest {
                        appliedTheme = nil
                        applyTheme(t, to: wv)
                    }
                    applyPendingNavigation(store: store, in: wv)
                }
            case "location":
                if let id = body["id"] as? String { store.setCurrent(id) }
                store.syncRead(ids)
            default:
                break
            }
        }
    }
}
