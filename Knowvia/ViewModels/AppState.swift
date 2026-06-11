import Foundation

enum SidebarDestination: String, CaseIterable, Identifiable {
    case dashboard
    case recent
    case library
    case pathways
    case cards
    case graph
    case writing
    case learningPath
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "首页"
        case .recent: "最近阅读"
        case .library: "资料库"
        case .pathways: "专题路径库"
        case .cards: "知识卡片"
        case .graph: "知识图谱"
        case .writing: "写作项目"
        case .learningPath: "学习路径"
        case .settings: "设置"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: "house"
        case .recent: "clock"
        case .library: "books.vertical"
        case .pathways: "point.topleft.down.curvedto.point.bottomright.up"
        case .cards: "rectangle.stack"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .writing: "square.and.pencil"
        case .learningPath: "point.topleft.down.curvedto.point.bottomright.up"
        case .settings: "gearshape"
        }
    }

    var isAvailable: Bool {
        [.dashboard, .recent, .library, .pathways, .cards, .learningPath, .settings].contains(self)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selection: SidebarDestination = .dashboard
    @Published var activeDocument: DocumentItem?
    @Published var requestedPDFPageNumber: Int?
    @Published var requestedTextAnchorExcerpt: String?
    @Published var requestedTextAnchorID = 0
    @Published var extractedPageText = ""
    @Published var inspectorPageNumber: Int?
    @Published var extractionMessage: String?
    @Published var selectedPDFText = ""
    @Published var selectedPDFPageNumber: Int?
    @Published var aiSummary = ""
    @Published var aiSummaryNotice: String?
    @Published var aiErrorMessage: String?
    @Published var isSummarizing = false
    @Published var suggestedCardDrafts: [KnowledgeCardDraft] = []
    @Published var aiSelectionExplanation = ""
    @Published var aiSelectionNotice: String?
    @Published var aiSelectionErrorMessage: String?
    @Published var isExplainingSelection = false
    @Published var aiSelectionCardNotice: String?
    @Published var aiSelectionCardErrorMessage: String?
    @Published var isGeneratingSelectionCard = false
    @Published var annotationCardNotice: String?
    @Published var annotationCardErrorMessage: String?
    @Published var isGeneratingAnnotationCard = false

    private let aiService = AIService()
    private let demoAIService = DemoAIService()
    private let keychainService = KeychainService.shared
    private let pdfTextExtractionService = PDFTextExtractionService()
    private let readingProgressService = DocumentReadingProgressService()
    private let selectionCardService = SelectionKnowledgeCardService()
    private let annotationCardService = AnnotationKnowledgeCardService()
    private let aiKnowledgeCardDraftService = AIKnowledgeCardDraftService()
    private let aiErrorRecoveryService = AIErrorRecoveryService()

    func select(_ destination: SidebarDestination) {
        selection = destination
        activeDocument = nil
        requestedPDFPageNumber = nil
        requestedTextAnchorExcerpt = nil
        extractedPageText = ""
        inspectorPageNumber = nil
        extractionMessage = nil
        selectedPDFText = ""
        selectedPDFPageNumber = nil
        resetAIState()
    }

    func open(
        _ document: DocumentItem,
        pageNumber: Int? = nil,
        textAnchorExcerpt: String? = nil
    ) {
        activeDocument = document
        requestedPDFPageNumber = document.isPDF
            ? pageNumber ?? readingProgressService.resumePageNumber(for: document)
            : nil
        requestedTextAnchorExcerpt = document.isPDF ? nil : textAnchorExcerpt
        requestedTextAnchorID += 1
        extractedPageText = ""
        inspectorPageNumber = document.isPDF ? requestedPDFPageNumber ?? 1 : nil
        extractionMessage = nil
        selectedPDFText = ""
        selectedPDFPageNumber = nil
        resetAIState()
    }

    func summarizeActiveDocument() async {
        guard let activeDocument else {
            return
        }

        isSummarizing = true
        aiErrorMessage = nil
        aiSummaryNotice = nil
        defer { isSummarizing = false }

        let documentText = activeDocument.isPDF
            ? pdfTextExtractionService.extractText(from: activeDocument.fileURL)
            : activeDocument.extractedText ?? ""

        do {
            guard !documentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                aiErrorMessage = activeDocument.isPDF
                    ? "该 PDF 可能是扫描版，当前 Demo 暂不支持 OCR。"
                    : "当前文档没有可用于 AI 速读的文本。"
                return
            }

            let settings = AppSettingsStore.load()
            if settings.demoModeEnabled {
                aiSummary = demoAIService.documentSummary(
                    title: activeDocument.title,
                    text: documentText
                )
                aiSummaryNotice = "本地 Demo AI 已开启：文本未发送到任何模型服务商。"
                suggestedCardDrafts = demoAIService.knowledgeCardDrafts(
                    documentTitle: activeDocument.title,
                    text: documentText
                )
            } else {
                guard let apiKey = try keychainService.loadAPIKey(), !apiKey.isEmpty else {
                    throw AIServiceError.missingAPIKey
                }

                let prompt = PromptTemplates.documentSpeedRead(documentText)
                aiSummary = try await aiService.sendChatCompletion(
                    endpoint: settings.apiEndpoint,
                    apiKey: apiKey,
                    model: settings.modelName,
                    messages: [AIMessage(role: "user", content: prompt.content)]
                )
                aiSummaryNotice = realAISummaryNotice(wasTruncated: prompt.wasTruncated)
                suggestedCardDrafts = aiKnowledgeCardDraftService.drafts(
                    documentTitle: activeDocument.title,
                    text: documentText,
                    generatedSummary: aiSummary
                )
            }
            activeDocument.summary = aiSummary
            activeDocument.updatedAt = Date()
        } catch {
            aiErrorMessage = aiErrorRecoveryService.message(
                for: error,
                action: .documentSummary
            )
            suggestedCardDrafts = demoAIService.knowledgeCardDrafts(
                documentTitle: activeDocument.title,
                text: documentText
            )
            aiSummaryNotice = "真实 API 暂未完成；已生成本地兜底卡片草稿，你可以先整理，稍后再重试 AI 速读。"
        }
    }

    func updateSelectedText(_ text: String, pageNumber: Int?) {
        if selectedPDFText != text {
            aiSelectionExplanation = ""
            aiSelectionNotice = nil
            aiSelectionErrorMessage = nil
            aiSelectionCardNotice = nil
            aiSelectionCardErrorMessage = nil
        }

        selectedPDFText = text
        selectedPDFPageNumber = pageNumber
    }

    func generateSelectedTextCardDraft() async -> KnowledgeCardDraft? {
        let selectedText = selectedPDFText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let activeDocument else {
            return nil
        }
        guard !selectedText.isEmpty else {
            aiSelectionCardErrorMessage = "请先选择一个名词、句子或片段。"
            return nil
        }

        isGeneratingSelectionCard = true
        aiSelectionCardNotice = nil
        aiSelectionCardErrorMessage = nil
        defer { isGeneratingSelectionCard = false }

        do {
            let settings = AppSettingsStore.load()
            if settings.demoModeEnabled {
                aiSelectionCardNotice = "本地 Demo AI 已生成卡片草稿：选区未发送到任何模型服务商。"
                return demoAIService.selectionKnowledgeCardDraft(
                    documentTitle: activeDocument.title,
                    selectedText: selectedText
                )
            }

            guard let apiKey = try keychainService.loadAPIKey(), !apiKey.isEmpty else {
                throw AIServiceError.missingAPIKey
            }

            let prompt = PromptTemplates.selectionKnowledgeCard(selectedText)
            let summary = try await aiService.sendChatCompletion(
                endpoint: settings.apiEndpoint,
                apiKey: apiKey,
                model: settings.modelName,
                messages: [AIMessage(role: "user", content: prompt.content)]
            )
            aiSelectionCardNotice = prompt.wasTruncated
                ? "当前仅处理选区前 4000 个字符，请结合原文继续核验。"
                : nil
            return selectionCardService.draft(
                documentTitle: activeDocument.title,
                selectedText: selectedText,
                generatedSummary: summary
            )
        } catch {
            aiSelectionCardErrorMessage = aiErrorRecoveryService.message(
                for: error,
                action: .selectionCard
            )
            return nil
        }
    }

    var generatedSelectionCardCreatedBy: String {
        AppSettingsStore.load().demoModeEnabled ? "ai-demo" : "ai"
    }

    func generateAnnotationCardDraft(
        _ annotation: DocumentAnnotation
    ) async -> KnowledgeCardDraft? {
        let selectedText = annotation.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = annotation.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedText.isEmpty, !note.isEmpty else {
            annotationCardErrorMessage = "这条批注缺少原文或备注，暂时无法生成卡片。"
            return nil
        }

        isGeneratingAnnotationCard = true
        annotationCardNotice = nil
        annotationCardErrorMessage = nil
        defer { isGeneratingAnnotationCard = false }

        do {
            let settings = AppSettingsStore.load()
            if settings.demoModeEnabled {
                annotationCardNotice = "本地 Demo AI 已根据批注生成卡片草稿：内容未发送到任何模型服务商。"
                return demoAIService.annotationKnowledgeCardDraft(
                    documentTitle: annotation.documentTitle,
                    selectedText: selectedText,
                    note: note
                )
            }

            guard let apiKey = try keychainService.loadAPIKey(), !apiKey.isEmpty else {
                throw AIServiceError.missingAPIKey
            }

            let prompt = PromptTemplates.annotationKnowledgeCard(
                selectedText: selectedText,
                note: note
            )
            let summary = try await aiService.sendChatCompletion(
                endpoint: settings.apiEndpoint,
                apiKey: apiKey,
                model: settings.modelName,
                messages: [AIMessage(role: "user", content: prompt.content)]
            )
            annotationCardNotice = prompt.wasTruncated
                ? "当前仅处理批注上下文前 4000 个字符，请结合原文继续核验。"
                : nil
            return annotationCardService.draft(
                documentTitle: annotation.documentTitle,
                selectedText: selectedText,
                note: note,
                generatedSummary: summary
            )
        } catch {
            annotationCardErrorMessage = aiErrorRecoveryService.message(
                for: error,
                action: .annotationCard
            )
            return nil
        }
    }

    func explainSelectedText() async {
        let selectedText = selectedPDFText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedText.isEmpty else {
            aiSelectionErrorMessage = "请先在正文中选择需要解释的文本。"
            return
        }

        isExplainingSelection = true
        aiSelectionErrorMessage = nil
        aiSelectionNotice = nil
        defer { isExplainingSelection = false }

        do {
            let settings = AppSettingsStore.load()
            if settings.demoModeEnabled {
                aiSelectionExplanation = demoAIService.conceptExplanation(selectedText)
                aiSelectionNotice = "本地 Demo AI 已开启：选区未发送到任何模型服务商。"
            } else {
                guard let apiKey = try keychainService.loadAPIKey(), !apiKey.isEmpty else {
                    throw AIServiceError.missingAPIKey
                }

                let prompt = PromptTemplates.conceptExplanation(selectedText)
                aiSelectionExplanation = try await aiService.sendChatCompletion(
                    endpoint: settings.apiEndpoint,
                    apiKey: apiKey,
                    model: settings.modelName,
                    messages: [AIMessage(role: "user", content: prompt.content)]
                )
                aiSelectionNotice = prompt.wasTruncated
                    ? "当前 Demo 仅解释选区前 4000 个字符，请结合原文继续核验。"
                    : nil
            }
        } catch {
            aiSelectionErrorMessage = aiErrorRecoveryService.message(
                for: error,
                action: .selectionExplanation
            )
        }
    }

    private func resetAIState() {
        aiSummary = ""
        aiSummaryNotice = nil
        aiErrorMessage = nil
        isSummarizing = false
        suggestedCardDrafts = []
        aiSelectionExplanation = ""
        aiSelectionNotice = nil
        aiSelectionErrorMessage = nil
        isExplainingSelection = false
        aiSelectionCardNotice = nil
        aiSelectionCardErrorMessage = nil
        isGeneratingSelectionCard = false
        annotationCardNotice = nil
        annotationCardErrorMessage = nil
        isGeneratingAnnotationCard = false
    }

    private func realAISummaryNotice(wasTruncated: Bool) -> String {
        if wasTruncated {
            return "当前仅处理文档前 12000 个字符；真实 API 已生成摘要和卡片草稿，请结合原文核验。"
        }
        return "真实 API 已生成摘要和卡片草稿，请结合原文核验后再沉淀。"
    }
}
