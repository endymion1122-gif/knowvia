import { useNavigate } from "react-router-dom";

export function DashboardPage() {
  const navigate = useNavigate();

  return (
    <div className="p-8 max-w-5xl">
      <h2 className="text-2xl font-semibold text-[var(--deep-indigo)] mb-1">欢迎使用知径 Knowvia</h2>
      <p className="text-sm text-[var(--secondary-text)] mb-8">
        AI 增强型多源知识路径生成系统 · 研究原型
      </p>

      {/* Quick Start Cards */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        {[
          { title: "导入资料", desc: "上传 PDF、文本或 Markdown", icon: "📚", path: "/library" },
          { title: "创建专题路径", desc: "围绕主题组织多源资料", icon: "🔗", path: "/pathways" },
          { title: "配置 AI", desc: "设置 API Key 启用 AI 能力", icon: "⚡", path: "/settings" },
        ].map((card) => (
          <button
            key={card.path}
            onClick={() => navigate(card.path)}
            className="bg-white p-6 rounded-xl border border-[var(--cool-gray)] hover:border-[var(--soft-violet)] transition-colors text-left"
          >
            <div className="text-2xl mb-3">{card.icon}</div>
            <h3 className="font-semibold text-sm text-[var(--primary-text)]">{card.title}</h3>
            <p className="text-xs text-[var(--tertiary-text)] mt-1">{card.desc}</p>
          </button>
        ))}
      </div>

      {/* About this research */}
      <div className="bg-white p-6 rounded-xl border border-[var(--cool-gray)]">
        <h3 className="font-semibold text-sm text-[var(--deep-indigo)] mb-3">关于本研究</h3>
        <div className="text-xs text-[var(--secondary-text)] space-y-2 leading-relaxed">
          <p>知径 Knowvia 是一个 AI 增强型多源知识路径生成系统。它将论文、网页、课程资料、笔记和外部来源转化为可追溯、可校准、可持续生长的 Knowledge Pathway。</p>
          <p>核心设计理念：<strong>Human-in-the-learning-loop</strong> — AI 负责提取、关联和推荐，你来判断、校准、补充和输出。</p>
          <p>本版本为学术研究原型。你的使用数据将被匿名记录用于研究分析。感谢你的参与。</p>
        </div>
      </div>
    </div>
  );
}
