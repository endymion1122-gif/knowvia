import SwiftUI

struct DocumentMetadataDraft {
    var title: String
    var tags: [String]
    var sourceKind: String
    var author: String
    var publicationYear: Int?
    var sourceURLString: String
    var sourceNote: String
    var credibilityLevel: String
    var contributionNote: String
}

struct DocumentMetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let document: DocumentItem
    let onSave: (DocumentMetadataDraft) -> Void

    @State private var title: String
    @State private var tagsText: String
    @State private var sourceKind: DocumentSourceKind
    @State private var author: String
    @State private var publicationYearText: String
    @State private var sourceURLString: String
    @State private var sourceNote: String
    @State private var credibility: SourceCredibilityLevel
    @State private var contributionNote: String

    init(document: DocumentItem, onSave: @escaping (DocumentMetadataDraft) -> Void) {
        self.document = document
        self.onSave = onSave
        _title = State(initialValue: document.title)
        _tagsText = State(initialValue: document.tags.joined(separator: "，"))
        _sourceKind = State(initialValue: document.sourceType)
        _author = State(initialValue: document.author)
        _publicationYearText = State(initialValue: document.publicationYear.map(String.init) ?? "")
        _sourceURLString = State(initialValue: document.sourceURLString)
        _sourceNote = State(initialValue: document.sourceNote)
        _credibility = State(initialValue: document.credibility)
        _contributionNote = State(initialValue: document.contributionNote)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("编辑来源资料")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("补全来源后，专题报告会保留更清楚的证据线索。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.pathTeal)
                }
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
                Button("保存") {
                    onSave(draft)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
                .disabled(trimmedTitle.isEmpty || !isYearValid)
                .opacity(trimmedTitle.isEmpty || !isYearValid ? 0.45 : 1)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    field("显示名称") {
                        TextField("资料名称", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        field("来源类型") {
                            Picker("来源类型", selection: $sourceKind) {
                                ForEach(DocumentSourceKind.allCases) { kind in
                                    Text(kind.title).tag(kind)
                                }
                            }
                            .labelsHidden()
                        }
                        field("可信度标记") {
                            Picker("可信度标记", selection: $credibility) {
                                ForEach(SourceCredibilityLevel.allCases) { level in
                                    Text(level.title).tag(level)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        field("作者 / 机构") {
                            TextField("例如：Vaswani et al.", text: $author)
                                .textFieldStyle(.roundedBorder)
                        }
                        field("年份") {
                            TextField("例如：2017", text: $publicationYearText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                        }
                    }

                    field("网页链接") {
                        TextField("https://...", text: $sourceURLString)
                            .textFieldStyle(.roundedBorder)
                    }

                    field("标签") {
                        TextField("使用逗号分隔，例如：论文，研究方法", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                    }

                    field("来源备注") {
                        TextEditor(text: $sourceNote)
                            .font(.system(size: 12))
                            .frame(minHeight: 62)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.coolGray, lineWidth: 1)
                            }
                    }

                    field("主要贡献") {
                        TextEditor(text: $contributionNote)
                            .font(.system(size: 12))
                            .frame(minHeight: 70)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.coolGray, lineWidth: 1)
                            }
                    }

                    if !isYearValid {
                        Text("年份请填写为数字，或留空。")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.softPlum)
                    }

                    Text("修改显示名称不会改动本地副本路径。网页资料链接仅用于来源追溯。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 700)
        .background(AppTheme.pageBackground)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var publicationYear: Int? {
        let text = publicationYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : Int(text)
    }

    private var isYearValid: Bool {
        publicationYearText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || publicationYear != nil
    }

    private var tags: [String] {
        tagsText
            .components(separatedBy: CharacterSet(charactersIn: ",，"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var draft: DocumentMetadataDraft {
        DocumentMetadataDraft(
            title: trimmedTitle,
            tags: tags,
            sourceKind: sourceKind.rawValue,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            publicationYear: publicationYear,
            sourceURLString: sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceNote: sourceNote.trimmingCharacters(in: .whitespacesAndNewlines),
            credibilityLevel: credibility.rawValue,
            contributionNote: contributionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        )
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
