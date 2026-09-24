import SwiftUI
import UIKit

/// 原生外壳：左边目录，右边教材正文。
///
/// iPhone 上的关键点：侧边栏必须用「带选择绑定的 List」，
/// 点击某一行时把 selection 改掉，NavigationSplitView 才会把详情列推出来。
/// 用普通 Button 包裹行是不行的（点了不会有任何反应）。
struct ContentView: View {
    @StateObject private var store = BookStore()
    @State private var query = ""
    @State private var showBackup = false
    /// 当前选中的章节 id。iPhone 上就是它把正文推出来。
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            BookWebView(store: store)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(store.currentChapter?.shortTitle ?? "Agent 就业教材全集")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selection) { newValue in
            guard let id = newValue else { return }
            store.jump(to: id)
        }
        .preferredColorScheme(store.colorScheme)
        .sheet(isPresented: $showBackup) { BackupView(store: store) }
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        List(selection: $selection) {
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

            ForEach(filteredGroups) { group in
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
                // 点它 = 选中这一章，iPhone 上会直接进正文
                Button {
                    selection = c.id
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

    /// 注意最后的 .tag(c.id)：没有它，List 就不知道这一行代表哪个值，
    /// 选中也不会生效。这是上一个版本打不开章节的原因。
    private func chapterRow(_ c: Chapter) -> some View {
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
        .tag(c.id)
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
                        Label("从上面的内容导入", systemImage: "square.and.arrow.down")
                    }
                    Button("粘贴剪贴板内容") {
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
