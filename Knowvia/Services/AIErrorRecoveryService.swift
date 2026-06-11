import Foundation

enum AIWorkflowAction {
    case documentSummary
    case selectionExplanation
    case selectionCard
    case annotationCard

    var title: String {
        switch self {
        case .documentSummary: "AI 速读"
        case .selectionExplanation: "AI 解释选区"
        case .selectionCard: "AI 智能制卡"
        case .annotationCard: "AI 批注制卡"
        }
    }
}

struct AIErrorRecoveryService {
    func message(for error: Error, action: AIWorkflowAction) -> String {
        let baseMessage = error.localizedDescription
        let suggestion: String

        switch error {
        case AIServiceError.missingAPIKey:
            suggestion = "请到设置中使用 DeepSeek 预设，填入 API Key 后保存并测试连接。"
        case AIServiceError.missingEndpoint, AIServiceError.invalidEndpoint:
            suggestion = "请检查设置里的 API Endpoint；DeepSeek 可使用 https://api.deepseek.com/chat/completions。"
        case AIServiceError.missingModel:
            suggestion = "请检查 Model Name；DeepSeek 当前可先使用 deepseek-v4-flash。"
        case AIServiceError.authenticationFailed:
            suggestion = "请确认 API Key 未填错、账户可用，并且 Endpoint 与模型名称属于同一服务商。"
        case AIServiceError.rateLimited:
            suggestion = "可能是额度、限流或并发限制；稍后重试，或在服务商控制台检查余额和配额。"
        case AIServiceError.serverError:
            suggestion = "模型服务临时不可用；稍后重试，本地资料和已生成内容不会丢失。"
        case AIServiceError.invalidResponse, AIServiceError.emptyResponse:
            suggestion = "模型返回格式不符合预期；可以重试，或缩短材料后再次生成。"
        default:
            suggestion = "请检查网络连接与模型服务配置；你仍可先使用本地兜底草稿继续整理。"
        }

        return "\(action.title)未完成：\(baseMessage)\n\(suggestion)"
    }
}
