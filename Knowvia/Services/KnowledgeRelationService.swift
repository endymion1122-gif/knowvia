import Foundation

enum KnowledgeRelationError: LocalizedError {
    case sameNode
    case duplicateRelation
    case missingNode

    var errorDescription: String? {
        switch self {
        case .sameNode:
            "请选择两个不同的知识节点。"
        case .duplicateRelation:
            "这条知识关系已经存在。"
        case .missingNode:
            "关系中的知识节点已不存在，请重新选择。"
        }
    }
}

struct ResolvedKnowledgeRelation: Identifiable {
    let relation: KnowledgeRelation
    let sourceCard: KnowledgeCard
    let targetCard: KnowledgeCard

    var id: UUID { relation.id }
}

struct ClaimEvidencePair: Identifiable {
    let relation: KnowledgeRelation
    let claim: KnowledgeCard
    let evidence: KnowledgeCard

    var id: UUID { relation.id }
}

struct KnowledgeRelationService {
    func makeRelation(
        pathwayID: UUID,
        sourceCardID: UUID,
        targetCardID: UUID,
        kind: KnowledgeRelationKind,
        note: String = "",
        existingRelations: [KnowledgeRelation]
    ) throws -> KnowledgeRelation {
        guard sourceCardID != targetCardID else {
            throw KnowledgeRelationError.sameNode
        }
        guard !existingRelations.contains(where: {
            $0.pathwayID == pathwayID
                && $0.sourceCardID == sourceCardID
                && $0.targetCardID == targetCardID
                && $0.kind == kind
        }) else {
            throw KnowledgeRelationError.duplicateRelation
        }

        return KnowledgeRelation(
            pathwayID: pathwayID,
            sourceCardID: sourceCardID,
            targetCardID: targetCardID,
            relationType: kind.rawValue,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func relations(
        for pathway: KnowledgePathway,
        in relations: [KnowledgeRelation]
    ) -> [KnowledgeRelation] {
        relations
            .filter { $0.pathwayID == pathway.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func relations(
        involving card: KnowledgeCard,
        in relations: [KnowledgeRelation]
    ) -> [KnowledgeRelation] {
        relations.filter {
            $0.sourceCardID == card.id || $0.targetCardID == card.id
        }
    }

    func resolvedRelations(
        for pathway: KnowledgePathway,
        relations: [KnowledgeRelation],
        cards: [KnowledgeCard]
    ) -> [ResolvedKnowledgeRelation] {
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return self.relations(for: pathway, in: relations).compactMap { relation in
            guard
                let source = cardsByID[relation.sourceCardID],
                let target = cardsByID[relation.targetCardID]
            else {
                return nil
            }
            return ResolvedKnowledgeRelation(
                relation: relation,
                sourceCard: source,
                targetCard: target
            )
        }
    }

    func claimEvidencePairs(
        for pathway: KnowledgePathway,
        relations: [KnowledgeRelation],
        cards: [KnowledgeCard]
    ) -> [ClaimEvidencePair] {
        resolvedRelations(for: pathway, relations: relations, cards: cards)
            .filter { $0.relation.kind == .supports }
            .compactMap { resolved in
                if resolved.sourceCard.kind == .evidence, resolved.targetCard.kind == .argument {
                    return ClaimEvidencePair(
                        relation: resolved.relation,
                        claim: resolved.targetCard,
                        evidence: resolved.sourceCard
                    )
                }
                if resolved.sourceCard.kind == .argument, resolved.targetCard.kind == .evidence {
                    return ClaimEvidencePair(
                        relation: resolved.relation,
                        claim: resolved.sourceCard,
                        evidence: resolved.targetCard
                    )
                }
                return nil
            }
    }
}
