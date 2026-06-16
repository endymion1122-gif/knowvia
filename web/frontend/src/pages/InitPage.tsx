import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";
import { Card } from "../components/common/Card";

const inputClass = "w-full px-4 py-2.5 bg-[var(--bg-page)] border border-[var(--border-default)] rounded-xl text-[13px] placeholder:text-[var(--text-placeholder)] focus:outline-none focus:border-[var(--brand-violet)] focus:shadow-[var(--shadow-glow-violet)] transition-all resize-none";
const labelClass = "block text-[11px] font-semibold text-[var(--text-secondary)] mb-2 ml-0.5 uppercase tracking-wide";

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
    setCreating(true); setError("");
    try { const { pathway } = await api.pathways.create({ title: title.trim(), goal: goal.trim(), existing_knowledge: existingKnowledge.trim(), output_target: outputTarget.trim() }); navigate(`/pathway/${pathway.id}`); }
    catch (e: any) { setError(e.message); } finally { setCreating(false); }
  };

  return (
    <div className="p-6 md:p-10 max-w-2xl mx-auto">
      <div className="mb-8">
        <h2 className="text-[28px] font-bold text-[var(--text-primary)] tracking-tight">新知识路径</h2>
        <p className="text-[13px] text-[var(--text-tertiary)] mt-1">回答以下问题，帮助 AI 更好地理解你的学习目标</p>
      </div>

      <Card variant="panel" padding="lg" className="space-y-5">
        <div>
          <label className={labelClass}>路径主题 <span className="text-[var(--error)]">*</span></label>
          <input type="text" value={title} onChange={e => setTitle(e.target.value)} className={inputClass} placeholder="例如：认知负荷理论学习路径" required autoFocus />
        </div>
        <div>
          <label className={labelClass}>Q1: 我为什么学这个？</label>
          <textarea value={goal} onChange={e => setGoal(e.target.value)} className={`${inputClass} h-20`} placeholder="说明你的学习动机和目标..." />
        </div>
        <div>
          <label className={labelClass}>Q2: 我已经知道什么？</label>
          <textarea value={existingKnowledge} onChange={e => setExistingKnowledge(e.target.value)} className={`${inputClass} h-20`} placeholder="你目前对这个主题的了解..." />
        </div>
        <div>
          <label className={labelClass}>Q3: 我最后要输出什么？</label>
          <textarea value={outputTarget} onChange={e => setOutputTarget(e.target.value)} className={`${inputClass} h-20`} placeholder="例如：完成3000字综述、准备课堂汇报..." />
        </div>
        {error && <p className="text-sm text-[var(--error)] font-medium">{error}</p>}
        <div className="flex gap-3 pt-2">
          <button onClick={handleCreate} disabled={creating || !title.trim()}
            className="flex-1 h-10 bg-[var(--brand-violet)] text-white rounded-xl text-sm font-semibold hover:bg-[var(--primary-400)] disabled:opacity-40 transition-colors shadow-[var(--shadow-card)] hover:shadow-[var(--shadow-floating)]">
            {creating ? "创建中..." : "创建路径，开始学习"}
          </button>
          <button onClick={() => navigate("/pathways")} className="h-10 px-6 text-sm text-[var(--text-tertiary)] hover:text-[var(--text-primary)] transition-colors">取消</button>
        </div>
      </Card>

      <div className="mt-4 bg-[var(--primary-50)] rounded-2xl p-4">
        <p className="text-[12px] text-[var(--text-secondary)] leading-relaxed">这些信息将帮助 AI 更精准地从资料中提取与你的学习目标相关的概念、观点和证据。也可以跳过详细填写，直接创建路径后上传资料。</p>
      </div>
    </div>
  );
}
