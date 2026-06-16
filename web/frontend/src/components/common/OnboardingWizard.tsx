import { useState } from "react";
import { useNavigate } from "react-router-dom";

interface Step { title: string; desc: string; icon: string; action?: { label: string; path: string } }

const STEPS: Step[] = [
  { title: "设定学习目标", desc: "告诉 AI 你想学什么、已经知道什么、想输出什么。这是有效学习的第一步。", icon: "🎯", action: { label: "开始创建", path: "/init" } },
  { title: "上传学习资料", desc: "支持 PDF、Word、PPT、Markdown 和网页链接。AI 会自动处理格式转换。", icon: "📚", action: { label: "上传资料", path: "/library" } },
  { title: "AI 提取 · 你校准", desc: "AI 提取概念、观点和证据。你用自己的话转述、确认、建立关系。知识才能真正内化。", icon: "🤖", action: { label: "查看路径", path: "/pathways" } },
];

export function OnboardingWizard() {
  const [current, setCurrent] = useState(0);
  const [dismissed, setDismissed] = useState(() => localStorage.getItem("onboarding_done") === "true");
  const navigate = useNavigate();
  if (dismissed) return null;

  const finish = () => { localStorage.setItem("onboarding_done", "true"); setDismissed(true); };

  return (
    <div className="bg-white rounded-2xl border border-[var(--border-light)] shadow-[var(--shadow-md)] p-6 mb-8 overflow-hidden relative">
      <div className="absolute top-0 left-0 right-0 h-1 bg-[var(--cool-gray-light)]">
        <div
          className="h-full bg-gradient-to-r from-[var(--brand-navy)] to-[var(--brand-violet)] transition-all duration-500 rounded-r"
          style={{ width: `${((current + 1) / STEPS.length) * 100}%` }}
        />
      </div>

      <div className="flex items-center justify-between mb-6 pt-2">
        <div className="flex items-center gap-2">
          <span className="text-lg">👋</span>
          <h3 className="text-sm font-semibold text-[var(--text-primary)]">3 步上手知径</h3>
        </div>
        <button onClick={finish} className="text-xs text-[var(--text-tertiary)] hover:text-[var(--danger-red)] transition-colors">跳过引导</button>
      </div>

      <div className="flex items-center gap-3 mb-6">
        {STEPS.map((_, i) => (
          <button key={i} onClick={() => setCurrent(i)}
            className={`flex-1 h-1.5 rounded-full transition-all duration-300 ${i <= current ? "bg-[var(--brand-violet)]" : "bg-[var(--cool-gray-light)]"}`}
          />
        ))}
      </div>

      <div className="flex items-start gap-5">
        <div className="w-14 h-14 rounded-2xl bg-[var(--surface-lavender)] flex items-center justify-center text-2xl flex-shrink-0">
          {STEPS[current].icon}
        </div>
        <div className="flex-1">
          <h4 className="text-base font-semibold text-[var(--text-primary)] mb-1">{STEPS[current].title}</h4>
          <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{STEPS[current].desc}</p>
        </div>
      </div>

      <div className="flex items-center justify-between mt-6 pt-4 border-t border-[var(--border-light)]">
        <button onClick={() => setCurrent(c => Math.max(0, c - 1))} disabled={current === 0}
          className="text-xs text-[var(--text-tertiary)] hover:text-[var(--text-primary)] disabled:opacity-30 transition-colors">
          ← 上一步
        </button>
        <div className="flex gap-2">
          {current < STEPS.length - 1 ? (
            <button onClick={() => setCurrent(c => c + 1)}
              className="px-5 py-2 bg-[var(--brand-violet)] hover:bg-[var(--brand-navy)] text-white rounded-xl text-xs font-semibold transition-all duration-200 shadow-[var(--shadow-sm)]">
              下一步
            </button>
          ) : (
            <button onClick={() => { finish(); if (STEPS[current].action) navigate(STEPS[current].action!.path); }}
              className="px-5 py-2 bg-[var(--brand-navy)] hover:bg-[var(--brand-navy-hover)] text-white rounded-xl text-xs font-semibold transition-all duration-200 shadow-[var(--shadow-sm)]">
              开始使用
            </button>
          )}
          {STEPS[current].action && (
            <button onClick={() => { finish(); navigate(STEPS[current].action!.path); }}
              className="px-4 py-2 text-xs text-[var(--brand-violet)] hover:text-[var(--brand-navy)] font-medium transition-colors">
              直接前往 →
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
