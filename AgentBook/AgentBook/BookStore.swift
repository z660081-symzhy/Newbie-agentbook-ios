import SwiftUI

/// 目录分组。注意：不能用带标签的元组配 ForEach(id:)，Swift 不支持元组的 key path，
/// 所以这里老老实实定义成结构体。
struct ChapterGroup: Identifiable {
    let id: String
    let part: String
    let items: [Chapter]
}

/// 原生侧的学习状态。
/// 注意：「已读」不是这里独立维护的，而是从网页自己的勾选状态同步过来的
/// （网页把已读章节存在 localStorage 的 st.read 里，键就是 c1、c2…）。
/// 书签和主题则是原生独有的。
final class BookStore: ObservableObject {
    enum ThemeMode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
    }

    @Published var chapters: [Chapter] = TocLoader.load()
    @Published private(set) var read: Set<String> = []
    @Published private(set) var bookmarked: Set<String> = []
    @Published private(set) var current: String?
    @Published private(set) var theme: ThemeMode = .system

    private var pendingJump: String?
    private let defaults = UserDefaults.standard

    init() {
        if let saved = defaults.array(forKey: "bookmarks") as? [String] {
            bookmarked = Set(saved)
        }
        if let t = defaults.string(forKey: "theme"), let mode = ThemeMode(rawValue: t) {
            theme = mode
        }
        current = defaults.string(forKey: "current")
        pendingJump = current
    }

    // MARK: - 派生数据

    var progress: Double {
        guard !chapters.isEmpty else { return 0 }
        return min(1, Double(read.count) / Double(chapters.count))
    }

    var readCount: Int { read.count }

    var realChapters: [Chapter] { chapters.filter { $0.number != nil } }

    var grouped: [ChapterGroup] {
        var order: [String] = []
        var map: [String: [Chapter]] = [:]
        for c in chapters {
            let p = c.part.isEmpty ? "正文" : c.part
            if map[p] == nil { order.append(p) }
            map[p, default: []].append(c)
        }
        return order.map { ChapterGroup(id: $0, part: $0, items: map[$0] ?? []) }
    }

    func isRead(_ id: String) -> Bool { read.contains(id) }
    func isBookmarked(_ id: String) -> Bool { bookmarked.contains(id) }

    var currentChapter: Chapter? {
        guard let id = current else { return nil }
        return chapters.first { $0.id == id }
    }

    // MARK: - 写入

    func syncRead(_ ids: [String]) {
        let set = Set(ids)
        if set != read { read = set }
    }

    func toggleBookmark(_ id: String) {
        if bookmarked.contains(id) { bookmarked.remove(id) } else { bookmarked.insert(id) }
        defaults.set(Array(bookmarked), forKey: "bookmarks")
    }

    func setCurrent(_ id: String) {
        guard current != id else { return }
        current = id
        defaults.set(id, forKey: "current")
    }

    func setTheme(_ mode: ThemeMode) {
        theme = mode
        defaults.set(mode.rawValue, forKey: "theme")
    }

    /// 点目录：记下要跳的锚点，WebView 在 updateUIView 里消费掉
    func jump(to id: String) {
        pendingJump = id
        setCurrent(id)
    }

    func consumeJump() -> String? {
        defer { pendingJump = nil }
        return pendingJump
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// 网页侧要用的主题字符串
    var webTheme: String {
        switch theme {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        }
    }

    // MARK: - 进度备份（用一段文本，跨设备粘一下就能带走）

    func exportCode() -> String {
        let payload: [String: Any] = [
            "v": 1,
            "bookmarks": Array(bookmarked).sorted(),
            "current": current ?? ""
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return ""
        }
        return "AGENTBOOK-" + data.base64EncodedString()
    }

    @discardableResult
    func importCode(_ raw: String) -> Bool {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "AGENTBOOK-", with: "")
        guard let data = Data(base64Encoded: code),
              let json = try? JSONSerialization.jsonObject(with: data),
              let obj = json as? [String: Any] else { return false }
        if let b = obj["bookmarks"] as? [String] {
            bookmarked = Set(b)
            defaults.set(Array(bookmarked), forKey: "bookmarks")
        }
        if let c = obj["current"] as? String, !c.isEmpty {
            current = c
            defaults.set(c, forKey: "current")
            pendingJump = c
        }
        return true
    }
}
