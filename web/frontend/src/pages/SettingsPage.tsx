import { useState, useEffect } from "react";

interface AISettings {
  providerName: string;
  apiEndpoint: string;
  modelName: string;
  apiKey: string;
}

const PRESETS: { name: string; settings: Omit<AISettings, "apiKey"> }[] = [
  { name: "OpenAI", settings: { providerName: "OpenAI", apiEndpoint: "https://api.openai.com/v1/chat/completions", modelName: "gpt-4o-mini" } },
  { name: "DeepSeek", settings: { providerName: "DeepSeek", apiEndpoint: "https://api.deepseek.com/chat/completions", modelName: "deepseek-chat" } },
  { name: "Claude", settings: { providerName: "Anthropic", apiEndpoint: "https://api.anthropic.com/v1/messages", modelName: "claude-sonnet-4-20250514" } },
  { name: "Gemini", settings: { providerName: "Google", apiEndpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", modelName: "gemini-2.5-flash" } },
  { name: "Ollama", settings: { providerName: "Ollama", apiEndpoint: "http://localhost:11434/v1/chat/completions", modelName: "llama3" } },
];

export function SettingsPage() {
  const [settings, setSettings] = useState<AISettings>(() => {
    const saved = localStorage.getItem("ai_settings");
    return saved ? JSON.parse(saved) : { providerName: "OpenAI", apiEndpoint: "https://api.openai.com/v1/chat/completions", modelName: "gpt-4o-mini", apiKey: "" };
  });
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    localStorage.setItem("ai_settings", JSON.stringify(settings));
    setSaved(true);
    const t = setTimeout(() => setSaved(false), 2000);
    return () => clearTimeout(t);
  }, [settings]);

  const applyPreset = (preset: (typeof PRESETS)[0]) => {
    setSettings((s) => ({ ...s, ...preset.settings }));
  };

  return (
    <div className="p-8 max-w-3xl">
      <h2 className="text-2xl font-semibold text-[var(--deep-indigo)] mb-1">设置</h2>
      <p className="text-xs text-[var(--tertiary-text)] mb-8">配置 AI 服务和账户信息</p>

      {/* AI Configuration */}
      <div className="bg-white p-6 rounded-xl border border-[var(--cool-gray)] mb-6">
        <h3 className="font-semibold text-sm text-[var(--deep-indigo)] mb-4">AI 服务配置</h3>

        {/* Presets */}
        <div className="flex flex-wrap gap-2 mb-4">
          {PRESETS.map((p) => (
            <button
              key={p.name}
              onClick={() => applyPreset(p)}
              className="px-3 py-1.5 bg-[var(--pale-mint)] text-[var(--deep-indigo)] rounded-md text-xs font-semibold hover:bg-[var(--path-teal)] hover:text-white transition-colors"
            >
              {p.name}
            </button>
          ))}
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-[11px] font-semibold text-[var(--slate-blue)] mb-1">Provider Name</label>
            <input type="text" value={settings.providerName} onChange={(e) => setSettings((s) => ({ ...s, providerName: e.target.value }))}
              className="w-full px-3 py-2 border border-[var(--cool-gray)] rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]" />
          </div>
          <div>
            <label className="block text-[11px] font-semibold text-[var(--slate-blue)] mb-1">Model Name</label>
            <input type="text" value={settings.modelName} onChange={(e) => setSettings((s) => ({ ...s, modelName: e.target.value }))}
              className="w-full px-3 py-2 border border-[var(--cool-gray)] rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]" />
          </div>
          <div>
            <label className="block text-[11px] font-semibold text-[var(--slate-blue)] mb-1">API Endpoint</label>
            <input type="text" value={settings.apiEndpoint} onChange={(e) => setSettings((s) => ({ ...s, apiEndpoint: e.target.value }))}
              className="w-full px-3 py-2 border border-[var(--cool-gray)] rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]" />
          </div>
          <div>
            <label className="block text-[11px] font-semibold text-[var(--slate-blue)] mb-1">API Key</label>
            <input type="password" value={settings.apiKey} onChange={(e) => setSettings((s) => ({ ...s, apiKey: e.target.value }))}
              className="w-full px-3 py-2 border border-[var(--cool-gray)] rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]" placeholder="sk-... 或留空使用内置 Demo" />
          </div>
          {saved && <p className="text-xs text-[var(--path-teal)]">✓ 已保存</p>}
        </div>
      </div>

      {/* Research Note */}
      <div className="bg-[var(--pale-lavender)] p-4 rounded-lg">
        <p className="text-[11px] text-[var(--secondary-text)]">
          知径 Knowvia 研究原型 v0.1。所有数据存储于本地服务器。AI 调用通过你配置的 API Key 完成，系统不会记录 API Key。
        </p>
      </div>
    </div>
  );
}
