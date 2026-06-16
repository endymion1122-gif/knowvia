import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";
import { Card } from "../components/common/Card";
import type { KnowledgeCard, CardKind } from "../types";

const TYPE_LABELS: Record<string, string> = {
  concept: "概念", claim: "观点", argument: "观点", evidence: "证据",
  question: "问题", summary: "摘要", method: "方法", quote: "摘录",
  reflection: "反思", note: "笔记",
};

const TYPE_TAG: Record<string, string> = {
  concept: "bg-[var(--primary-100)] text-[var(--primary-600)]",
  claim: "bg-[var(--warning-bg)] text-[var(--warning)]",
  evidence: "bg-[var(--teal-100)] text-[var(--teal-600)]",
  question: "bg-[var(--error-bg)] text-[var(--error)]",
  summary: "bg-[#EDE8FF] text-[#5B3FC4]",
  reflection: "bg-[#FFE8F0] text-[#C43F6B]",
  note: "bg-[var(--border-light)] text-[var(--text-tertiary)]",
};

const STATUS_LABELS: Record<string, string> = { pendingReview: "待核验", confirmed: "已确认", needsFollowUp: "需跟进" };

export function CardsPage() {
  const navigate = useNavigate();
  const [cards, setCards] = useState<KnowledgeCard[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState<string>("");
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const loadCards = useCallback(async () => {
    try { const { cards } = await api.cards.list(filter ? { card_type: filter } : undefined); setCards(cards); }
    catch (e: any) { setError(e.message); } finally { setLoading(false); }
  }, [filter]);
  useEffect(() => { loadCards(); }, [loadCards]);

  const handleBatchDelete = async () => {
    if (selected.size === 0 || !confirm(`删除选中的 ${selected.size} 张卡片？`)) return;
    try { await api.cards.batchDelete(Array.from(selected)); setSelected(new Set()); await loadCards(); }
    catch (err: any) { setError(err.message); }
  };
  const handleBatchExport = async () => {
    if (selected.size === 0) return;
    try {
      const { markdown } = await api.cards.batchExport(Array.from(selected));
      const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([markdown], { type: "text/markdown" })); a.download = "cards-export.md"; a.click();
    } catch (err: any) { setError(err.message); }
  };
  const toggleSelect = (id: string) => setSelected(p => { const n = new Set(p); n.has(id) ? n.delete(id) : n.add(id); return n; });
  const toggleAll = () => selected.size === cards.length ? setSelected(new Set()) : setSelected(new Set(cards.map(c => c.id)));
  const handleStatus = async (card: KnowledgeCard, s: string) => { try { await api.cards.update(card.id, { calibration_status: s }); await loadCards(); } catch {} };

  const cardTypes: CardKind[] = ["concept", "claim", "evidence", "question", "summary", "reflection", "note"];

  return (
    <div className="p-6 md:p-10 max-w-6xl mx-auto">
      <div className="flex flex-wrap items-center justify-between gap-4 mb-8">
        <div>
          <h2 className="text-[28px] font-bold text-[var(--text-primary)] tracking-tight">卡片库</h2>
          <p className="text-[13px] text-[var(--text-tertiary)] mt-1">概念 · 观点 · 证据 · 反思 — 知识路径的构成单元</p>
        </div>
      </div>

      {/* Filter + Batch actions */}
      <div className="flex flex-wrap items-center gap-2 mb-4">
        <div className="flex gap-1.5 flex-wrap flex-1">
          <button onClick={() => setFilter("")} className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${!filter ? "bg-[var(--brand-indigo)] text-white" : "bg-white text-[var(--text-secondary)] border border-[var(--border-default)]"}`}>全部</button>
          {cardTypes.map(t => (
            <button key={t} onClick={() => setFilter(t === filter ? "" : t)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${filter === t ? "bg-[var(--brand-indigo)] text-white" : "bg-white text-[var(--text-secondary)] border border-[var(--border-default)]"}`}>{TYPE_LABELS[t] || t}</button>
          ))}
        </div>
        <label className="text-[11px] text-[var(--text-tertiary)] flex items-center gap-1.5 cursor-pointer select-none">
          <input type="checkbox" checked={selected.size === cards.length && cards.length > 0} onChange={toggleAll} className="w-3.5 h-3.5" /> 全选
        </label>
      </div>

      {selected.size > 0 && (
        <div className="flex items-center gap-2 mb-4 bg-[var(--primary-100)] p-2.5 rounded-xl">
          <span className="text-xs text-[var(--primary-600)] font-medium">已选 {selected.size} 张</span>
          <button onClick={handleBatchExport} className="px-3 py-1.5 bg-[var(--brand-teal)] text-white text-xs rounded-lg font-medium">导出 Markdown</button>
          <button onClick={handleBatchDelete} className="px-3 py-1.5 bg-[var(--error)] text-white text-xs rounded-lg font-medium">删除</button>
          <button onClick={() => setSelected(new Set())} className="px-2 py-1 text-xs text-[var(--text-tertiary)]">取消</button>
        </div>
      )}

      {error && <p className="text-sm text-red-500 mb-4">{error}</p>}

      {loading ? <p className="text-sm text-[var(--text-tertiary)]">加载中...</p>
      : cards.length === 0 ? (
        <div className="text-center py-20">
          <div className="text-5xl mb-4">◈</div>
          <p className="text-sm text-[var(--text-secondary)]">还没有知识卡片</p>
          <p className="text-xs text-[var(--text-tertiary)] mt-2">在阅读器中选中文本 → 添加批注 → 转为知识卡片</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3">
          {cards.map(card => (
            <Card key={card.id} padding="md" className={selected.has(card.id) ? "ring-2 ring-[var(--brand-violet)]" : ""}>
              <div className="flex items-start gap-3">
                <input type="checkbox" checked={selected.has(card.id)} onChange={() => toggleSelect(card.id)} className="w-3.5 h-3.5 mt-1 flex-shrink-0 accent-[var(--brand-violet)]" />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1.5">
                    <span className={`text-[11px] px-2 py-0.5 rounded-md font-semibold ${TYPE_TAG[card.card_type] || "bg-gray-100 text-gray-600"}`}>{TYPE_LABELS[card.card_type] || card.card_type}</span>
                    <span className={`text-[11px] px-2 py-0.5 rounded-md font-medium ${card.calibration_status === "confirmed" ? "bg-[var(--teal-100)] text-[var(--teal-600)]" : card.calibration_status === "needsFollowUp" ? "bg-[var(--error-bg)] text-[var(--error)]" : "bg-[var(--warning-bg)] text-[var(--warning)]"}`}>{STATUS_LABELS[card.calibration_status] || card.calibration_status}</span>
                  </div>
                  <h4 className="text-[15px] font-semibold text-[var(--text-primary)] truncate">{card.title}</h4>
                  <p className="text-[13px] text-[var(--text-secondary)] mt-1 line-clamp-2">{card.content}</p>
                  {card.user_summary && <p className="text-[13px] text-[var(--brand-violet)] mt-1 italic">💬 {card.user_summary}</p>}
                  {card.source_document_title && (
                    <button onClick={() => card.source_document_id && navigate(`/reader/${card.source_document_id}`)}
                      className="text-[11px] text-[var(--brand-teal)] hover:underline mt-1.5 block">📄 {card.source_document_title} {card.page_number ? `p.${card.page_number}` : ""}</button>
                  )}
                  <div className="flex items-center gap-1.5 mt-2 pt-2 border-t border-[var(--border-light)]">
                    {card.calibration_status === "pendingReview" && (
                      <>
                        <button onClick={() => handleStatus(card, "confirmed")} className="text-[11px] px-2 py-1 bg-[var(--teal-100)] text-[var(--teal-600)] rounded-lg hover:bg-[var(--teal-300)]/30 transition-colors">确认</button>
                        <button onClick={() => handleStatus(card, "needsFollowUp")} className="text-[11px] px-2 py-1 bg-[var(--error-bg)] text-[var(--error)] rounded-lg hover:bg-[var(--error-bg)]/70 transition-colors">需跟进</button>
                      </>
                    )}
                    <button onClick={async () => { await api.cards.delete(card.id); setCards(p => p.filter(c => c.id !== card.id)); }}
                      className="text-[11px] ml-auto text-[var(--text-tertiary)] hover:text-[var(--error)]">删除</button>
                  </div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
