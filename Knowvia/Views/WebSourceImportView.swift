import SwiftUI

enum WebSourceImportMode {
    case librarySource
    case externalCandidate

    var title: String {
        switch self {
        case .librarySource: "添加网页资料"
        case .externalCandidate: "添加外部补全候选"
        }
    }

    var subtitle: String {
        switch self {
        case .librarySource: "保存链接和正文摘录，作为可回溯的本地 Markdown 来源。"
        case .externalCandidate: "候选资料不会直接进入正式路径，需要你确认后再纳入。"
        }
    }

    var sourceKind: DocumentSourceKind {
        switch self {
        case .librarySource: .webPage
        case .externalCandidate: .externalEnrichment
        }
    }

    var saveTitle: String {
        switch self {
        case .librarySource: "保存网页资料"
        case .externalCandidate: "保存为候选"
        }
    }
}

struct WebSourceImportView: View {
    @Environment(\.dismiss) private var dismiss
    var mode: WebSourceImportMode = .librarySource
    let onImport: (DocumentItem) -> Void

    @State private var title = ""
    @State private var urlString = ""
    @State private var excerpt = ""
    @State private var author = ""
    @State private var publicationYearText = ""
    @State private var note = ""
    @State private var extractionMessage: String?
    @State private var errorMessage: String?
    @State private var isFetching = false

    private let importService = WebSourceImportService()
    private let extractionService = WebSourceExtractionService()
    private let fetchService = WebPageFetchService()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(mode.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.pathTeal)
                }
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
                Button(mode.saveTitle) {
                    importSource()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    field("标题") {
                        TextField("网页标题", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("网页链接")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.slateBlue)
                            TextField("https://...", text: $urlString)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            Task { await fetchFromURL() }
                        } label: {
                            HStack(spacing: 4) {
                                if isFetching {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                }
                                Text(isFetching ? "获取中..." : "获取")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isFetching || urlString.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AppTheme.coolGray
                                    : AppTheme.deepIndigo,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isFetching || urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        field("作者 / 机构") {
                            TextField("可选", text: $author)
                                .textFieldStyle(.roundedBorder)
                        }
                        field("年份") {
                            TextField("可选", text: $publicationYearText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("网页正文或 HTML")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.slateBlue)
                            Spacer()
                            Button("从粘贴内容提取") {
                                extractPastedContent()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.softViolet)
                        }
                        TextEditor(text: $excerpt)
                            .font(.system(size: 12))
                            .frame(minHeight: 210)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.coolGray, lineWidth: 1)
                            }
                    }

                    if let extractionMessage {
                        Label(extractionMessage, systemImage: "wand.and.sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.pathTeal)
                    }

                    field("来源备注") {
                        TextEditor(text: $note)
                            .font(.system(size: 12))
                            .frame(minHeight: 64)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.coolGray, lineWidth: 1)
                            }
                    }

                    Text("可以粘贴网页正文或 HTML 后点击提取；也可以输入链接后点击“获取”自动抓取。当前版本不会在后台自动联网。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 690)
        .background(AppTheme.pageBackground)
        .alert("无法添加网页资料", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var publicationYear: Int? {
        let text = publicationYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : Int(text)
    }

    // MARK: - Actions

    private func importSource() {
        let yearText = publicationYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard yearText.isEmpty || publicationYear != nil else {
            errorMessage = "年份请填写为数字，或留空。"
            return
        }

        do {
            let document = try importService.importWebSource(
                title: title,
                urlString: urlString,
                excerpt: excerpt,
                author: author,
                publicationYear: publicationYear,
                note: note,
                sourceKind: mode.sourceKind
            )
            onImport(document)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func extractPastedContent() {
        do {
            let draft = try extractionService.extract(from: excerpt)
            applyDraft(draft, message: "已提取标题、作者、年份与正文，请确认后保存。")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchFromURL() async {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        isFetching = true
        extractionMessage = nil
        defer { isFetching = false }

        do {
            let result = try await fetchService.fetch(urlString: trimmedURL)
            let draft = try extractionService.extract(from: result.html)

            // Only auto-fill URL if it changed (followed redirect)
            if result.finalURL.absoluteString != trimmedURL {
                urlString = result.finalURL.absoluteString
            }

            let redirectNote = result.finalURL.absoluteString != trimmedURL
                ? "（已跟随重定向）" : ""
            applyDraft(draft, message: "已获取网页内容并提取信息\(redirectNote)，请确认后保存。")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyDraft(_ draft: WebSourceExtractionDraft, message: String) {
        if !draft.title.isEmpty {
            title = draft.title
        }
        if !draft.author.isEmpty {
            author = draft.author
        }
        if let publicationYear = draft.publicationYear {
            publicationYearText = String(publicationYear)
        }
        excerpt = draft.excerpt
        extractionMessage = message
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.slateBlue)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
