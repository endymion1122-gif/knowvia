import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct KnowledgePathwayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \DocumentItem.importedAt, order: .reverse) private var documents: [DocumentItem]
    @Query(sort: \KnowledgeCard.updatedAt, order: .reverse) private var cards: [KnowledgeCard]
    @Query(sort: \KnowledgeRelation.updatedAt, order: .reverse) private var relations: [KnowledgeRelation]

    let pathway: KnowledgePathway

    @State private var showsNodeEditor = false
    @State private var showsRelationEditor = false
    @State private var inspectingCard: KnowledgeCard?
    @State private var editingCard: KnowledgeCard?
    @State private var calibratingCard: KnowledgeCard?
    @State private var editingSourceDocument: DocumentItem?
    @State private var showsExternalCandidateImporter = false
    @State private var sourceSearchText = ""
    @State private var sourceKindFilter: DocumentSourceKind?
    @State private var sourceCredibilityFilter: SourceCredibilityLevel?
    @State private var sourceQualityFilter: SourceQualityFilter?
    @State private var nodeKindFilter: KnowledgeCardKind?
    @State private var nodeSourceQualityFilter: SourceQualityFilter?
    @State private var errorMessage: String?
    @State private var exportFeedback: String?

    private let pathwayService = KnowledgePathwayService()
    private let relationService = KnowledgeRelationService()
    private let sourceService = KnowledgeCardSourceService()
    private let readingProgressService = DocumentReadingProgressService()
    private let markdownExportService = KnowledgePathwayMarkdownExportService()
    private let calibrationService = KnowledgeCardCalibrationService()
    private let gapService = KnowledgePathwayGapService()
    private let writingReadinessService = KnowledgePathwayWritingReadinessService()
    private let writingOutlineService = KnowledgePathwayWritingOutlineService()
    private let writingActionService = KnowledgePathwayWritingActionService()
    private let nodeFilterService = KnowledgePathwayNodeFilterService()
    private let sourceFolderService = PathwaySourceFolderService()
    private let sourceSectionID = "pathway-source-folder-section"
    private let candidateSectionID = "pathway-candidate-section"
    private let nodeSectionID = "pathway-node-section"

    private var sourceDocuments: [DocumentItem] {
        pathwayService.documents(for: pathway, in: documents)
    }

    private var nodes: [KnowledgeCard] {
        pathwayService.cards(for: pathway, in: cards)
    }

    private var filteredNodes: [KnowledgeCard] {
        nodeFilterService.filter(
            nodes,
            documents: documents,
            kind: nodeKindFilter,
            sourceQuality: nodeSourceQualityFilter
        )
    }

    private var candidateDocuments: [DocumentItem] {
        pathwayService.candidateDocuments(for: pathway, in: documents)
    }

    private var filteredSourceDocuments: [DocumentItem] {
        sourceFolderService.filter(
            sourceDocuments,
            query: sourceSearchText,
            sourceKind: sourceKindFilter,
            credibility: sourceCredibilityFilter,
            quality: sourceQualityFilter
        )
    }

    private var unverifiedSourceCount: Int {
        sourceFolderService.filter(sourceDocuments, quality: .needsVerification).count
    }

    private var missingMetadataSourceCount: Int {
        sourceFolderService.filter(sourceDocuments, quality: .missingMetadata).count
    }

    private var overview: KnowledgePathwayOverview {
        pathwayService.overview(for: pathway, in: cards)
    }

    private var sourceQualityOverview: SourceQualityOverview {
        sourceFolderService.qualityOverview(
            sources: sourceDocuments,
            candidates: candidateDocuments
        )
    }

    private var resolvedRelations: [ResolvedKnowledgeRelation] {
        relationService.resolvedRelations(
            for: pathway,
            relations: relations,
            cards: cards
        )
    }

    private var claimEvidencePairs: [ClaimEvidencePair] {
        relationService.claimEvidencePairs(
            for: pathway,
            relations: relations,
            cards: cards
        )
    }

    private var gaps: [KnowledgePathwayGap] {
        gapService.gaps(
            for: pathway,
            cards: cards,
            relations: relations,
            documents: documents
        )
    }

    private var writingReadinessChecks: [KnowledgePathwayWritingReadinessCheck] {
        writingReadinessService.checks(
            for: pathway,
            cards: cards,
            relations: relations,
            documents: documents
        )
    }

    private var writingOutline: [KnowledgePathwayWritingOutlineSection] {
        writingOutlineService.outline(
            for: pathway,
            cards: cards,
            relations: relations
        )
    }

    private var writingActions: [KnowledgePathwayWritingAction] {
        writingActionService.actions(
            for: pathway,
            cards: cards,
            relations: relations,
            documents: documents
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        pathwaySummary
                        sourceQualitySection(scrollProxy: scrollProxy)
                        localOverview
                        gapSection
                        writingReadinessSection
                        writingOutlineSection
                        writingActionsSection(scrollProxy: scrollProxy)
                        relationSection
                        claimEvidenceSection
                        sourceSection
                            .id(sourceSectionID)
                        externalCandidateSection
                            .id(candidateSectionID)
                        nodeSection
                            .id(nodeSectionID)
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 920, idealWidth: 1080, minHeight: 720, idealHeight: 820)
        .background(AppTheme.pageBackground)
        .sheet(isPresented: $showsNodeEditor) {
            PathwayKnowledgeNodesEditorView(
                pathway: pathway,
                cards: cards
            ) { selectedCardIDs in
                updateKnowledgeNodes(selectedCardIDs)
            }
        }
        .sheet(isPresented: $showsRelationEditor) {
            PathwayRelationEditorView(
                pathway: pathway,
                cards: nodes,
                relations: relations,
                onAdd: createRelation,
                onDelete: deleteRelation
            )
        }
        .sheet(item: $inspectingCard) { card in
            KnowledgeCardDetailView(
                card: card,
                onEdit: { editingCard = card },
                onOpenSource: card.sourceDocumentId == nil ? nil : { openSource(for: card) }
            )
        }
        .sheet(item: $editingCard) { card in
            KnowledgeCardEditorView(card: card)
        }
        .sheet(item: $calibratingCard) { card in
            KnowledgeCardCalibrationEditorView(card: card) { status, isHighlighted, isUnderstood, note in
                updateCalibration(
                    for: card,
                    status: status,
                    isHighlighted: isHighlighted,
                    isUnderstood: isUnderstood,
                    note: note
                )
            }
        }
        .sheet(item: $editingSourceDocument) { document in
            DocumentMetadataEditorView(document: document) { draft in
                update(document, draft: draft)
            }
        }
        .sheet(isPresented: $showsExternalCandidateImporter) {
            WebSourceImportView(mode: .externalCandidate) { document in
                insertExternalCandidate(document)
            }
        }
        .alert("专题路径操作失败", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("专题报告导出完成", isPresented: exportFeedbackBinding) {
            Button("知道了") {
                exportFeedback = nil
            }
        } message: {
            Text(exportFeedback ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 19))
                .foregroundStyle(AppTheme.softViolet)
                .frame(width: 46, height: 46)
                .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(pathway.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Text("专题路径详情 · 多源资料与知识节点")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.pathTeal)
            }

            Spacer()

            Button {
                exportMarkdownReport()
            } label: {
                Label("导出报告", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button {
                showsRelationEditor = true
            } label: {
                Label("管理关系", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button {
                showsNodeEditor = true
            } label: {
                Label("管理知识节点", systemImage: "rectangle.stack.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.coolGray.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(AppTheme.warmWhite)
    }

    private var pathwaySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                metric("\(sourceDocuments.count)", label: "来源资料")
                metric("\(candidateDocuments.count)", label: "补全候选")
                metric("\(nodes.count)", label: "知识节点")
                metric("\(overview.concepts.count)", label: "核心概念")
                metric("\(overview.evidence.count)", label: "关键证据")
                metric("\(gaps.count)", label: "待补提示")
            }

            Text(
                pathway.overview.isEmpty
                    ? "还没有专题总览。可以继续加入资料和知识节点，逐步形成可追溯的知识脉络。"
                    : pathway.overview
            )
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.secondaryText)
            .lineSpacing(4)

            if !pathway.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(pathway.tags, id: \.self) { tag in
                        tagBadge(tag)
                    }
                }
            }
        }
        .padding(15)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private var localOverview: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("路径概览", symbol: "sparkles")

            if overview.isEmpty {
                Text("加入知识节点后，这里会自动整理核心概念、主要观点、关键证据与待解决问题。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: 10)],
                    spacing: 10
                ) {
                    overviewBlock("核心概念", cards: overview.concepts, accent: AppTheme.deepIndigo)
                    overviewBlock("主要观点", cards: overview.arguments, accent: AppTheme.softPlum)
                    overviewBlock("关键证据", cards: overview.evidence, accent: AppTheme.pathTeal)
                    overviewBlock("待解决问题", cards: overview.questions, accent: AppTheme.knowledgeBlue)
                }
            }
        }
        .sectionCard()
    }

    private func sourceQualitySection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("来源质量概览", symbol: "checkmark.seal")

            if sourceQualityOverview.totalSources == 0 {
                Text("加入正式来源后，这里会显示元数据完整度、核验进度和权威来源覆盖情况。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), spacing: 10)],
                    spacing: 10
                ) {
                    qualityMetric(
                        "元数据完整",
                        value: "\(sourceQualityOverview.completeMetadataSources)/\(sourceQualityOverview.totalSources)",
                        detail: percent(sourceQualityOverview.metadataCompletionRatio),
                        accent: AppTheme.knowledgeBlue
                    )
                    qualityMetric(
                        "已核验",
                        value: "\(sourceQualityOverview.totalSources - sourceQualityOverview.unverifiedSources)/\(sourceQualityOverview.totalSources)",
                        detail: percent(sourceQualityOverview.verificationRatio),
                        accent: AppTheme.pathTeal
                    )
                    qualityMetric(
                        "权威来源",
                        value: "\(sourceQualityOverview.authoritativeSources)",
                        detail: "核心证据",
                        accent: AppTheme.deepIndigo
                    )
                    qualityMetric(
                        "补全候选",
                        value: "\(sourceQualityOverview.candidateSources)",
                        detail: "待确认",
                        accent: AppTheme.softViolet
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    ProgressView(value: sourceQualityOverview.metadataCompletionRatio)
                        .tint(AppTheme.knowledgeBlue)
                    Text("元数据完整度：作者、年份和网页链接会影响报告可追溯性。")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                HStack(spacing: 8) {
                    qualityShortcut(
                        "查看待核验",
                        count: unverifiedSourceCount,
                        symbol: "exclamationmark.shield",
                        filter: .needsVerification,
                        scrollProxy: scrollProxy
                    )
                    qualityShortcut(
                        "补作者年份",
                        count: missingMetadataSourceCount,
                        symbol: "person.text.rectangle",
                        filter: .missingMetadata,
                        scrollProxy: scrollProxy
                    )
                    qualityShortcut(
                        "看权威来源",
                        count: sourceQualityOverview.authoritativeSources,
                        symbol: "checkmark.seal",
                        filter: .authoritative,
                        scrollProxy: scrollProxy
                    )
                    Spacer()
                    if sourceQualityFilter != nil || sourceCredibilityFilter != nil || sourceKindFilter != nil || !sourceSearchText.isEmpty {
                        Button("清除筛选") {
                            resetSourceFilters()
                            withAnimation(.easeInOut(duration: 0.24)) {
                                scrollProxy.scrollTo(sourceSectionID, anchor: .top)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.softViolet)
                    }
                }
            }
        }
        .sectionCard()
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("来源资料夹", symbol: "books.vertical")
                Spacer()
                Text("\(filteredSourceDocuments.count) / \(sourceDocuments.count) 份")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            if sourceDocuments.isEmpty {
                Text("尚未加入来源资料。可以从专题路径库菜单或资料库菜单进行归类。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                sourceFilters

                if filteredSourceDocuments.isEmpty {
                    Text("没有符合当前筛选条件的来源资料。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320), spacing: 9)],
                    spacing: 9
                ) {
                    ForEach(filteredSourceDocuments) { document in
                        sourceDocumentCard(document)
                    }
                }
            }
        }
        .sectionCard()
    }

    private var sourceFilters: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.tertiaryText)
                TextField("搜索标题、作者、年份或贡献", text: $sourceSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 7))

            Picker("类型", selection: $sourceKindFilter) {
                Text("全部类型").tag(DocumentSourceKind?.none)
                ForEach(DocumentSourceKind.allCases) { kind in
                    Text(kind.title).tag(Optional(kind))
                }
            }
            .frame(width: 120)

            Picker("可信度", selection: $sourceCredibilityFilter) {
                Text("全部可信度").tag(SourceCredibilityLevel?.none)
                ForEach(SourceCredibilityLevel.allCases) { level in
                    Text(level.title).tag(Optional(level))
                }
            }
            .frame(width: 130)

            Picker("质量", selection: $sourceQualityFilter) {
                Text("全部质量").tag(SourceQualityFilter?.none)
                ForEach(SourceQualityFilter.allCases) { filter in
                    Text(filter.title).tag(Optional(filter))
                }
            }
            .frame(width: 122)
        }
    }

    private var externalCandidateSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("外部补全候选", symbol: "link.badge.plus")
                Spacer()
                Button {
                    showsExternalCandidateImporter = true
                } label: {
                    Label("添加候选", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.softViolet)
            }

            Text("候选资料与正式来源分开保存。阅读并确认后，再纳入专题路径。")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)

            if candidateDocuments.isEmpty {
                Text("暂无候选资料。遇到来源不足时，可以手动记录待核验的网页或参考资料。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.tertiaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300), spacing: 9)],
                    spacing: 9
                ) {
                    ForEach(candidateDocuments) { document in
                        externalCandidateCard(document)
                    }
                }
            }
        }
        .sectionCard()
    }

    private var gapSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("待补全提示", symbol: "exclamationmark.bubble")

            if gaps.isEmpty {
                Label("当前路径的基础结构已经比较完整。", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.pathTeal)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260), spacing: 9)],
                    spacing: 9
                ) {
                    ForEach(gaps) { gap in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(gap.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.softPlum)
                            Text(gap.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineSpacing(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.warmIvory, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Text("提示由本地规则生成，用来帮助你校准路径，不代表自动判断。")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .sectionCard()
    }

    private var writingReadinessSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("写作准备度", symbol: "doc.text.magnifyingglass")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: 9)],
                spacing: 9
            ) {
                ForEach(writingReadinessChecks) { check in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: writingReadinessSymbol(check.status))
                                .font(.system(size: 10, weight: .semibold))
                            Text(check.status.title)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(writingReadinessAccent(check.status))

                        Text(check.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)

                        Text(check.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Text("准备度由本地结构规则生成，只帮助检查资料、节点和证据链，不会自动生成论文。")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .sectionCard()
    }

    private var writingOutlineSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("写作准备大纲", symbol: "list.bullet.rectangle")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: 9)],
                spacing: 9
            ) {
                ForEach(writingOutline) { section in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)

                        ForEach(section.bullets.prefix(4), id: \.self) { bullet in
                            Text("• \(bullet)")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(3)
                                .lineSpacing(2)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Text("大纲草稿只按本地节点和关系整理写作前材料，不会自动生成正文。")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .sectionCard()
    }

    private func writingActionsSection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("写作行动清单", symbol: "checklist")

            if writingActions.isEmpty {
                Label("当前没有明显的写作前阻塞项。", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.pathTeal)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260), spacing: 9)],
                    spacing: 9
                ) {
                    ForEach(writingActions) { action in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 6) {
                                Image(systemName: writingActionSymbol(action.priority))
                                    .font(.system(size: 10, weight: .semibold))
                                Text(action.priority.title)
                                    .font(.system(size: 10, weight: .semibold))
                                if action.relatedCount > 0 {
                                    Text("\(action.relatedCount)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(
                                            writingActionAccent(action.priority).opacity(0.14),
                                            in: Capsule()
                                        )
                                }
                            }
                            .foregroundStyle(writingActionAccent(action.priority))

                            Text(action.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.deepIndigo)

                            Text(action.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineSpacing(2)
                                .lineLimit(3)

                            if !action.relatedTitles.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(action.relatedTitles, id: \.self) { title in
                                        Text("• \(title)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.tertiaryText)
                                            .lineLimit(1)
                                    }
                                }
                            }

                            if action.target != nil {
                                Button {
                                    focusWritingAction(action, scrollProxy: scrollProxy)
                                } label: {
                                    Label("定位", systemImage: "scope")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(writingActionAccent(action.priority))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Text("行动清单只整理写作前需要补证据、核来源和校准节点的任务，不会生成正文。")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .sectionCard()
    }

    private func sourceDocumentCard(_ document: DocumentItem) -> some View {
        let relatedCards = sourceFolderService.relatedCards(for: document, in: nodes)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    open(document)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: document.sourceType == .webPage ? "link" : "doc.text")
                            .foregroundStyle(AppTheme.pathTeal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(document.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)
                            Text(document.attributionDescription ?? "作者与年份待补充")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    editingSourceDocument = document
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.softViolet)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.paleLavender, in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 5) {
                sourceBadge(document.sourceType.title, accent: AppTheme.slateBlue)
                sourceBadge(document.credibility.title, accent: credibilityAccent(document.credibility))
                sourceBadge("\(relatedCards.count) 个节点", accent: AppTheme.pathTeal)
            }

            Text(
                document.contributionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "主要贡献尚待整理。点击编辑补充这份资料在专题中的作用。"
                    : document.contributionNote
            )
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.secondaryText)
            .lineLimit(3)

            if !relatedCards.isEmpty {
                HStack(spacing: 6) {
                    ForEach(relatedCards.prefix(3)) { card in
                        Button {
                            inspectingCard = card
                        } label: {
                            Text(card.title)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.deepIndigo)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(AppTheme.paleLavender, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func externalCandidateCard(_ document: DocumentItem) -> some View {
        let advice = sourceFolderService.candidateAdvice(for: document)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(AppTheme.softViolet)
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Text(document.attributionDescription ?? document.sourceURLString)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                }
                Spacer()
                sourceBadge("需核验", accent: AppTheme.softPlum)
            }

            if !document.sourceNote.isEmpty {
                Text(document.sourceNote)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                    .frame(width: 18, height: 18)
                    .background(AppTheme.paleLavender, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(advice.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(advice.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(8)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button("打开阅读") {
                    open(document)
                }
                Button("编辑信息") {
                    editingSourceDocument = document
                }
                Spacer()
                Button("移出候选") {
                    removeExternalCandidate(document)
                }
                .foregroundStyle(AppTheme.softPlum)
                Button("纳入路径") {
                    confirmExternalCandidate(document)
                }
                .foregroundStyle(AppTheme.pathTeal)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.warmIvory, in: RoundedRectangle(cornerRadius: 8))
    }

    private func qualityShortcut(
        _ title: String,
        count: Int,
        symbol: String,
        filter: SourceQualityFilter,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        Button {
            sourceSearchText = ""
            sourceKindFilter = nil
            sourceCredibilityFilter = nil
            sourceQualityFilter = filter
            withAnimation(.easeInOut(duration: 0.24)) {
                scrollProxy.scrollTo(sourceSectionID, anchor: .top)
            }
        } label: {
            Label("\(title) \(count)", systemImage: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(sourceQualityFilter == filter ? .white : AppTheme.deepIndigo)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    sourceQualityFilter == filter ? AppTheme.deepIndigo : AppTheme.pageBackground,
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.45 : 1)
    }

    private func sourceBadge(_ title: String, accent: Color) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(accent.opacity(0.10), in: Capsule())
    }

    private func credibilityAccent(_ credibility: SourceCredibilityLevel) -> Color {
        switch credibility {
        case .authoritative: AppTheme.pathTeal
        case .userProvided: AppTheme.knowledgeBlue
        case .needsVerification: AppTheme.softPlum
        case .unreviewed: AppTheme.slateBlue
        }
    }

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("关系组织", symbol: "point.3.connected.trianglepath.dotted")
                Spacer()
                Button("管理关系") {
                    showsRelationEditor = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.softViolet)
            }

            if resolvedRelations.isEmpty {
                Text("还没有节点关系。可以先从定义、支持、挑战、扩展和相关五类关系开始，逐步整理知识脉络。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(resolvedRelations) { resolved in
                        relationRow(resolved)
                    }
                }
            }
        }
        .sectionCard()
    }

    private var claimEvidenceSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("观点—证据链", symbol: "link")

            if claimEvidencePairs.isEmpty {
                Text("将证据节点与观点节点建立“支持”关系后，这里会形成可回溯的观点—证据链。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(claimEvidencePairs) { pair in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(pair.claim.title, systemImage: "quote.bubble")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.softPlum)
                                .lineLimit(2)

                            HStack(spacing: 7) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.pathTeal)
                                Text("由证据支持")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.pathTeal)
                            }

                            Button {
                                inspectingCard = pair.evidence
                            } label: {
                                Label(pair.evidence.title, systemImage: "link")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .sectionCard()
    }

    private var nodeSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                sectionTitle("知识节点", symbol: "rectangle.stack")
                Spacer()
                Text("\(filteredNodes.count) / \(nodes.count) 个")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            if nodes.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("还没有知识节点。")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("可以管理已有卡片，也可以在阅读器中选择名词、句子或片段，让 AI 生成卡片草稿并直接归入当前专题。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("管理知识节点") {
                        showsNodeEditor = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                }
            } else {
                nodeFilters

                if filteredNodes.isEmpty {
                    Text("没有符合当前筛选条件的知识节点。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                ForEach(nodeGroups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 9) {
                        Text("\(group.title) · \(group.cards.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(group.accent)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 230, maximum: 340), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(group.cards) { card in
                                KnowledgeCardView(
                                    card: card,
                                    onOpenSource: card.sourceDocumentId == nil ? nil : { openSource(for: card) },
                                    onOpenDetail: { inspectingCard = card },
                                    onEdit: { editingCard = card },
                                    onToggleHighlighted: { toggleHighlighted(card) },
                                    onToggleUnderstood: { toggleUnderstood(card) },
                                    onConfirm: { confirm(card) },
                                    onCalibrate: { calibratingCard = card }
                                )
                            }
                        }
                    }
                }
            }
        }
        .sectionCard()
    }

    private var nodeFilters: some View {
        HStack(spacing: 8) {
            Picker("节点类型", selection: $nodeKindFilter) {
                Text("全部节点").tag(KnowledgeCardKind?.none)
                ForEach(KnowledgeCardKind.allCases) { kind in
                    Text(kind.title).tag(Optional(kind))
                }
            }
            .frame(width: 126)

            Picker("来源质量", selection: $nodeSourceQualityFilter) {
                Text("全部来源质量").tag(SourceQualityFilter?.none)
                ForEach(SourceQualityFilter.allCases) { filter in
                    Text(filter.title).tag(Optional(filter))
                }
            }
            .frame(width: 150)

            Button {
                nodeKindFilter = .argument
                nodeSourceQualityFilter = .needsVerification
            } label: {
                Label("待核验观点", systemImage: "quote.bubble")
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppTheme.softPlum)

            Button {
                nodeKindFilter = .evidence
                nodeSourceQualityFilter = .missingMetadata
            } label: {
                Label("待补证据", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppTheme.softViolet)

            Spacer()

            if nodeKindFilter != nil || nodeSourceQualityFilter != nil {
                Button("清除筛选") {
                    resetNodeFilters()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
            }
        }
    }

    private var nodeGroups: [(title: String, cards: [KnowledgeCard], accent: Color)] {
        let filteredOverview = KnowledgePathwayOverview(
            concepts: filteredNodes.filter { $0.kind == .concept },
            arguments: filteredNodes.filter { $0.kind == .argument },
            evidence: filteredNodes.filter { $0.kind == .evidence },
            questions: filteredNodes.filter { $0.kind == .question },
            otherNodes: filteredNodes.filter {
                ![.concept, .argument, .evidence, .question].contains($0.kind)
            }
        )
        return [
            ("概念", filteredOverview.concepts, AppTheme.deepIndigo),
            ("观点", filteredOverview.arguments, AppTheme.softPlum),
            ("证据", filteredOverview.evidence, AppTheme.pathTeal),
            ("问题", filteredOverview.questions, AppTheme.knowledgeBlue),
            ("其他节点", filteredOverview.otherNodes, AppTheme.slateBlue),
        ]
        .filter { !$0.1.isEmpty }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var exportFeedbackBinding: Binding<Bool> {
        Binding(
            get: { exportFeedback != nil },
            set: { if !$0 { exportFeedback = nil } }
        )
    }

    private func overviewBlock(
        _ title: String,
        cards: [KnowledgeCard],
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
            if cards.isEmpty {
                Text("尚待补充")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiaryText)
            } else {
                ForEach(cards.prefix(3)) { card in
                    Text("• \(card.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func qualityMetric(
        _ title: String,
        value: String,
        detail: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func relationRow(_ resolved: ResolvedKnowledgeRelation) -> some View {
        HStack(spacing: 10) {
            Button {
                inspectingCard = resolved.sourceCard
            } label: {
                Text(resolved.sourceCard.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(spacing: 3) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                Text(resolved.relation.kind.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(relationAccent(resolved.relation.kind))
            .frame(width: 54)

            Button {
                inspectingCard = resolved.targetCard
            } label: {
                Text(resolved.targetCard.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(AppTheme.pageBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func relationAccent(_ kind: KnowledgeRelationKind) -> Color {
        switch kind {
        case .defines: AppTheme.deepIndigo
        case .supports: AppTheme.pathTeal
        case .challenges: AppTheme.softPlum
        case .extends: AppTheme.softViolet
        case .relatedTo: AppTheme.slateBlue
        }
    }

    private func writingReadinessAccent(_ status: KnowledgePathwayWritingReadinessStatus) -> Color {
        switch status {
        case .ready: AppTheme.pathTeal
        case .attention: AppTheme.softViolet
        case .blocker: AppTheme.softPlum
        }
    }

    private func writingReadinessSymbol(_ status: KnowledgePathwayWritingReadinessStatus) -> String {
        switch status {
        case .ready: "checkmark.seal.fill"
        case .attention: "exclamationmark.circle.fill"
        case .blocker: "xmark.octagon.fill"
        }
    }

    private func writingActionAccent(_ priority: KnowledgePathwayWritingActionPriority) -> Color {
        switch priority {
        case .high: AppTheme.softPlum
        case .medium: AppTheme.softViolet
        case .low: AppTheme.pathTeal
        }
    }

    private func writingActionSymbol(_ priority: KnowledgePathwayWritingActionPriority) -> String {
        switch priority {
        case .high: "flag.fill"
        case .medium: "circle.lefthalf.filled"
        case .low: "checkmark.circle.fill"
        }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.deepIndigo)
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func tagBadge(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.slateBlue)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(AppTheme.coolGray.opacity(0.72), in: Capsule())
    }

    private func updateKnowledgeNodes(_ selectedCardIDs: Set<UUID>) {
        let removedCardIDs = Set(pathway.knowledgeCardIDs).subtracting(selectedCardIDs)
        for relation in relationService.relations(for: pathway, in: relations)
        where removedCardIDs.contains(relation.sourceCardID)
            || removedCardIDs.contains(relation.targetCardID) {
            modelContext.delete(relation)
        }
        pathwayService.updateKnowledgeNodes(
            for: pathway,
            selectedCardIDs: selectedCardIDs,
            cards: cards
        )
        do {
            try modelContext.save()
            showsNodeEditor = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetSourceFilters() {
        sourceSearchText = ""
        sourceKindFilter = nil
        sourceCredibilityFilter = nil
        sourceQualityFilter = nil
    }

    private func resetNodeFilters() {
        nodeKindFilter = nil
        nodeSourceQualityFilter = nil
    }

    private func focusWritingAction(
        _ action: KnowledgePathwayWritingAction,
        scrollProxy: ScrollViewProxy
    ) {
        guard let target = action.target else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            if let sourceQuality = target.sourceQuality {
                sourceQualityFilter = sourceQuality
                scrollProxy.scrollTo(sourceSectionID, anchor: .top)
            }

            if target.focusesCandidates {
                scrollProxy.scrollTo(candidateSectionID, anchor: .top)
            }

            if target.nodeKind != nil || target.nodeSourceQuality != nil {
                nodeKindFilter = target.nodeKind
                nodeSourceQualityFilter = target.nodeSourceQuality
                scrollProxy.scrollTo(nodeSectionID, anchor: .top)
            }
        }
    }

    private func update(_ document: DocumentItem, draft: DocumentMetadataDraft) {
        document.title = draft.title
        document.tags = draft.tags
        document.sourceKind = draft.sourceKind
        document.author = draft.author
        document.publicationYear = draft.publicationYear
        document.sourceURLString = draft.sourceURLString
        document.sourceNote = draft.sourceNote
        document.credibilityLevel = draft.credibilityLevel
        document.contributionNote = draft.contributionNote
        document.updatedAt = Date()

        do {
            try modelContext.save()
            editingSourceDocument = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func insertExternalCandidate(_ document: DocumentItem) {
        modelContext.insert(document)
        pathwayService.addCandidate(document, to: pathway)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmExternalCandidate(_ document: DocumentItem) {
        pathwayService.confirmCandidate(document, for: pathway)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeExternalCandidate(_ document: DocumentItem) {
        pathwayService.removeCandidate(document, from: pathway)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createRelation(
        _ sourceCardID: UUID,
        _ targetCardID: UUID,
        _ kind: KnowledgeRelationKind,
        _ note: String
    ) {
        do {
            let relation = try relationService.makeRelation(
                pathwayID: pathway.id,
                sourceCardID: sourceCardID,
                targetCardID: targetCardID,
                kind: kind,
                note: note,
                existingRelations: relations
            )
            modelContext.insert(relation)
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRelation(_ relation: KnowledgeRelation) {
        modelContext.delete(relation)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleHighlighted(_ card: KnowledgeCard) {
        calibrationService.toggleHighlighted(card)
        saveCalibrationChanges()
    }

    private func toggleUnderstood(_ card: KnowledgeCard) {
        calibrationService.toggleUnderstood(card)
        saveCalibrationChanges()
    }

    private func confirm(_ card: KnowledgeCard) {
        calibrationService.confirm(card)
        saveCalibrationChanges()
    }

    private func updateCalibration(
        for card: KnowledgeCard,
        status: KnowledgeCardCalibrationStatus,
        isHighlighted: Bool,
        isUnderstood: Bool,
        note: String
    ) {
        calibrationService.update(
            card,
            status: status,
            isHighlighted: isHighlighted,
            isUnderstood: isUnderstood,
            note: note
        )
        saveCalibrationChanges {
            calibratingCard = nil
        }
    }

    private func saveCalibrationChanges(onSuccess: () -> Void = {}) {
        do {
            try modelContext.save()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportMarkdownReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(safeFilename(pathway.title)) Knowledge Pathway.md"
        panel.title = "导出专题 Knowledge Pathway 报告"
        panel.message = "导出专题总览、来源列表、资料贡献矩阵、知识节点、节点关系、学习路径与待补全问题。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try markdownExportService.export(
                pathway: pathway,
                documents: documents,
                cards: cards,
                relations: relations,
                to: url
            )
            exportFeedback = "已导出《\(pathway.title)》专题报告。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func safeFilename(_ value: String) -> String {
        value
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private func open(_ document: DocumentItem) {
        readingProgressService.markOpened(document)
        do {
            try modelContext.save()
            dismiss()
            appState.open(document)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openSource(for card: KnowledgeCard) {
        do {
            let document = try sourceService.sourceDocument(for: card, in: documents)
            readingProgressService.markOpened(document)
            try modelContext.save()
            dismiss()
            appState.open(
                document,
                pageNumber: sourceService.targetPageNumber(for: card, in: document)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PathwayRelationEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let pathway: KnowledgePathway
    let cards: [KnowledgeCard]
    let relations: [KnowledgeRelation]
    let onAdd: (UUID, UUID, KnowledgeRelationKind, String) -> Void
    let onDelete: (KnowledgeRelation) -> Void

    @State private var sourceCardID: UUID?
    @State private var targetCardID: UUID?
    @State private var kind = KnowledgeRelationKind.supports
    @State private var note = ""

    private let relationService = KnowledgeRelationService()

    private var resolvedRelations: [ResolvedKnowledgeRelation] {
        relationService.resolvedRelations(
            for: pathway,
            relations: relations,
            cards: cards
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("管理节点关系")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(pathway.title)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.pathTeal)
                }
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    relationForm

                    VStack(alignment: .leading, spacing: 9) {
                        Text("已有关系")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)

                        if resolvedRelations.isEmpty {
                            Text("还没有关系。先添加一条轻量关系，让路径开始连接起来。")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.secondaryText)
                        } else {
                            ForEach(resolvedRelations) { resolved in
                                HStack(spacing: 9) {
                                    Text(resolved.sourceCard.title)
                                        .lineLimit(1)
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(AppTheme.tertiaryText)
                                    Text(resolved.relation.kind.title)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppTheme.pathTeal)
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(AppTheme.tertiaryText)
                                    Text(resolved.targetCard.title)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        onDelete(resolved.relation)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(AppTheme.softPlum)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(10)
                                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .frame(width: 740, height: 680)
        .background(AppTheme.pageBackground)
    }

    private var relationForm: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("新增关系")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)

            if cards.count < 2 {
                Text("至少需要两个知识节点才能建立关系。请先回到路径详情补充节点。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                HStack(spacing: 9) {
                    nodePicker("起点节点", selection: $sourceCardID)
                    relationPicker
                    nodePicker("终点节点", selection: $targetCardID)
                }

                TextField("关系备注，可选", text: $note)
                    .textFieldStyle(.roundedBorder)

                Button {
                    guard let sourceCardID, let targetCardID else {
                        return
                    }
                    onAdd(sourceCardID, targetCardID, kind, note)
                    note = ""
                } label: {
                    Label("添加关系", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.softViolet, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(sourceCardID == nil || targetCardID == nil)
                .opacity(sourceCardID == nil || targetCardID == nil ? 0.45 : 1)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.coolGray, lineWidth: 1)
        }
    }

    private func nodePicker(_ title: String, selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            Text(title).tag(UUID?.none)
            ForEach(cards) { card in
                Text(card.title).tag(UUID?.some(card.id))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
    }

    private var relationPicker: some View {
        Picker("关系", selection: $kind) {
            ForEach(KnowledgeRelationKind.allCases) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 94)
    }
}

private struct PathwayKnowledgeNodesEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let pathway: KnowledgePathway
    let cards: [KnowledgeCard]
    let onSave: (Set<UUID>) -> Void

    @State private var searchText = ""
    @State private var selectedCardIDs: Set<UUID>

    init(
        pathway: KnowledgePathway,
        cards: [KnowledgeCard],
        onSave: @escaping (Set<UUID>) -> Void
    ) {
        self.pathway = pathway
        self.cards = cards
        self.onSave = onSave
        _selectedCardIDs = State(initialValue: Set(pathway.knowledgeCardIDs))
    }

    private var filteredCards: [KnowledgeCard] {
        cards.filter {
            searchText.isEmpty
                || $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.content.localizedCaseInsensitiveContains(searchText)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("管理知识节点")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text(pathway.title)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.pathTeal)
                }
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
                Button("保存") {
                    onSave(selectedCardIDs)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(18)

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.tertiaryText)
                TextField("搜索卡片标题、内容或标签", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(10)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.coolGray, lineWidth: 1)
            }
            .padding(16)

            if cards.isEmpty {
                ContentUnavailableView(
                    "还没有知识卡片",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("先在阅读器中选择内容生成卡片，或进入知识卡片页新建卡片。")
                )
            } else if filteredCards.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredCards) { card in
                            Button {
                                toggle(card.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(
                                        systemName: selectedCardIDs.contains(card.id)
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                    .foregroundStyle(
                                        selectedCardIDs.contains(card.id)
                                            ? AppTheme.softViolet
                                            : AppTheme.tertiaryText
                                    )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(card.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(AppTheme.primaryText)
                                        Text("\(card.kind.title)卡 · \(card.sourceDescription ?? "未关联资料")")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 680, height: 680)
        .background(AppTheme.pageBackground)
    }

    private func toggle(_ cardID: UUID) {
        if selectedCardIDs.contains(cardID) {
            selectedCardIDs.remove(cardID)
        } else {
            selectedCardIDs.insert(cardID)
        }
    }
}

private extension View {
    func sectionCard() -> some View {
        padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.coolGray, lineWidth: 1)
            }
    }
}
