import Foundation

struct KnowledgePathwayOverview {
    let concepts: [KnowledgeCard]
    let arguments: [KnowledgeCard]
    let evidence: [KnowledgeCard]
    let questions: [KnowledgeCard]
    let otherNodes: [KnowledgeCard]

    var isEmpty: Bool {
        concepts.isEmpty
            && arguments.isEmpty
            && evidence.isEmpty
            && questions.isEmpty
            && otherNodes.isEmpty
    }
}

struct KnowledgePathwayService {
    func pathways(
        for document: DocumentItem,
        in pathways: [KnowledgePathway]
    ) -> [KnowledgePathway] {
        pathways.filter { document.pathwayIDs.contains($0.id) }
    }

    func documents(
        for pathway: KnowledgePathway,
        in documents: [DocumentItem]
    ) -> [DocumentItem] {
        documents.filter { pathway.sourceDocumentIDs.contains($0.id) }
    }

    func candidateDocuments(
        for pathway: KnowledgePathway,
        in documents: [DocumentItem]
    ) -> [DocumentItem] {
        documents.filter { pathway.candidateDocumentIDs.contains($0.id) }
    }

    func pathways(
        for card: KnowledgeCard,
        in pathways: [KnowledgePathway]
    ) -> [KnowledgePathway] {
        pathways.filter { card.pathwayIDs.contains($0.id) }
    }

    func cards(
        for pathway: KnowledgePathway,
        in cards: [KnowledgeCard]
    ) -> [KnowledgeCard] {
        cards.filter { pathway.knowledgeCardIDs.contains($0.id) }
    }

    func overview(
        for pathway: KnowledgePathway,
        in cards: [KnowledgeCard]
    ) -> KnowledgePathwayOverview {
        let nodes = self.cards(for: pathway, in: cards)
        return KnowledgePathwayOverview(
            concepts: nodes.filter { $0.kind == .concept },
            arguments: nodes.filter { $0.kind == .argument },
            evidence: nodes.filter { $0.kind == .evidence },
            questions: nodes.filter { $0.kind == .question },
            otherNodes: nodes.filter {
                ![.concept, .argument, .evidence, .question].contains($0.kind)
            }
        )
    }

    func updateAssignments(
        for document: DocumentItem,
        selectedPathwayIDs: Set<UUID>,
        pathways: [KnowledgePathway]
    ) {
        for pathway in pathways {
            if selectedPathwayIDs.contains(pathway.id) {
                add(document, to: pathway)
            } else {
                remove(document, from: pathway)
            }
        }
        document.pathwayIDs = unique(document.pathwayIDs.filter(selectedPathwayIDs.contains))
        document.updatedAt = Date()
    }

    func updateSources(
        for pathway: KnowledgePathway,
        selectedDocumentIDs: Set<UUID>,
        documents: [DocumentItem]
    ) {
        for document in documents {
            if selectedDocumentIDs.contains(document.id) {
                add(document, to: pathway)
            } else {
                remove(document, from: pathway)
            }
        }
        pathway.sourceDocumentIDs = unique(pathway.sourceDocumentIDs.filter(selectedDocumentIDs.contains))
        pathway.updatedAt = Date()
    }

    func addCandidate(_ document: DocumentItem, to pathway: KnowledgePathway) {
        if !pathway.candidateDocumentIDs.contains(document.id) {
            pathway.candidateDocumentIDs.append(document.id)
        }
        document.sourceKind = DocumentSourceKind.externalEnrichment.rawValue
        document.credibilityLevel = SourceCredibilityLevel.needsVerification.rawValue
        document.updatedAt = Date()
        pathway.updatedAt = Date()
    }

    func confirmCandidate(_ document: DocumentItem, for pathway: KnowledgePathway) {
        pathway.candidateDocumentIDs.removeAll { $0 == document.id }
        add(document, to: pathway)
        pathway.updatedAt = Date()
    }

    func removeCandidate(_ document: DocumentItem, from pathway: KnowledgePathway) {
        pathway.candidateDocumentIDs.removeAll { $0 == document.id }
        pathway.updatedAt = Date()
    }

    func updateAssignments(
        for card: KnowledgeCard,
        selectedPathwayIDs: Set<UUID>,
        pathways: [KnowledgePathway]
    ) {
        for pathway in pathways {
            if selectedPathwayIDs.contains(pathway.id) {
                add(card, to: pathway)
            } else {
                remove(card, from: pathway)
            }
        }
        card.pathwayIDs = unique(card.pathwayIDs.filter(selectedPathwayIDs.contains))
        card.updatedAt = Date()
    }

    func updateKnowledgeNodes(
        for pathway: KnowledgePathway,
        selectedCardIDs: Set<UUID>,
        cards: [KnowledgeCard]
    ) {
        for card in cards {
            if selectedCardIDs.contains(card.id) {
                add(card, to: pathway)
            } else {
                remove(card, from: pathway)
            }
        }
        pathway.knowledgeCardIDs = unique(pathway.knowledgeCardIDs.filter(selectedCardIDs.contains))
        pathway.updatedAt = Date()
    }

    func detach(
        _ pathway: KnowledgePathway,
        from documents: [DocumentItem],
        cards: [KnowledgeCard] = []
    ) {
        for document in documents where document.pathwayIDs.contains(pathway.id) {
            document.pathwayIDs.removeAll { $0 == pathway.id }
            document.updatedAt = Date()
        }
        pathway.sourceDocumentIDs = []
        pathway.candidateDocumentIDs = []
        for card in cards where card.pathwayIDs.contains(pathway.id) {
            card.pathwayIDs.removeAll { $0 == pathway.id }
            card.updatedAt = Date()
        }
        pathway.knowledgeCardIDs = []
        pathway.updatedAt = Date()
    }

    func detach(
        _ card: KnowledgeCard,
        from pathways: [KnowledgePathway]
    ) {
        for pathway in pathways where pathway.knowledgeCardIDs.contains(card.id) {
            pathway.knowledgeCardIDs.removeAll { $0 == card.id }
            pathway.updatedAt = Date()
        }
        card.pathwayIDs = []
        card.updatedAt = Date()
    }

    private func add(_ document: DocumentItem, to pathway: KnowledgePathway) {
        if !document.pathwayIDs.contains(pathway.id) {
            document.pathwayIDs.append(pathway.id)
            document.updatedAt = Date()
        }
        if !pathway.sourceDocumentIDs.contains(document.id) {
            pathway.sourceDocumentIDs.append(document.id)
            pathway.updatedAt = Date()
        }
    }

    private func remove(_ document: DocumentItem, from pathway: KnowledgePathway) {
        if document.pathwayIDs.contains(pathway.id) {
            document.pathwayIDs.removeAll { $0 == pathway.id }
            document.updatedAt = Date()
        }
        if pathway.sourceDocumentIDs.contains(document.id) {
            pathway.sourceDocumentIDs.removeAll { $0 == document.id }
            pathway.updatedAt = Date()
        }
    }

    private func add(_ card: KnowledgeCard, to pathway: KnowledgePathway) {
        if !card.pathwayIDs.contains(pathway.id) {
            card.pathwayIDs.append(pathway.id)
            card.updatedAt = Date()
        }
        if !pathway.knowledgeCardIDs.contains(card.id) {
            pathway.knowledgeCardIDs.append(card.id)
            pathway.updatedAt = Date()
        }
    }

    private func remove(_ card: KnowledgeCard, from pathway: KnowledgePathway) {
        if card.pathwayIDs.contains(pathway.id) {
            card.pathwayIDs.removeAll { $0 == pathway.id }
            card.updatedAt = Date()
        }
        if pathway.knowledgeCardIDs.contains(card.id) {
            pathway.knowledgeCardIDs.removeAll { $0 == card.id }
            pathway.updatedAt = Date()
        }
    }

    private func unique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
