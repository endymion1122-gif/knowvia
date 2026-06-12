import { useState, useEffect, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { PDFReader } from "../components/reader/PDFReader";
import { TextReader } from "../components/reader/TextReader";
import { api } from "../services/api";
import type { Document as DocType, Annotation, CardKind } from "../types";

const CARD_TYPE_OPTIONS: { value: CardKind; label: string }[] = [
  { value: "concept", label: "概念" },
  { value: "claim" as CardKind, label: "观点" },
  { value: "evidence", label: "证据" },
  { value: "question", label: "问题" },
  { value: "summary", label: "摘要" },
  { value: "reflection", label: "反思" },
  { value: "note", label: "笔记" },
];

function getAISettings() {
  try {
    return JSON.parse(localStorage.getItem("ai_settings") || "{}");
  } catch { return {}; }
}

export function ReaderPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [doc, setDoc] = useState<DocType | null>(null);
  const [annotations, setAnnotations] = useState<Annotation[]>([]);
  const [selectedText, setSelectedText] = useState("");
  const [selectedPage, setSelectedPage] = useState(0);
  const [note, setNote] = useState("");
  const [aiResult, setAiResult] = useState("");
  const [aiLoading, setAiLoading] = useState(false);
  const [docSummary, setDocSummary] = useState<any>(null);
  const [summaryLoading, setSummaryLoading] = useState(false);

  // Card creation state
  const [cardTargetAnn, setCardTargetAnn] = useState<Annotation | null>(null);
  const [cardType, setCardType] = useState<CardKind>("concept");
  const [cardParaphrase, setCardParaphrase] = useState("");
  const [cardCreating, setCardCreating] = useState(false);
  const [cardCreated, setCardCreated] = useState(false);

  const token = localStorage.getItem("token");

  const loadAnnotations = useCallback(async () => {
    if (!id) return;
    const res = await fetch(`/api/annotations?document_id=${id}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.ok) {
      const { annotations } = await res.json();
      setAnnotations(annotations);
    }
  }, [id, token]);

  useEffect(() => {
    if (!id) return;
    api.documents.list().then(({ documents }) => {
      const found = documents.find((d: any) => d.id === id);
      if (found) setDoc(found);
    });
    loadAnnotations();
  }, [id, loadAnnotations]);

  const handleTextSelect = useCallback((text: string, page: number) => {
    setSelectedText(text);
    setSelectedPage(page);
    setNote("");
    setAiResult("");
  }, []);

  const handleAddAnnotation = async () => {
    if (!selectedText.trim() || !id) return;
    const res = await fetch("/api/annotations", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify({ document_id: id, selected_text: selectedText, note, page_number: selectedPage }),
    });
    const data = await res.json();
    if (res.ok) {
      setAnnotations((prev) => [...prev, data.annotation]);
      setNote("");
    }
  };

  const handleDeleteAnnotation = async (annId: string) => {
    const res = await fetch(`/api/annotations/${annId}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.ok) {
      setAnnotations((prev) => prev.filter((a) => a.id !== annId));
    }
  };

  const handleStartCard = (ann: Annotation) => {
    setCardTargetAnn(ann);
    setCardType("concept");
    setCardParaphrase(ann.note || "");
    setCardCreated(false);
  };

  const handleCreateCard = async () => {
    if (!cardTargetAnn || !cardParaphrase.trim()) return;
    setCardCreating(true);
    try {
      await api.cards.create({
        title: cardTargetAnn.selected_text.slice(0, 80),
        content: cardParaphrase.trim(),
        card_type: cardType,
        source_document_id: cardTargetAnn.document_id,
        source_document_title: doc?.title || "",
        page_number: cardTargetAnn.page_number ?? undefined,
        calibration_note: cardParaphrase.trim(),
      });
      setCardCreated(true);
      setTimeout(() => {
        setCardTargetAnn(null);
        setCardCreated(false);
      }, 1500);
    } catch (e: any) {
      alert("创建卡片失败: " + e.message);
    } finally {
      setCardCreating(false);
    }
  };

  const handleAIAnalyze = async () => {
    if (!selectedText.trim()) return;
    setAiLoading(true);
    try {
      const aiSettings = getAISettings();
      const res = await fetch("/api/ai/explain", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          text: selectedText,
          context: doc?.title || "",
          apiKey: aiSettings.apiKey,
          endpoint: aiSettings.apiEndpoint,
          model: aiSettings.modelName,
        }),
      });
      const data = await res.json();
      if (res.ok) setAiResult(data.mode === "demo" ? `[Demo AI] ${data.result}` : data.result);
      else setAiResult("错误: " + (data.error || "请求失败"));
    } catch (e: any) {
      setAiResult("AI 请求失败: " + e.message);
    } finally { setAiLoading(false); }
  };

  const handleSummarize = async () => {
    if (!doc) return;
    setSummaryLoading(true);
    try {
      // Fetch document content
      const fileName = doc.file_path.split("/").pop();
      let content = "";
      if (doc.file_type === "txt" || doc.file_type === "md") {
        const fileRes = await fetch(`/uploads/${fileName}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (fileRes.ok) content = await fileRes.text();
      } else {
        // PDF — can't extract text easily from client; send title-based summary
        content = `[PDF 文件] ${doc.title}`;
      }

      const aiSettings = getAISettings();
      const res = await fetch("/api/ai/summarize-document", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          content: content.slice(0, 10000),
          title: doc.title,
          apiKey: aiSettings.apiKey,
          endpoint: aiSettings.apiEndpoint,
          model: aiSettings.modelName,
        }),
      });
      const data = await res.json();
      if (res.ok) setDocSummary({ ...data, mode: data.mode || "api" });
      else setDocSummary({ error: data.error || "请求失败" });
    } catch (e: any) {
      setDocSummary({ error: "AI 请求失败: " + e.message });
    } finally { setSummaryLoading(false); }
  };

  if (!doc) return <div className="p-8 text-sm text-[var(--tertiary-text)]">加载中...</div>;

  return (
    <div className="flex h-full">
      {/* Reader */}
      <div className="flex-1 flex flex-col min-w-0">
        <div className="flex items-center gap-3 px-4 py-2 bg-[var(--warm-white)] border-b border-[var(--cool-gray)]">
          <button onClick={() => navigate("/library")} className="text-xs text-[var(--soft-violet)] hover:underline">← 资料库</button>
          <span className="text-xs text-[var(--tertiary-text)]">|</span>
          <span className="text-sm font-medium text-[var(--primary-text)] truncate">{doc.title}</span>
          <span className="text-[10px] text-[var(--path-teal)] ml-auto">{doc.file_type.toUpperCase()}</span>
        </div>
        {doc.file_type === "pdf" ? (
          <PDFReader document={doc} onTextSelect={handleTextSelect} />
        ) : (
          <TextReader document={doc} onTextSelect={handleTextSelect} />
        )}
      </div>

      {/* Inspector Sidebar */}
      <aside className="w-80 flex-shrink-0 bg-[var(--warm-white)] border-l border-[var(--cool-gray)] overflow-auto">
        <div className="p-4 space-y-4">
          {selectedText ? (
            <>
              <div>
                <h4 className="text-[11px] font-semibold text-[var(--slate-blue)] mb-2">已选文本 {selectedPage > 0 && `（第 ${selectedPage} 页）`}</h4>
                <p className="text-xs text-[var(--secondary-text)] bg-[var(--page-bg)] p-2 rounded border max-h-24 overflow-auto">{selectedText}</p>
              </div>

              <div>
                <h4 className="text-[11px] font-semibold text-[var(--slate-blue)] mb-2">添加批注</h4>
                <textarea value={note} onChange={(e) => setNote(e.target.value)}
                  className="w-full text-xs p-2 border rounded h-16 resize-none focus:outline-none focus:ring-1 focus:ring-[var(--soft-violet)]"
                  placeholder="你的理解..." />
                <button onClick={handleAddAnnotation}
                  className="mt-2 w-full py-1.5 bg-[var(--soft-violet)] text-white text-xs font-semibold rounded hover:opacity-90">
                  保存批注
                </button>
              </div>

              <div>
                <h4 className="text-[11px] font-semibold text-[var(--slate-blue)] mb-2">AI 概念解释</h4>
                <button onClick={handleAIAnalyze} disabled={aiLoading}
                  className="w-full py-1.5 bg-[var(--deep-indigo)] text-white text-xs font-semibold rounded hover:opacity-90 disabled:opacity-50">
                  {aiLoading ? "分析中..." : "解释选中概念"}
                </button>
                {aiResult && (
                  <div className="mt-2 text-xs text-[var(--secondary-text)] bg-[var(--pale-lavender)] p-2 rounded max-h-40 overflow-auto whitespace-pre-wrap">
                    {aiResult}
                  </div>
                )}
              </div>
            </>
          ) : (
            <p className="text-[10px] text-[var(--tertiary-text)]">选中文本后可以添加批注或让 AI 解释</p>
          )}

          <hr className="border-[var(--cool-gray)]" />

          {/* Document AI Analysis */}
          <div>
            <h4 className="text-[11px] font-semibold text-[var(--slate-blue)] mb-2">AI 文档分析</h4>
            <button
              onClick={handleSummarize}
              disabled={summaryLoading}
              className="w-full py-1.5 bg-[var(--path-teal)] text-white text-xs font-semibold rounded hover:opacity-90 disabled:opacity-50"
            >
              {summaryLoading ? "分析中..." : "分析本文档"}
            </button>
            {docSummary && !docSummary.error && (
              <div className="mt-2 text-xs space-y-2 bg-[var(--page-bg)] p-3 rounded border max-h-64 overflow-auto">
                <p className="text-[var(--primary-text)] leading-relaxed">{docSummary.summary}</p>
                <div className="flex gap-1 flex-wrap">
                  <span className="text-[10px] px-1.5 py-0.5 bg-[var(--pale-lavender)] rounded text-[var(--deep-indigo)]">
                    结构：{docSummary.structure_type}
                  </span>
                  <span className="text-[10px] px-1.5 py-0.5 bg-[var(--pale-mint)] rounded text-[var(--path-teal)]">
                    推荐视图：{docSummary.recommended_view}
                  </span>
                  {docSummary.mode === "demo" && (
                    <span className="text-[10px] px-1.5 py-0.5 bg-amber-100 rounded text-amber-700">Demo</span>
                  )}
                </div>
                {docSummary.reading_goal && (
                  <p className="text-[10px] text-[var(--tertiary-text)]">🎯 {docSummary.reading_goal}</p>
                )}
                {docSummary.key_items?.length > 0 && (
                  <div>
                    <div className="flex items-center justify-between mt-1">
                      <p className="text-[10px] font-semibold text-[var(--slate-blue)]">关键条目：</p>
                      <button
                        onClick={async () => {
                          for (const item of docSummary.key_items) {
                            try {
                              await api.cards.create({
                                title: item.title,
                                content: item.content,
                                card_type: item.type,
                                source_document_id: doc?.id,
                                source_document_title: doc?.title || "",
                                calibration_note: "",
                              });
                            } catch {}
                          }
                          alert("已全部转为知识卡片，可在「知识节点」页面查看。");
                        }}
                        className="text-[10px] text-[var(--path-teal)] hover:underline"
                      >
                        全部转为卡片
                      </button>
                    </div>
                    {docSummary.key_items.map((item: any, i: number) => (
                      <div key={i} className="text-[10px] mt-0.5 flex items-start gap-1 group/item">
                        <span className={`flex-shrink-0 w-1 h-1 rounded-full mt-1 ${item.importance === "high" ? "bg-red-400" : item.importance === "medium" ? "bg-amber-400" : "bg-gray-300"}`} />
                        <span className="text-[var(--secondary-text)] flex-1">[{item.type}] {item.title}: {item.content}</span>
                        <button
                          onClick={async () => {
                            try {
                              await api.cards.create({
                                title: item.title,
                                content: item.content,
                                card_type: item.type,
                                source_document_id: doc?.id,
                                source_document_title: doc?.title || "",
                                calibration_note: "",
                              });
                              alert("已转为知识卡片");
                            } catch (e: any) { alert("创建失败: " + e.message); }
                          }}
                          className="text-[10px] text-[var(--path-teal)] hover:underline opacity-0 group-hover/item:opacity-100 flex-shrink-0"
                        >
                          +卡片
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
            {docSummary?.error && (
              <p className="mt-2 text-xs text-red-500">{docSummary.error}</p>
            )}
          </div>

          <hr className="border-[var(--cool-gray)]" />

          <div>
            <h4 className="text-[11px] font-semibold text-[var(--slate-blue)] mb-2">批注列表 ({annotations.length})</h4>
            {annotations.length === 0 ? (
              <p className="text-[10px] text-[var(--tertiary-text)]">暂无批注</p>
            ) : (
              <div className="space-y-2">
                {annotations.map((a) => (
                  <div key={a.id}>
                    <div className="text-xs p-2 bg-[var(--page-bg)] rounded border group">
                      <div className="flex items-start justify-between gap-1">
                        <p className="text-[var(--secondary-text)] line-clamp-2 flex-1">"{a.selected_text}"</p>
                        <button
                          onClick={() => handleDeleteAnnotation(a.id)}
                          className="text-[10px] text-[var(--tertiary-text)] hover:text-red-500 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0"
                          title="删除批注"
                        >
                          ✕
                        </button>
                      </div>
                      {a.note && <p className="text-[var(--soft-violet)] mt-1">💬 {a.note}</p>}
                      <div className="flex items-center justify-between mt-1">
                        {a.page_number ? (
                          <span className="text-[10px] text-[var(--tertiary-text)]">p.{a.page_number}</span>
                        ) : <span />}
                        <button
                          onClick={() => handleStartCard(a)}
                          className="text-[10px] text-[var(--path-teal)] hover:text-[var(--deep-indigo)] opacity-0 group-hover:opacity-100 transition-opacity"
                        >
                          + 转为卡片
                        </button>
                      </div>
                    </div>

                    {/* Inline card creation form */}
                    {cardTargetAnn?.id === a.id && (
                      <div className="mt-1 p-2 bg-[var(--pale-mint)] rounded border border-[var(--path-teal)] text-xs">
                        {cardCreated ? (
                          <p className="text-[var(--path-teal)] text-center">✓ 卡片已创建</p>
                        ) : (
                          <>
                            <label className="text-[10px] font-semibold text-[var(--slate-blue)]">卡片类型</label>
                            <select
                              value={cardType}
                              onChange={(e) => setCardType(e.target.value as CardKind)}
                              className="w-full mt-1 px-2 py-1 border rounded text-xs focus:outline-none focus:ring-1 focus:ring-[var(--soft-violet)]"
                            >
                              {CARD_TYPE_OPTIONS.map((o) => (
                                <option key={o.value} value={o.value}>{o.label}</option>
                              ))}
                            </select>

                            <label className="text-[10px] font-semibold text-[var(--slate-blue)] mt-2 block">
                              我的一句话 <span className="text-[var(--tertiary-text)]">（用自己的话转述）</span>
                            </label>
                            <textarea
                              value={cardParaphrase}
                              onChange={(e) => setCardParaphrase(e.target.value)}
                              className="w-full mt-1 p-2 border rounded h-12 resize-none text-xs focus:outline-none focus:ring-1 focus:ring-[var(--soft-violet)]"
                              placeholder="用你自己的理解来重述这个概念..."
                            />

                            <div className="flex gap-2 mt-2">
                              <button
                                onClick={handleCreateCard}
                                disabled={cardCreating || !cardParaphrase.trim()}
                                className="flex-1 py-1 bg-[var(--deep-indigo)] text-white text-xs font-semibold rounded hover:opacity-90 disabled:opacity-40"
                              >
                                {cardCreating ? "创建中..." : "创建知识卡片"}
                              </button>
                              <button
                                onClick={() => setCardTargetAnn(null)}
                                className="px-2 py-1 text-xs text-[var(--tertiary-text)] hover:text-red-500"
                              >
                                取消
                              </button>
                            </div>
                          </>
                        )}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </aside>
    </div>
  );
}
