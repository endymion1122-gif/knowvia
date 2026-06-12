import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";
import { OnboardingWizard } from "../components/common/OnboardingWizard";

export function DashboardPage() {
  const navigate = useNavigate();
  const [stats, setStats] = useState({ pathways: 0, documents: 0, cards: 0, annotations: 0 });
  const [recentPathways, setRecentPathways] = useState<any[]>([]);

  useEffect(() => {
    // Load stats in parallel
    Promise.all([
      api.pathways.list(),
      api.documents.list(),
      api.cards.list(),
      fetch("/api/annotations", { headers: { Authorization: `Bearer ${localStorage.getItem("token")}` } }).then(r => r.json()),
    ]).then(([pw, docs, cards, anns]) => {
      setStats({
        pathways: pw.pathways?.length || 0,
        documents: docs.documents?.length || 0,
        cards: cards.cards?.length || 0,
        annotations: anns.annotations?.length || 0,
      });
      setRecentPathways((pw.pathways || []).slice(0, 3));
    }).catch(() => {});
  }, []);

  return (
    <div className="p-8 max-w-5xl">
      <h2 className="text-2xl font-semibold text-[var(--deep-indigo)] mb-1">欢迎使用知径 Knowvia</h2>
      <p className="text-sm text-[var(--secondary-text)] mb-6">
        把资料变成可理解、可追溯、可复习、可输出的知识路径
      </p>

      <OnboardingWizard />

      {/* Stats */}
      <div className="grid grid-cols-4 gap-3 mb-8">
        {[
          { label: "知识路径", value: stats.pathways, icon: "🔗", color: "border-[var(--deep-indigo)]" },
          { label: "学习资料", value: stats.documents, icon: "📚", color: "border-[var(--path-teal)]" },
          { label: "知识卡片", value: stats.cards, icon: "◈", color: "border-[var(--soft-violet)]" },
          { label: "阅读批注", value: stats.annotations, icon: "💬", color: "border-[var(--slate-blue)]" },
        ].map((s) => (
          <div key={s.label} className={`bg-white p-4 rounded-xl border-l-4 ${s.color} border border-[var(--cool-gray)]`}>
            <p className="text-[10px] text-[var(--tertiary-text)]">{s.label}</p>
            <p className="text-2xl font-bold text-[var(--primary-text)]">{s.value}</p>
            <span className="text-lg">{s.icon}</span>
          </div>
        ))}
      </div>

      {/* Quick Start */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        {[
          { title: "新建知识路径", desc: "设定目标 + 上传资料 + AI 提取节点", icon: "🔗", path: "/init" },
          { title: "管理资料库", desc: "上传 PDF、Word、PPT、Markdown", icon: "📚", path: "/library" },
          { title: "配置 AI 服务", desc: "设置 API Key 启用真实 AI 分析", icon: "⚡", path: "/settings" },
        ].map((card) => (
          <button
            key={card.path}
            onClick={() => navigate(card.path)}
            className="bg-white p-5 rounded-xl border border-[var(--cool-gray)] hover:border-[var(--soft-violet)] transition-colors text-left"
          >
            <div className="text-2xl mb-2">{card.icon}</div>
            <h3 className="font-semibold text-sm text-[var(--primary-text)]">{card.title}</h3>
            <p className="text-xs text-[var(--tertiary-text)] mt-1">{card.desc}</p>
          </button>
        ))}
      </div>

      {/* Recent Pathways */}
      {recentPathways.length > 0 && (
        <div className="bg-white p-5 rounded-xl border border-[var(--cool-gray)] mb-8">
          <h3 className="font-semibold text-sm text-[var(--deep-indigo)] mb-3">最近的路径</h3>
          <div className="space-y-1">
            {recentPathways.map((p: any) => (
              <div key={p.id} className="flex items-center justify-between py-2 border-b border-[var(--cool-gray)] last:border-0">
                <div>
                  <p className="text-sm font-medium text-[var(--primary-text)]">{p.title}</p>
                  <p className="text-[10px] text-[var(--tertiary-text)]">{p.goal?.slice(0, 50) || "未设定目标"}</p>
                </div>
                <button onClick={() => navigate(`/pathway/${p.id}`)} className="text-xs text-[var(--soft-violet)] hover:underline">打开</button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* About */}
      <div className="bg-[var(--pale-lavender)] p-5 rounded-xl">
        <h3 className="font-semibold text-sm text-[var(--deep-indigo)] mb-2">关于知径 Knowvia</h3>
        <div className="text-xs text-[var(--secondary-text)] space-y-1.5 leading-relaxed">
          <p><strong>AI 支持型有效笔记与知识路径建构系统。</strong>融合有效笔记策略、知识路径可视化、来源追溯与主动回忆机制。</p>
          <p>核心理念：<strong>AI 不替你学习，而是帮你完成选择、转述、连接、组织、复习与迁移。</strong></p>
          <p className="text-[10px] text-[var(--tertiary-text)] mt-2">研究原型 v0.2 · 知径 Knowvia · 让知识成为路径。</p>
        </div>
      </div>
    </div>
  );
}
