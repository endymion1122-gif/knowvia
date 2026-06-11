import Foundation

struct KnowledgeCardCalibrationService {
    func toggleHighlighted(_ card: KnowledgeCard) {
        card.isHighlighted.toggle()
        card.updatedAt = Date()
    }

    func toggleUnderstood(_ card: KnowledgeCard) {
        card.isUnderstood.toggle()
        card.updatedAt = Date()
    }

    func confirm(_ card: KnowledgeCard) {
        card.calibrationStatus = KnowledgeCardCalibrationStatus.confirmed.rawValue
        card.updatedAt = Date()
    }

    func update(
        _ card: KnowledgeCard,
        status: KnowledgeCardCalibrationStatus,
        isHighlighted: Bool,
        isUnderstood: Bool,
        note: String
    ) {
        card.calibrationStatus = status.rawValue
        card.isHighlighted = isHighlighted
        card.isUnderstood = isUnderstood
        card.calibrationNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        card.updatedAt = Date()
    }
}
