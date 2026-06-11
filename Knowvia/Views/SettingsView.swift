import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(ResearchParticipationPreferences.statusKey)
    private var participationStatusRaw = ResearchParticipationStatus.undecided.rawValue
    @AppStorage(AppSettingsStore.demoModeEnabledKey)
    private var demoModeEnabled = true

    @State private var showsResearchConsent = false
    @State private var showsExitConfirmation = false
    @State private var showsClearAPIKeyConfirmation = false
    @State private var providerName = AppSettings.defaultProviderName
    @State private var apiEndpoint = AppSettings.defaultAPIEndpoint
    @State private var modelName = AppSettings.defaultModelName
    @State private var apiKey = ""
    @State private var hasStoredAPIKey = false
    @State private var isTestingConnection = false
    @State private var aiConfigurationMessage: String?
    @State private var errorMessage: String?
    @State private var libraryPath = ""
    @State private var demoExperienceMessage: String?

    private let settingsPreferences = AppSettingsPreferences()
    private let keychainService = KeychainService.shared
    private let demoExperienceService = DemoExperienceService()

    private var status: ResearchParticipationStatus {
        ResearchParticipationStatus(rawValue: participationStatusRaw) ?? .undecided
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("设置")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("管理 AI 服务、本地数据原则与研究参与选择。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                aiConfigurationCard
                demoExperienceCard
                researchParticipationCard
                privacyPrinciplesCard
                demoBoundaryCard
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.pageBackground)
        .onAppear {
            loadSettings()
        }
        .sheet(isPresented: $showsResearchConsent) {
            ResearchConsentView(
                participationStatusRaw: $participationStatusRaw,
                requiresDecision: false
            )
        }
        .alert("退出学习研究计划？", isPresented: $showsExitConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认退出", role: .destructive) {
                participationStatusRaw = ResearchParticipationStatus.declined.rawValue
            }
        } message: {
            Text("退出不会影响你继续使用知径 Knowvia 的基本功能。")
        }
        .alert("删除 API Key？", isPresented: $showsClearAPIKeyConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                deleteAPIKey()
            }
        } message: {
            Text("删除后，本地 Demo AI 仍可使用。切换到真实 API 模式时，需要再次保存 API Key。")
        }
        .alert("无法保存设置", isPresented: errorBinding) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var demoExperienceCard: some View {
        settingsCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.pathTeal)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    Text("示例体验")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("在本机恢复一份示例阅读材料和三张引导卡片，用来体验阅读、Demo AI、知识卡片与学习路径。重复载入不会创建副本。")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(3)
                    Button("恢复示例体验") {
                        installDemoExperience()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)

                    if let demoExperienceMessage {
                        Text(demoExperienceMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.pathTeal)
                    }
                }
            }
        }
    }

    private var aiConfigurationCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.softViolet)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("AI 模式")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.deepIndigo)
                            Spacer()
                            apiKeyStatusPill
                        }

                        Text("测试版默认使用本地 Demo AI，不需要 API Key，也不会发送文本。需要联调时，可切换到真实 OpenAI-compatible API；DeepSeek 可直接使用预设。")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineSpacing(3)
                    }
                }

                Toggle(isOn: $demoModeEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("使用本地 Demo AI")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                        Text("直接体验摘要、选区解释和知识卡片流程。结果为本机生成的结构化示例，不代表真实模型分析。")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineSpacing(3)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Text("真实 API 联调（可选）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.slateBlue)

                Button {
                    applyDeepSeekPreset()
                } label: {
                    Label("使用 DeepSeek 预设", systemImage: "wand.and.stars")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.deepIndigo)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.paleMint, in: RoundedRectangle(cornerRadius: 7))

                HStack(alignment: .top, spacing: 12) {
                    settingsField("Provider Name") {
                        TextField("例如：DeepSeek", text: $providerName)
                            .textFieldStyle(.roundedBorder)
                    }

                    settingsField("Model Name") {
                        TextField("例如：deepseek-v4-flash", text: $modelName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                settingsField("API Endpoint") {
                    TextField(AppSettings.deepSeekAPIEndpoint, text: $apiEndpoint)
                        .textFieldStyle(.roundedBorder)
                }

                settingsField("API Key") {
                    SecureField(
                        hasStoredAPIKey ? "已保存。输入新 Key 可覆盖原值" : "输入 DeepSeek 或 OpenAI-compatible API Key",
                        text: $apiKey
                    )
                    .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    Button("保存 AI 配置") {
                        saveAIConfiguration()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.deepIndigo, in: RoundedRectangle(cornerRadius: 7))
                    .disabled(demoModeEnabled)
                    .opacity(demoModeEnabled ? 0.45 : 1)

                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        if isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("测试连接")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.softViolet)
                    .disabled(isTestingConnection || demoModeEnabled)
                    .opacity(demoModeEnabled ? 0.45 : 1)

                    if hasStoredAPIKey {
                        Button("删除 API Key") {
                            showsClearAPIKeyConfirmation = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .disabled(demoModeEnabled)
                        .opacity(demoModeEnabled ? 0.45 : 1)
                    }
                }

                if let aiConfigurationMessage {
                    Text(aiConfigurationMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.pathTeal)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("本地资料路径")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.slateBlue)
                    Text(libraryPath)
                        .font(.system(size: 11).monospaced())
                        .foregroundStyle(AppTheme.secondaryText)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var researchParticipationCard: some View {
        settingsCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.softViolet)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.paleLavender, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("参与知径 Knowvia 学习研究计划")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.deepIndigo)
                        Spacer()
                        statusPill
                    }

                    Text(ResearchParticipationCopy.intro)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(3)

                    Text(ResearchParticipationCopy.demoNotice)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.pathTeal)
                        .lineSpacing(3)

                    HStack(spacing: 12) {
                        Button("查看研究说明") {
                            showsResearchConsent = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.deepIndigo)

                        if status == .participating {
                            Button("退出研究计划") {
                                showsExitConfirmation = true
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                        } else {
                            Button("我同意参与") {
                                showsResearchConsent = true
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.softViolet)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var privacyPrinciplesCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 13) {
                Label("数据使用原则", systemImage: "lock.shield")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)

                principle(
                    "本地优先",
                    text: "你导入的 PDF、课程资料、笔记、知识卡片和写作草稿默认保存在本机设备中。"
                )
                principle(
                    "明确授权",
                    text: "研究数据不会默认收集。只有你主动同意后，脱敏后的学习行为数据才可用于教育技术研究。"
                )
                principle(
                    "最小必要",
                    text: "本地 Demo AI 不会发送文本。切换到真实 API 模式后，只有你主动触发 AI 功能时，选中文本或当前文档提取文本才会发送给你配置的模型服务商。API Key 仅保存在 macOS Keychain 中。"
                )
                principle(
                    "可以撤回",
                    text: "你可以随时在这里退出学习研究计划，退出不会影响知径 Knowvia 的基本功能。"
                )
            }
        }
    }

    private var demoBoundaryCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("当前 Demo 边界", systemImage: "checkmark.shield")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.deepIndigo)
                Text("当前版本不包含账号、云同步、数据分析后端或遥测 SDK，也不会向知径 Knowvia 服务器上传学习行为数据。产品当前以轻量维护为主，暂不扩展重型知识平台能力。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
            }
        }
    }

    private var statusPill: some View {
        Text(status.title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(status == .participating ? AppTheme.pathTeal : AppTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                status == .participating ? AppTheme.paleMint : AppTheme.coolGray.opacity(0.72),
                in: Capsule()
            )
    }

    private var apiKeyStatusPill: some View {
        Text(demoModeEnabled ? "本地 Demo 已开启" : hasStoredAPIKey ? "Key 已保存" : "Key 未配置")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(demoModeEnabled || hasStoredAPIKey ? AppTheme.pathTeal : AppTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                demoModeEnabled || hasStoredAPIKey ? AppTheme.paleMint : AppTheme.coolGray.opacity(0.72),
                in: Capsule()
            )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func principle(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.slateBlue)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
        }
    }

    private func settingsField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.slateBlue)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.coolGray, lineWidth: 1)
            }
    }

    private func loadSettings() {
        let settings = settingsPreferences.settings
        providerName = settings.providerName
        apiEndpoint = settings.apiEndpoint
        modelName = settings.modelName

        do {
            hasStoredAPIKey = try keychainService.loadAPIKey() != nil
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            libraryPath = try FileImportService.shared.libraryDirectory().path
        } catch {
            libraryPath = "暂时无法读取本地资料路径。"
        }
    }

    private func applyDeepSeekPreset() {
        let preset = AppSettings.deepSeekPreset
        providerName = preset.providerName
        apiEndpoint = preset.apiEndpoint
        modelName = preset.modelName
        demoModeEnabled = preset.demoModeEnabled
        aiConfigurationMessage = "已填入 DeepSeek 预设。请输入你的 API Key 后保存并测试连接。"
    }

    private func saveAIConfiguration() {
        let trimmedProviderName = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndpoint = apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedProviderName.isEmpty else {
            errorMessage = "请填写 API Provider Name。"
            return
        }
        guard
            let endpointURL = URL(string: trimmedEndpoint),
            ["http", "https"].contains(endpointURL.scheme?.lowercased() ?? ""),
            endpointURL.host != nil
        else {
            errorMessage = "请填写有效的 HTTP 或 HTTPS API Endpoint。"
            return
        }
        guard !trimmedModelName.isEmpty else {
            errorMessage = "请填写 Model Name。"
            return
        }

        settingsPreferences.settings = AppSettings(
            providerName: trimmedProviderName,
            apiEndpoint: trimmedEndpoint,
            modelName: trimmedModelName,
            demoModeEnabled: demoModeEnabled
        )

        do {
            if !trimmedAPIKey.isEmpty {
                try keychainService.saveAPIKey(trimmedAPIKey)
                apiKey = ""
                hasStoredAPIKey = true
            }
            aiConfigurationMessage = "AI 配置已保存在本机。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func installDemoExperience() {
        do {
            let result = try demoExperienceService.installOrRestore(into: modelContext)
            demoExperienceMessage = result.addedCardCount == 0
                ? "示例体验已存在，可以从首页或资料库继续阅读。"
                : "示例体验已恢复：新增 \(result.addedCardCount) 张引导卡片。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAPIKey() {
        do {
            try keychainService.deleteAPIKey()
            apiKey = ""
            hasStoredAPIKey = false
            aiConfigurationMessage = "API Key 已从本机 Keychain 删除。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func testConnection() async {
        isTestingConnection = true
        aiConfigurationMessage = nil
        defer { isTestingConnection = false }

        if demoModeEnabled {
            aiConfigurationMessage = "本地 Demo AI 已开启，无需测试网络连接。"
            return
        }

        saveAIConfiguration()
        guard errorMessage == nil else {
            return
        }

        do {
            guard let savedAPIKey = try keychainService.loadAPIKey(), !savedAPIKey.isEmpty else {
                throw AIServiceError.missingAPIKey
            }

            _ = try await AIService().sendChatCompletion(
                endpoint: apiEndpoint,
                apiKey: savedAPIKey,
                model: modelName,
                messages: [AIMessage(role: "user", content: PromptTemplates.connectionTest())]
            )
            aiConfigurationMessage = "连接成功。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
