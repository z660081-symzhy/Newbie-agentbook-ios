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

      // 原生点目录 → 网页滚过去并闪一下
      window.__bookJumpTo = function (id) {
        var el = document.getElementById(id);
        if (!el) return;
        var top = el.getBoundingClientRect().top + window.scrollY - 56;
        window.scrollTo({ top: top, behavior: 'smooth' });
        var old = el.style.backgroundColor;
        el.style.transition = 'background-color .5s';
        el.style.backgroundColor = 'rgba(140,61,46,.16)';
        setTimeout(function () { el.style.backgroundColor = old || ''; }, 900);
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
      var last = null;
      try {
        var obs = new IntersectionObserver(function (entries) {
          entries.forEach(function (en) {
            if (en.isIntersecting && en.target.id !== last) {
              last = en.target.id;
              post({ type: 'location', id: last, read: window.__bookReadSet() });
            }
          });
        }, { rootMargin: '-10% 0px -80% 0px' });
        document.querySelectorAll('h2[id]').forEach(function (h) { obs.observe(h); });
      } catch (e) {}

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
              var el = document.getElementById('\(id)');
              if (!el) return 'no-element';
              if (window.__bookJumpTo) { window.__bookJumpTo('\(id)'); return 'bridge'; }
              var top = el.getBoundingClientRect().top + window.scrollY - 56;
              window.scrollTo({ top: top, behavior: 'smooth' });
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
