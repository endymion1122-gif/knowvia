import Foundation

enum ResearchParticipationStatus: String {
    case undecided
    case participating
    case declined

    var title: String {
        switch self {
        case .undecided:
            "尚未选择"
        case .participating:
            "已同意参与"
        case .declined:
            "暂不参与"
        }
    }
}

struct ResearchParticipationPreferences {
    static let statusKey = "privacy.researchParticipationStatus"
    static let introSeenKey = "privacy.researchParticipationIntroSeen"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var status: ResearchParticipationStatus {
        get {
            guard
                let rawValue = defaults.string(forKey: Self.statusKey),
                let status = ResearchParticipationStatus(rawValue: rawValue)
            else {
                return .undecided
            }
            return status
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.statusKey)
        }
    }

    var hasSeenIntro: Bool {
        get {
            defaults.bool(forKey: Self.introSeenKey)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.introSeenKey)
        }
    }
}

enum ResearchParticipationCopy {
    static let intro = "我们正在探索 AI 阅读与知识卡片工具如何支持学习者将阅读材料转化为结构化知识卡片和学习路径。"

    static let collectedData = "如果你选择参与，我们可能会收集并分析脱敏后的学习行为数据，例如阅读时长、AI 功能使用次数、知识卡片数量、卡片类型、学习路径完成情况，以及你自愿填写的问卷或访谈反馈。"

    static let excludedData = "我们不会默认收集你的 PDF 正文、笔记全文、知识卡片全文、API Key 或可直接识别你身份的信息。研究结果仅以统计汇总或匿名案例形式呈现。"

    static let voluntary = "参与完全自愿。你可以随时退出研究计划，退出不会影响你继续使用知径 Knowvia 的基本功能。"

    static let demoNotice = "当前 Demo 尚未启用任何研究数据上传或遥测。你的选择仅保存在本机，用于预留后续研究模块的授权状态。"
}
