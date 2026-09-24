import Foundation

/// 一章 / 一节的目录条目。id 就是网页里的锚点（c1、c2…），
/// 原生侧边栏点一下，就是让网页滚到那个锚点。
struct Chapter: Identifiable, Hashable, Codable {
    let id: String
    let part: String
    let title: String

    /// 「第 12 章 xxx」→ 12；非章节条目（比如"每日固定动作"）返回 nil
    var number: Int? {
        guard title.contains("章") else { return nil }
        let cleaned = title.replacingOccurrences(of: "第", with: " ")
            .replacingOccurrences(of: "章", with: " ")
        guard let first = cleaned.split(separator: " ").first else { return nil }
        return Int(String(first))
    }

    var shortTitle: String {
        guard let n = number else { return title }
        // 去掉开头的「第 N 章」，列表里更清爽
        var t = title
        if let r = t.range(of: "章") {
            t = String(t[r.upperBound...])
        }
        t = t.trimmingCharacters(in: .whitespaces)
        return n == 0 ? "导论 · \(t)" : "第 \(n) 章 · \(t)"
    }
}

enum TocLoader {
    static func load() -> [Chapter] {
        guard let url = Bundle.main.url(forResource: "toc", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        struct Wrapper: Codable { let chapters: [Chapter] }
        return (try? JSONDecoder().decode(Wrapper.self, from: data))?.chapters ?? []
    }
}
