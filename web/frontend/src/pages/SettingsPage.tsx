import { useState, useEffect } from "react";
import { Card } from "../components/common/Card";

interface AISettings { providerName: string; apiEndpoint: string; modelName: string; apiKey: string }

const PRESETS: { name: string; settings: Omit<AISettings, "apiKey"> }[] = [
  { name: "OpenAI", settings: { providerName: "OpenAI", apiEndpoint: "https://api.openai.com/v1/chat/completions", modelName: "gpt-4o-mini" } },
  { name: "DeepSeek", settings: { providerName: "DeepSeek", apiEndpoint: "https://api.deepseek.com/chat/completions", modelName: "deepseek-chat" } },
  { name: "Claude Sonnet", settings: { providerName: "Anthropic", apiEndpoint: "https://api.anthropic.com/v1/messages", modelName: "claude-sonnet-4-20250514" } },
  { name: "Claude Opus", settings: { providerName: "Anthropic", apiEndpoint: "https://api.anthropic.com/v1/messages", modelName: "claude-opus-4-20250514" } },
  { name: "Claude Haiku", settings: { providerName: "Anthropic", apiEndpoint: "https://api.anthropic.com/v1/messages", modelName: "claude-haiku-4-5-20251001" } },
  { name: "Gemini", settings: { providerName: "Google", apiEndpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", modelName: "gemini-2.5-flash" } },
  { name: "Ollama", settings: { providerName: "Ollama", apiEndpoint: "http://localhost:11434/v1/chat/completions", modelName: "llama3" } },
];

const inputClass = "w-full h-9 px-3 bg-white border border-[var(--border-default)] rounded-xl text-[13px] placeholder:text-[var(--text-placeholder)] focus:outline-none focus:border-[var(--brand-violet)] focus:shadow-[var(--shadow-glow-violet)] transition-all";

export function SettingsPage() {
  const [settings, setSettings] = useState<AISettings>(() => {
    const saved = localStorage.getItem("ai_settings");
    return saved ? JSON.parse(saved) : { providerName: "OpenAI", apiEndpoint: "https://api.openai.com/v1/chat/completions", modelName: "gpt-4o-mini", apiKey: "" };
  });
  const [saved, setSaved] = useState(false);

  const update = (patch: Partial<AISettings>) => {
    setSettings(s => ({ ...s, ...patch }));
    setSaved(true);
    const t = setTimeout(() => setSaved(false), 2000);
    return () => clearTimeout(t);
  };
  useEffect(() => { localStorage.setItem("ai_settings", JSON.stringify(settings)); }, [settings]);

  return (
    <div className="p-6 md:p-10 max-w-3xl mx-auto">
      <div className="mb-8">
        <h2 className="text-[28px] font-bold text-[var(--text-primary)] tracking-tight">设置</h2>
        <p className="text-[13px] text-[var(--text-tertiary)] mt-1">配置 AI 服务和账户信息</p>
      </div>

      <Card variant="panel" padding="lg" className="mb-6">
        <h3 className="text-[16px] font-semibold text-[var(--text-primary)] mb-4">AI 模型预设</h3>
        <div className="flex flex-wrap gap-2 mb-6">
          {PRESETS.map(p => (
            <button key={p.name} onClick={() => update(p.settings)}
              className="px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors bg-[var(--primary-100)] text-[var(--primary-600)] hover:bg-[var(--primary-200)]">
              {p.name}
            </button>
          ))}
        </div>

        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-[11px] font-semibold text-[var(--text-secondary)] mb-1.5 uppercase tracking-wide">服务商</label>
              <input type="text" value={settings.providerName} onChange={e => update({ providerName: e.target.value })} className={inputClass} />
            </div>
            <div>
              <label className="block text-[11px] font-semibold text-[var(--text-secondary)] mb-1.5 uppercase tracking-wide">模型名称</label>
              <input type="text" value={settings.modelName} onChange={e => update({ modelName: e.target.value })} className={inputClass} />
            </div>
          </div>
          <div>
            <label className="block text-[11px] font-semibold text-[var(--text-secondary)] mb-1.5 uppercase tracking-wide">API Endpoint</label>
            <input type="text" value={settings.apiEndpoint} onChange={e => update({ apiEndpoint: e.target.value })} className={inputClass} />
          </div>
          <div>
            <label className="block text-[11px] font-semibold text-[var(--text-secondary)] mb-1.5 uppercase tracking-wide">API Key</label>
            <input type="password" value={settings.apiKey} onChange={e => update({ apiKey: e.target.value })} className={inputClass} placeholder="sk-... 或留空使用 Demo 模式" />
          </div>
          {saved && <p className="text-xs text-[var(--brand-teal)] font-medium">✓ 已自动保存</p>}
        </div>
      </Card>

      <Card variant="panel" padding="lg">
        <h3 className="text-[16px] font-semibold text-[var(--text-primary)] mb-2">关于</h3>
        <p className="text-[13px] text-[var(--text-secondary)] leading-relaxed">
          知径 Knowvia 研究原型 · AI 支持型有效笔记与知识路径建构系统。所有数据存储于本地服务器。AI 调用通过你配置的 API Key 完成，系统不会记录 API Key。
        </p>
      </Card>
    </div>
  );
}
