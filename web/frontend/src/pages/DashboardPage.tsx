import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";
import { useAuthStore } from "../stores/authStore";
import { OnboardingWizard } from "../components/common/OnboardingWizard";

export function DashboardPage() {
  const navigate = useNavigate();
  const { user } = useAuthStore();
  const [stats, setStats] = useState({ pathways: 0, documents: 0, cards: 0 });
  const [recentPathways, setRecentPathways] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      api.pathways.list(),
      api.documents.list(),
      api.cards.list(),
    ]).then(([pw, docs, cards]) => {
      setStats({
        pathways: pw.pagination?.total || pw.pathways?.length || 0,
        documents: docs.pagination?.total || docs.documents?.length || 0,
        cards: cards.cards?.length || 0,
      });
      setRecentPathways((pw.pathways || []).slice(0, 4));
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const statCards = [
    { label: "知识路径", value: stats.pathways, icon: "🔗", color: "from-[var(--deep-indigo)] to-[var(--slate-blue)]", bg: "bg-[var(--pale-lavender)]", path: "/pathways" },
    { label: "学习资料", value: stats.documents, icon: "📚", color: "from-[var(--path-teal)] to-[#5DB8A8]", bg: "bg-[var(--pale-mint)]", path: "/library" },
    { label: "知识卡片", value: stats.cards, icon: "◈", color: "from-[var(--soft-violet)] to-[var(--soft-violet-light)]", bg: "bg-[var(--pale-lavender)]", path: "/cards" },
  ];

  return (
    <div className="p-6 md:p-10 max-w-5xl mx-auto">
      {/* Header */}
      <div className="mb-10">
        <h2 className="text-2xl font-bold text-[var(--primary-text)] tracking-tight">
          {user?.username ? `你好，${user.username}` : "欢迎使用知径"}
        </h2>
        <p className="text-sm text-[var(--tertiary-text)] mt-1.5">
          把资料变成可理解、可追溯、可复习、可输出的知识路径
        </p>
      </div>

      {/* Onboarding for new users */}
      <OnboardingWizard />

      {/* Stats */}
      {!loading && (
        <div className="grid grid-cols-3 gap-4 mb-10">
          {statCards.map((s) => (
            <button
              key={s.label}
              onClick={() => navigate(s.path)}
              className="group bg-white rounded-2xl p-5 border border-[var(--border-subtle)] shadow-[var(--shadow-xs)] hover:shadow-[var(--shadow-md)] hover:border-[var(--cool-gray)] transition-all duration-200 text-left"
            >
              <div className="flex items-start justify-between mb-3">
                <span className="text-2xl">{s.icon}</span>
                <span className="text-3xl font-bold text-[var(--primary-text)] tabular-nums">
                  {s.value}
                </span>
              </div>
              <p className="text-sm font-medium text-[var(--secondary-text)] group-hover:text-[var(--primary-text)] transition-colors">
                {s.label}
              </p>
            </button>
          ))}
        </div>
      )}

      {/* Quick Actions */}
      <div className="mb-10">
        <h3 className="text-sm font-semibold text-[var(--secondary-text)] uppercase tracking-wider mb-4">
          快速开始
        </h3>
        <div className="grid grid-cols-2 gap-3">
          <button
            onClick={() => navigate("/init")}
            className="flex items-center gap-4 bg-white rounded-2xl p-5 border border-[var(--border-subtle)] shadow-[var(--shadow-xs)] hover:shadow-[var(--shadow-md)] hover:border-[var(--soft-violet)]/30 transition-all duration-200 group"
          >
            <div className="w-10 h-10 rounded-xl bg-[var(--pale-lavender)] flex items-center justify-center text-lg group-hover:scale-110 transition-transform">
              🎯
            </div>
            <div className="text-left">
              <p className="text-sm font-semibold text-[var(--primary-text)]">新建知识路径</p>
              <p className="text-xs text-[var(--tertiary-text)] mt-0.5">设定目标，让 AI 帮你提取和组织知识</p>
            </div>
          </button>

          <button
            onClick={() => navigate("/library")}
            className="flex items-center gap-4 bg-white rounded-2xl p-5 border border-[var(--border-subtle)] shadow-[var(--shadow-xs)] hover:shadow-[var(--shadow-md)] hover:border-[var(--path-teal)]/30 transition-all duration-200 group"
          >
            <div className="w-10 h-10 rounded-xl bg-[var(--pale-mint)] flex items-center justify-center text-lg group-hover:scale-110 transition-transform">
              📚
            </div>
            <div className="text-left">
              <p className="text-sm font-semibold text-[var(--primary-text)]">管理资料库</p>
              <p className="text-xs text-[var(--tertiary-text)] mt-0.5">上传 PDF、Word、网页，自动转换为结构化内容</p>
            </div>
          </button>

          <button
            onClick={() => navigate("/recall")}
            className="flex items-center gap-4 bg-white rounded-2xl p-5 border border-[var(--border-subtle)] shadow-[var(--shadow-xs)] hover:shadow-[var(--shadow-md)] hover:border-[var(--soft-violet)]/30 transition-all duration-200 group"
          >
            <div className="w-10 h-10 rounded-xl bg-[var(--pale-amber)] flex items-center justify-center text-lg group-hover:scale-110 transition-transform">
              🧠
            </div>
            <div className="text-left">
              <p className="text-sm font-semibold text-[var(--primary-text)]">主动回忆练习</p>
              <p className="text-xs text-[var(--tertiary-text)] mt-0.5">用科学方法检验你的学习效果</p>
            </div>
          </button>

          <button
            onClick={() => navigate("/settings")}
            className="flex items-center gap-4 bg-white rounded-2xl p-5 border border-[var(--border-subtle)] shadow-[var(--shadow-xs)] hover:shadow-[var(--shadow-md)] hover:border-[var(--slate-blue)]/30 transition-all duration-200 group"
          >
            <div className="w-10 h-10 rounded-xl bg-[var(--cool-gray-light)] flex items-center justify-center text-lg group-hover:scale-110 transition-transform">
              ⚡
            </div>
            <div className="text-left">
              <p className="text-sm font-semibold text-[var(--primary-text)]">配置 AI 服务</p>
              <p className="text-xs text-[var(--tertiary-text)] mt-0.5">设置 API Key，启用真实 AI 分析能力</p>
            </div>
          </button>
        </div>
      </div>

      {/* Recent Pathways */}
      {recentPathways.length > 0 && (
        <div>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-[var(--secondary-text)] uppercase tracking-wider">
              最近的路径
            </h3>
            <button
              onClick={() => navigate("/pathways")}
              className="text-xs text-[var(--soft-violet)] hover:text-[var(--deep-indigo)] font-medium transition-colors"
            >
              查看全部 →
            </button>
          </div>
          <div className="grid grid-cols-2 gap-3">
            {recentPathways.map((p: any) => (
              <button
                key={p.id}
                onClick={() => navigate(`/pathway/${p.id}`)}
                className="flex items-center gap-4 bg-white rounded-2xl p-4 border border-[var(--border-subtle)] shadow-[var(--shadow-xs)] hover:shadow-[var(--shadow-md)] transition-all duration-200 text-left group"
              >
                <div className="w-9 h-9 rounded-xl bg-[var(--pale-lavender)] flex items-center justify-center text-sm flex-shrink-0">
                  🔗
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-[var(--primary-text)] truncate group-hover:text-[var(--deep-indigo)] transition-colors">
                    {p.title}
                  </p>
                  <p className="text-xs text-[var(--tertiary-text)] mt-0.5 truncate">
                    {p.goal?.slice(0, 40) || "未设定目标"}
                  </p>
                </div>
                <span className="text-[var(--tertiary-text)] text-xs opacity-0 group-hover:opacity-100 transition-opacity">
                  →
                </span>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Empty State */}
      {!loading && stats.pathways === 0 && stats.documents === 0 && (
        <div className="text-center py-16">
          <div className="text-5xl mb-5">📚</div>
          <h3 className="text-lg font-semibold text-[var(--primary-text)] mb-2">开始你的知识之旅</h3>
          <p className="text-sm text-[var(--tertiary-text)] max-w-md mx-auto leading-relaxed">
            创建你的第一个知识路径，上传学习资料，让 AI 帮你提取和组织关键概念。
          </p>
          <button
            onClick={() => navigate("/init")}
            className="mt-6 inline-flex items-center gap-2 px-6 py-3 bg-[var(--deep-indigo)] text-white rounded-xl text-sm font-semibold hover:bg-[var(--deep-indigo-hover)] shadow-[var(--shadow-sm)] hover:shadow-[var(--shadow-md)] transition-all duration-200"
          >
            🎯 创建第一条路径
          </button>
        </div>
      )}

      {/* Footer */}
      <div className="mt-16 pt-8 border-t border-[var(--border-subtle)] text-center">
        <p className="text-[11px] text-[var(--tertiary-text)]">
          知径 Knowvia · 让知识成为路径 · 研究原型
        </p>
      </div>
    </div>
  );
}
