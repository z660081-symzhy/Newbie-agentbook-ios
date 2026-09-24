import SwiftUI
import UIKit

/// 原生外壳：左侧是目录（SwiftUI 列表 + 搜索 + 进度），右侧是教材正文（WKWebView）。
/// iPhone 上 NavigationSplitView 会自动折叠成"目录 → 正文"的层级导航。
struct ContentView: View {
    @StateObject private var store = BookStore()
    @State private var query = ""
    @State private var showBackup = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            BookWebView(store: store)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(store.currentChapter?.shortTitle ?? "Agent 就业教材全集")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(store.colorScheme)
        .sheet(isPresented: $showBackup) { BackupView(store: store) }
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        List {
            Section {
                progressHeader
            }

            if !bookmarkedChapters.isEmpty && query.isEmpty {
                Section("书签") {
                    ForEach(bookmarkedChapters) { c in
                        chapterRow(c)
                    }
                }
            }

            ForEach(filteredGroups, id: \.part) { group in
                Section(group.part) {
                    ForEach(group.items) { c in
                        chapterRow(c)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, placement: .sidebar, prompt: "搜索章节或关键词")
        .navigationTitle("目录")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                themeMenu
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    if let id = store.current { store.toggleBookmark(id) }
                } label: {
                    Image(systemName: isCurrentBookmarked ? "bookmark.fill" : "bookmark")
                }
                .disabled(store.current == nil)
                .accessibilityLabel("给当前章节加书签")

                Button {
                    showBackup = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("备份与恢复进度")
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("学习进度")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.readCount) / \(store.chapters.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: store.progress)
                .tint(Color.accentColor)
            if let c = store.currentChapter {
                Button {
                    store.jump(to: c.id)
                } label: {
                    Label("继续：\(c.shortTitle)", systemImage: "arrow.right.circle")
                        .font(.footnote)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var themeMenu: some View {
        Menu {
            ForEach(BookStore.ThemeMode.allCases) { mode in
                Button {
                    store.setTheme(mode)
                } label: {
                    if store.theme == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Text(mode.label)
                    }
                }
            }
        } label: {
            Image(systemName: store.theme == .dark ? "moon.fill"
                    : store.theme == .light ? "sun.max.fill" : "circle.lefthalf.filled")
        }
        .accessibilityLabel("切换主题")
    }

    private func chapterRow(_ c: Chapter) -> some View {
        Button {
            store.jump(to: c.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.isRead(c.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(store.isRead(c.id) ? Color.green : Color.secondary)
                    .font(.footnote)
                Text(c.shortTitle)
                    .lineLimit(2)
                    .font(.callout)
                Spacer(minLength: 4)
                if store.isBookmarked(c.id) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }
                if store.current == c.id {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 过滤

    private var filteredGroups: [ChapterGroup] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.grouped }
        return store.grouped.compactMap { group in
            let hits = group.items.filter {
                $0.title.localizedCaseInsensitiveContains(q)
                    || group.part.localizedCaseInsensitiveContains(q)
            }
            return hits.isEmpty ? nil : ChapterGroup(id: group.id, part: group.part, items: hits)
        }
    }

    private var bookmarkedChapters: [Chapter] {
        store.chapters.filter { store.isBookmarked($0.id) }
    }

    private var isCurrentBookmarked: Bool {
        guard let id = store.current else { return false }
        return store.isBookmarked(id)
    }
}

/// 进度备份：用一段文本在设备之间搬运，避免依赖 iCloud 能力
/// （免费 Apple ID 签名时不支持 iCloud，所以这里用最朴素的办法）
struct BackupView: View {
    @ObservedObject var store: BookStore
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("导出") {
                    Text(store.exportCode())
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = store.exportCode()
                        message = "已复制到剪贴板"
                    } label: {
                        Label("复制备份码", systemImage: "doc.on.doc")
                    }
                }
                Section("导入") {
                    TextField("把备份码粘到这里", text: $input, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.footnote.monospaced())
                    Button {
                        if store.importCode(input) {
                            message = "导入成功"
                        } else {
                            message = "备份码无效"
                        }
                    } label: {
                        Label("从剪贴板内容导入", systemImage: "square.and.arrow.down")
                    }
                    Button("直接粘贴剪贴板") {
                        input = UIPasteboard.general.string ?? ""
                    }
                }
                if !message.isEmpty {
                    Section {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("备份内容包含：书签列表、当前阅读位置。"
                         + "已读章节由网页自己保存，跟着 App 数据一起走。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("备份与恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
