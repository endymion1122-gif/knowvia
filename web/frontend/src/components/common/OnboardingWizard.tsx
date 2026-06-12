import { useState } from "react";
import { useNavigate } from "react-router-dom";

interface Step {
  title: string;
  desc: string;
  icon: string;
  action?: { label: string; path: string };
}

const STEPS: Step[] = [
  {
    title: "创建知识路径",
    desc: "设定学习目标，告诉 AI 你想学什么、已经知道什么、想输出什么。这是有效学习的第一步。",
    icon: "🎯",
    action: { label: "开始创建", path: "/init" },
  },
  {
    title: "上传学习资料",
    desc: "支持 PDF、Word、PPT、Markdown 和网页链接。AI 会自动将文档转换为结构化内容。",
    icon: "📚",
    action: { label: "上传资料", path: "/library" },
  },
  {
    title: "AI 提取 + 你校准",
    desc: "AI 从资料中提取概念、观点和证据。你用自己的话转述、确认、建立关系。知识才能真正内化。",
    icon: "🤖",
    action: { label: "查看路径", path: "/pathways" },
  },
];

export function OnboardingWizard() {
  const [current, setCurrent] = useState(0);
  const [dismissed, setDismissed] = useState(() => localStorage.getItem("onboarding_done") === "true");
  const navigate = useNavigate();

  const finish = () => {
    localStorage.setItem("onboarding_done", "true");
    setDismissed(true);
  };

  if (dismissed) return null;

  return (
    <div className="bg-white p-6 rounded-xl border-2 border-[var(--soft-violet)] shadow-lg mb-8">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-[var(--deep-indigo)]">
          👋 欢迎使用知径 Knowvia — 3 步上手
        </h3>
        <button onClick={finish} className="text-xs text-[var(--tertiary-text)] hover:text-red-500">跳过</button>
      </div>

      {/* Step indicators */}
      <div className="flex gap-2 mb-5">
        {STEPS.map((_, i) => (
          <div
            key={i}
            className={`flex-1 h-1 rounded-full transition-colors ${i <= current ? "bg-[var(--soft-violet)]" : "bg-gray-200"}`}
          />
        ))}
      </div>

      {/* Current step */}
      <div className="text-center py-4">
        <div className="text-4xl mb-3">{STEPS[current].icon}</div>
        <h4 className="text-lg font-semibold text-[var(--primary-text)] mb-2">{STEPS[current].title}</h4>
        <p className="text-sm text-[var(--secondary-text)] max-w-md mx-auto leading-relaxed">{STEPS[current].desc}</p>
      </div>

      {/* Actions */}
      <div className="flex items-center justify-between mt-4">
        <button
          onClick={() => setCurrent((c) => Math.max(0, c - 1))}
          disabled={current === 0}
          className="text-xs text-[var(--tertiary-text)] hover:text-[var(--primary-text)] disabled:opacity-30"
        >
          ← 上一步
        </button>
        <div className="flex gap-2">
          {current < STEPS.length - 1 ? (
            <button
              onClick={() => setCurrent((c) => c + 1)}
              className="px-4 py-1.5 bg-[var(--soft-violet)] text-white text-xs font-semibold rounded hover:opacity-90"
            >
              下一步
            </button>
          ) : (
            <button
              onClick={() => {
                finish();
                if (STEPS[current].action) navigate(STEPS[current].action!.path);
              }}
              className="px-4 py-1.5 bg-[var(--deep-indigo)] text-white text-xs font-semibold rounded hover:opacity-90"
            >
              开始使用
            </button>
          )}
          {STEPS[current].action && (
            <button
              onClick={() => { finish(); navigate(STEPS[current].action!.path); }}
              className="text-xs text-[var(--soft-violet)] hover:underline"
            >
              直接前往 →
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
