import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";

interface RecallItem {
  card: any;
  revealed: boolean;
  userAnswer: string;
  feedback: "" | "correct" | "partial" | "incorrect";
}

export function RecallPage() {
  const navigate = useNavigate();
  const [pathways, setPathways] = useState<any[]>([]);
  const [selectedPathway, setSelectedPathway] = useState<string>("");
  const [items, setItems] = useState<RecallItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [started, setStarted] = useState(false);
  const [score, setScore] = useState(0);

  // Load pathways for selection
  useEffect(() => {
    api.pathways.list().then(({ pathways }) => setPathways(pathways));
  }, []);

  const startRecall = useCallback(async () => {
    if (!selectedPathway) return;
    setLoading(true);

    // Get pathway documents
    const { documents } = await api.pathways.getDocuments(selectedPathway);
    const allCards = await api.cards.list();
    const pwCards = allCards.cards.filter((c: any) =>
      documents.some((d: any) => d.id === c.source_document_id)
    );

    // Shuffle and pick items
    const shuffled = [...pwCards].sort(() => Math.random() - 0.5);
    const selected = shuffled.slice(0, Math.min(8, shuffled.length));
    setItems(selected.map((c) => ({ card: c, revealed: false, userAnswer: "", feedback: "" as const })));
    setScore(0);
    setStarted(true);
    setLoading(false);
  }, [selectedPathway]);

  const reveal = (idx: number) => {
    setItems((prev) => prev.map((item, i) => (i === idx ? { ...item, revealed: true } : item)));
  };

  const checkAnswer = (idx: number) => {
    setItems((prev) => {
      const item = prev[idx];
      const correct = item.card.user_summary || item.card.content || "";
      const userText = item.userAnswer.trim().toLowerCase();
      const correctText = correct.toLowerCase();

      let feedback: "" | "correct" | "partial" | "incorrect" = "";
      if (!userText) {
        feedback = "incorrect";
      } else if (userText === correctText || userText.length > 20 && correctText.includes(userText)) {
        feedback = "correct";
      } else if (userText.length > 5 && correctText.includes(userText.slice(0, 5))) {
        feedback = "partial";
      } else {
        feedback = "incorrect";
      }

      const newItems = prev.map((it, i) => (i === idx ? { ...it, feedback } : it));
      const correctCount = newItems.filter((it) => it.feedback === "correct" || it.feedback === "partial").length;
      setScore(correctCount);
      return newItems;
    });
  };

  if (!started) {
    return (
      <div className="p-8 max-w-2xl mx-auto">
        <h2 className="text-2xl font-semibold text-[var(--deep-indigo)] mb-1">主动回忆练习</h2>
        <p className="text-xs text-[var(--tertiary-text)] mb-6">
          选择一个知识路径，尝试用自己的话回忆每个节点的内容。这是最有效的学习策略之一。
        </p>
        <div className="bg-white p-6 rounded-xl border border-[var(--cool-gray)] space-y-4">
          {pathways.length === 0 ? (
            <p className="text-sm text-[var(--tertiary-text)]">还没有知识路径。请先创建路径并提取节点。</p>
          ) : (
            <>
              <select
                value={selectedPathway}
                onChange={(e) => setSelectedPathway(e.target.value)}
                className="w-full px-4 py-2.5 border border-[var(--cool-gray)] rounded-lg text-sm"
              >
                <option value="">选择知识路径...</option>
                {pathways.map((p) => (
                  <option key={p.id} value={p.id}>{p.title}</option>
                ))}
              </select>
              <button
                onClick={startRecall}
                disabled={!selectedPathway || loading}
                className="w-full py-2.5 bg-[var(--deep-indigo)] text-white rounded-lg text-sm font-semibold hover:opacity-90 disabled:opacity-40"
              >
                {loading ? "加载中..." : "开始回忆练习"}
              </button>
            </>
          )}
          <p className="text-[10px] text-[var(--tertiary-text)]">
            系统会从路径中随机选取节点，隐藏内容，请你用自己的话回忆。完成后可以对照原文检查。
          </p>
        </div>
        <button onClick={() => navigate("/pathways")} className="mt-4 text-xs text-[var(--soft-violet)] hover:underline">← 返回路径列表</button>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-semibold text-[var(--deep-indigo)]">主动回忆</h2>
          <p className="text-xs text-[var(--tertiary-text)]">
            进度：{items.filter((i) => i.revealed).length}/{items.length} · 正确：{score}
          </p>
        </div>
        <button onClick={() => { setStarted(false); setItems([]); }}
          className="text-xs text-[var(--soft-violet)] hover:underline">← 重新选择</button>
      </div>

      <div className="space-y-4">
        {items.map((item, idx) => (
          <div key={item.card.id} className="bg-white p-4 rounded-xl border border-[var(--cool-gray)]">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--pale-lavender)] text-[var(--deep-indigo)] font-semibold">
                {item.card.card_type}
              </span>
              <span className="text-sm font-medium text-[var(--primary-text)]">{item.card.title}</span>
              {item.feedback && (
                <span className={`ml-auto text-[10px] px-1.5 py-0.5 rounded font-semibold ${
                  item.feedback === "correct" ? "bg-green-100 text-green-700" :
                  item.feedback === "partial" ? "bg-amber-100 text-amber-700" :
                  "bg-red-100 text-red-700"
                }`}>
                  {item.feedback === "correct" ? "✓ 正确" : item.feedback === "partial" ? "△ 部分正确" : "✗ 需复习"}
                </span>
              )}
            </div>

            {!item.revealed ? (
              <div className="space-y-2">
                <textarea
                  value={item.userAnswer}
                  onChange={(e) => setItems((prev) => prev.map((it, i) => i === idx ? { ...it, userAnswer: e.target.value } : it))}
                  placeholder="用你自己的话回忆这个节点的内容..."
                  className="w-full px-3 py-2 border rounded-lg text-xs h-16 resize-none focus:outline-none focus:ring-1 focus:ring-[var(--soft-violet)]"
                />
                <div className="flex gap-2">
                  <button onClick={() => { checkAnswer(idx); reveal(idx); }}
                    disabled={!item.userAnswer.trim()}
                    className="px-3 py-1.5 bg-[var(--soft-violet)] text-white text-xs font-semibold rounded hover:opacity-90 disabled:opacity-40">
                    检查答案
                  </button>
                  <button onClick={() => reveal(idx)}
                    className="px-3 py-1.5 text-xs text-[var(--tertiary-text)] hover:text-[var(--primary-text)]">
                    跳过（直接查看）
                  </button>
                </div>
              </div>
            ) : (
              <div className="space-y-1">
                <div className="bg-[var(--page-bg)] p-3 rounded-lg">
                  <p className="text-xs text-[var(--secondary-text)]">📝 <strong>正确答案：</strong>{item.card.user_summary || item.card.content}</p>
                  {item.card.ai_generated_text && item.card.ai_generated_text !== item.card.content && (
                    <p className="text-[10px] text-[var(--tertiary-text)] mt-1">AI 原文：{item.card.ai_generated_text}</p>
                  )}
                </div>
                {item.userAnswer && (
                  <p className="text-[10px] text-[var(--tertiary-text)]">你的回答：{item.userAnswer}</p>
                )}
                <button onClick={() => {
                  setItems((prev) => prev.map((it, i) => i === idx ? { ...it, revealed: false } : it));
                }} className="text-[10px] text-[var(--path-teal)] hover:underline">
                  再试一次
                </button>
              </div>
            )}
          </div>
        ))}
      </div>

      {items.every((i) => i.revealed) && (
        <div className="mt-6 bg-[var(--pale-mint)] p-4 rounded-xl text-center">
          <p className="text-sm font-semibold text-[var(--path-teal)]">
            🎉 练习完成！得分：{score}/{items.length}
          </p>
          <p className="text-xs text-[var(--secondary-text)] mt-1">
            {score === items.length ? "完美！你对这个路径的掌握非常扎实。" :
             score >= items.length / 2 ? "不错！再复习一下标记为红色的节点。" :
             "继续加油！建议重新浏览路径内容后再练习一次。"}
          </p>
          <div className="flex gap-2 justify-center mt-3">
            <button onClick={() => startRecall()}
              className="px-4 py-1.5 bg-[var(--path-teal)] text-white text-xs font-semibold rounded hover:opacity-90">
              再来一轮
            </button>
            <button onClick={() => { setStarted(false); setItems([]); }}
              className="px-4 py-1.5 text-xs text-[var(--secondary-text)] hover:text-[var(--primary-text)]">
              换一个路径
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
