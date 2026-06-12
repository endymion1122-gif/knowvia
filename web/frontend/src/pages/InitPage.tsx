import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";

export function InitPage() {
  const navigate = useNavigate();
  const [title, setTitle] = useState("");
  const [goal, setGoal] = useState("");
  const [existingKnowledge, setExistingKnowledge] = useState("");
  const [outputTarget, setOutputTarget] = useState("");
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState("");

  const handleCreate = async () => {
    if (!title.trim()) { setError("请输入路径主题"); return; }
    setCreating(true);
    setError("");
    try {
      const { pathway } = await api.pathways.create({
        title: title.trim(),
        goal: goal.trim(),
        existing_knowledge: existingKnowledge.trim(),
        output_target: outputTarget.trim(),
      });
      navigate(`/pathway/${pathway.id}`);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="p-8 max-w-2xl mx-auto">
      <div className="mb-8">
        <h2 className="text-2xl font-semibold text-[var(--deep-indigo)] mb-1">开启知识路径</h2>
        <p className="text-xs text-[var(--tertiary-text)]">
          回答以下问题，帮助 AI 更好地理解你的学习目标
        </p>
      </div>

      <div className="bg-white p-6 rounded-xl border border-[var(--cool-gray)] space-y-5">
        {/* Title */}
        <div>
          <label className="block text-sm font-semibold text-[var(--primary-text)] mb-1">
            路径主题 <span className="text-red-400">*</span>
          </label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="例如：认知负荷理论学习路径"
            className="w-full px-4 py-2.5 border border-[var(--cool-gray)] rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]"
          />
        </div>

        {/* Q1 */}
        <div>
          <label className="block text-sm font-semibold text-[var(--primary-text)] mb-1">
            Q1: 我为什么学这个？
          </label>
          <textarea
            value={goal}
            onChange={(e) => setGoal(e.target.value)}
            placeholder="说明你的学习动机和目标..."
            className="w-full px-4 py-2.5 border border-[var(--cool-gray)] rounded-lg text-sm h-20 resize-none focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]"
          />
        </div>

        {/* Q2 */}
        <div>
          <label className="block text-sm font-semibold text-[var(--primary-text)] mb-1">
            Q2: 我已经知道什么？
          </label>
          <textarea
            value={existingKnowledge}
            onChange={(e) => setExistingKnowledge(e.target.value)}
            placeholder="你目前对这个主题的了解..."
            className="w-full px-4 py-2.5 border border-[var(--cool-gray)] rounded-lg text-sm h-20 resize-none focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]"
          />
        </div>

        {/* Q3 */}
        <div>
          <label className="block text-sm font-semibold text-[var(--primary-text)] mb-1">
            Q3: 我最后要输出什么？
          </label>
          <textarea
            value={outputTarget}
            onChange={(e) => setOutputTarget(e.target.value)}
            placeholder="例如：完成3000字综述、准备课堂汇报、撰写研究计划..."
            className="w-full px-4 py-2.5 border border-[var(--cool-gray)] rounded-lg text-sm h-20 resize-none focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]"
          />
        </div>

        {error && <p className="text-sm text-red-500">{error}</p>}

        <div className="flex gap-3 pt-2">
          <button
            onClick={handleCreate}
            disabled={creating || !title.trim()}
            className="flex-1 py-2.5 bg-[var(--deep-indigo)] text-white rounded-lg text-sm font-semibold hover:opacity-90 disabled:opacity-40 transition-opacity"
          >
            {creating ? "创建中..." : "创建路径，开始学习"}
          </button>
          <button
            onClick={() => navigate("/pathways")}
            className="px-6 py-2.5 text-sm text-[var(--secondary-text)] hover:text-[var(--primary-text)] transition-colors"
          >
            取消
          </button>
        </div>
      </div>

      {/* Hint */}
      <div className="mt-4 bg-[var(--pale-lavender)] p-4 rounded-lg">
        <p className="text-[11px] text-[var(--secondary-text)]">
          这些信息将帮助 AI 更精准地从资料中提取与你的学习目标相关的概念、观点和证据。
          你也可以跳过详细填写，直接创建路径后上传资料。
        </p>
      </div>
    </div>
  );
}
