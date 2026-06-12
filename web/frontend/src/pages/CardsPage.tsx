import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";
import type { KnowledgeCard, CardKind } from "../types";

const TYPE_LABELS: Record<string, string> = {
  concept: "概念", claim: "观点", argument: "观点", evidence: "证据",
  question: "问题", summary: "摘要", method: "方法", quote: "摘录",
  reflection: "反思", note: "笔记",
};

const TYPE_COLORS: Record<string, string> = {
  concept: "bg-blue-50 text-blue-700", claim: "bg-amber-50 text-amber-700",
  evidence: "bg-green-50 text-green-700", question: "bg-red-50 text-red-700",
  summary: "bg-purple-50 text-purple-700", reflection: "bg-pink-50 text-pink-700",
  note: "bg-gray-100 text-gray-600",
};

const STATUS_LABELS: Record<string, string> = {
  pendingReview: "待核验", confirmed: "已确认", needsFollowUp: "需跟进",
};

export function CardsPage() {
  const navigate = useNavigate();
  const [cards, setCards] = useState<KnowledgeCard[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState<string>("");

  const loadCards = useCallback(async () => {
    try {
      const { cards } = await api.cards.list(filter ? { card_type: filter } : undefined);
      setCards(cards);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => { loadCards(); }, [loadCards]);

  const handleDelete = async (id: string) => {
    if (!confirm("确定删除这张卡片？")) return;
    try { await api.cards.delete(id); await loadCards(); }
    catch (err: any) { setError(err.message); }
  };

  const handleStatus = async (card: KnowledgeCard, status: string) => {
    try { await api.cards.update(card.id, { calibration_status: status }); await loadCards(); }
    catch (err: any) { setError(err.message); }
  };

  const cardTypes: CardKind[] = ["concept", "claim", "evidence", "question", "summary", "reflection", "note"];

  return (
    <div className="p-8 max-w-5xl">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-semibold text-[var(--deep-indigo)]">知识节点</h2>
          <p className="text-xs text-[var(--tertiary-text)] mt-1">
            概念 · 观点 · 证据 · 反思 — 知识路径的基本构成单元
          </p>
        </div>
      </div>

      {/* Type filter */}
      <div className="flex gap-1.5 mb-4 flex-wrap">
        <button
          onClick={() => setFilter("")}
          className={`px-3 py-1 rounded-md text-xs font-semibold transition-colors ${!filter ? "bg-[var(--deep-indigo)] text-white" : "bg-white text-[var(--secondary-text)] border"}`}
        >
          全部
        </button>
        {cardTypes.map((t) => (
          <button
            key={t}
            onClick={() => setFilter(t === filter ? "" : t)}
            className={`px-3 py-1 rounded-md text-xs font-semibold transition-colors ${filter === t ? "bg-[var(--deep-indigo)] text-white" : "bg-white text-[var(--secondary-text)] border"}`}
          >
            {TYPE_LABELS[t] || t}
          </button>
        ))}
      </div>

      {error && <p className="text-sm text-red-500 mb-4">{error}</p>}

      {loading ? (
        <p className="text-sm text-[var(--tertiary-text)]">加载中...</p>
      ) : cards.length === 0 ? (
        <div className="bg-white p-10 rounded-xl border border-dashed border-[var(--cool-gray)] text-center">
          <p className="text-sm text-[var(--secondary-text)]">还没有知识卡片。</p>
          <p className="text-xs text-[var(--tertiary-text)] mt-2">
            在阅读器中选中文本 → 添加批注 → 转为知识卡片。
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {cards.map((card) => (
            <div key={card.id} className="bg-white p-4 rounded-lg border border-[var(--cool-gray)]">
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={`text-[10px] px-1.5 py-0.5 rounded font-semibold ${TYPE_COLORS[card.card_type] || "bg-gray-100"}`}>
                      {TYPE_LABELS[card.card_type] || card.card_type}
                    </span>
                    <span className={`text-[10px] px-1.5 py-0.5 rounded ${card.calibration_status === "confirmed" ? "bg-green-100 text-green-700" : card.calibration_status === "needsFollowUp" ? "bg-red-100 text-red-700" : "bg-amber-100 text-amber-700"}`}>
                      {STATUS_LABELS[card.calibration_status] || card.calibration_status}
                    </span>
                  </div>
                  <h4 className="text-sm font-medium text-[var(--primary-text)] truncate">{card.title}</h4>
                  <p className="text-xs text-[var(--secondary-text)] mt-1 line-clamp-2">{card.content}</p>
                  {card.calibration_note && (
                    <p className="text-xs text-[var(--soft-violet)] mt-1 italic">💬 {card.calibration_note}</p>
                  )}
                  {card.source_document_title && (
                    <button
                      onClick={() => card.source_document_id && navigate(`/reader/${card.source_document_id}`)}
                      className="text-[10px] text-[var(--path-teal)] hover:underline mt-1 block"
                    >
                      📄 {card.source_document_title} {card.page_number ? `p.${card.page_number}` : ""}
                    </button>
                  )}
                </div>
                <div className="flex items-center gap-1 flex-shrink-0">
                  {card.calibration_status === "pendingReview" && (
                    <>
                      <button
                        onClick={() => handleStatus(card, "confirmed")}
                        className="text-[10px] px-1.5 py-0.5 bg-green-100 text-green-700 rounded hover:bg-green-200"
                      >
                        确认
                      </button>
                      <button
                        onClick={() => handleStatus(card, "needsFollowUp")}
                        className="text-[10px] px-1.5 py-0.5 bg-red-100 text-red-700 rounded hover:bg-red-200"
                      >
                        需跟进
                      </button>
                    </>
                  )}
                  <button
                    onClick={() => handleDelete(card.id)}
                    className="text-[10px] text-[var(--tertiary-text)] hover:text-red-500 ml-1"
                  >
                    ✕
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
