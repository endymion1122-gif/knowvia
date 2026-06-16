import { useState, useEffect } from "react";
import { api } from "../../services/api";

interface ReadinessData {
  pathway_id: string;
  readiness_score: number;
  total_cards: number;
  total_claims: number;
  total_evidence: number;
  total_sources: number;
  checks: Record<string, { passed: boolean; label: string; detail: string; affected_ids: string[] }>;
  summary: string;
}

interface WritingChecklistProps {
  pathwayId: string;
  nodes: any[];
  documents: any[];
  onNavigateToNode?: (nodeId: string) => void;
}

export function WritingChecklist({ pathwayId, nodes, documents, onNavigateToNode }: WritingChecklistProps) {
  const [data, setData] = useState<ReadinessData | null>(null);
  const [loading, setLoading] = useState(true);
  const [doneItems, setDoneItems] = useState<Set<string>>(new Set());

  useEffect(() => {
    api.pathways.list().then(() => {
      // Use fetch for custom endpoint
      const token = localStorage.getItem("token");
      fetch(`/api/pathways/${pathwayId}/writing-readiness`, {
        headers: { Authorization: `Bearer ${token}` },
      })
        .then(r => r.json())
        .then(setData)
        .finally(() => setLoading(false));
    });
  }, [pathwayId]);

  const toggleDone = (key: string) => {
    setDoneItems(prev => {
      const next = new Set(prev);
      next.has(key) ? next.delete(key) : next.add(key);
      return next;
    });
  };

  if (loading) return <p className="text-xs text-[var(--text-tertiary)] animate-pulse">分析中...</p>;
  if (!data) return <p className="text-xs text-red-500">加载失败</p>;

  const checks = Object.entries(data.checks);
  const totalDone = checks.filter(([k]) => doneItems.has(k) || data.checks[k].passed).length;

  // Build action items from failed checks
  const actionItems = checks.flatMap(([key, check]) => {
    if (check.passed) return [];
    return check.affected_ids.map((id, i) => {
      const node = nodes.find(n => n.id === id);
      const doc = documents.find(d => d.id === id);
      const itemKey = `${key}-${id}`;
      return {
        key: itemKey,
        checkKey: key,
        label: check.label,
        detail: node ? `"${node.title}"` : doc ? `"${doc.title}"` : id,
        targetId: id,
        targetType: node ? "node" : "source",
        done: doneItems.has(itemKey),
      };
    });
  });

  return (
    <div className="space-y-4">
      {/* Score card */}
      <div className="bg-white p-4 rounded-xl border border-[var(--border-default)]">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-semibold text-[var(--text-primary)]">写作准备度</h3>
          <span className={`text-lg font-bold ${data.readiness_score >= 75 ? "text-green-600" : data.readiness_score >= 50 ? "text-amber-600" : "text-red-600"}`}>
            {data.readiness_score}%
          </span>
        </div>
        <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden mb-3">
          <div
            className={`h-2 rounded-full transition-all ${data.readiness_score >= 75 ? "bg-green-500" : data.readiness_score >= 50 ? "bg-amber-500" : "bg-red-500"}`}
            style={{ width: `${data.readiness_score}%` }}
          />
        </div>
        <div className="grid grid-cols-2 gap-1.5 text-[10px] text-[var(--text-secondary)]">
          <span>{data.total_cards} 节点</span>
          <span>{data.total_claims} 观点</span>
          <span>{data.total_evidence} 证据</span>
          <span>{data.total_sources} 来源</span>
        </div>
        <p className="text-[10px] text-[var(--text-tertiary)] mt-2 italic">{data.summary}</p>
      </div>

      {/* Checklist */}
      <div className="space-y-1.5">
        {checks.map(([key, check]) => (
          <div
            key={key}
            className={`flex items-center gap-2 p-2.5 rounded-lg text-xs border transition-colors ${
              check.passed || doneItems.has(key)
                ? "bg-green-50 border-green-200"
                : "bg-amber-50 border-amber-200"
            }`}
          >
            <input
              type="checkbox"
              checked={check.passed || doneItems.has(key)}
              onChange={() => !check.passed && toggleDone(key)}
              disabled={check.passed}
              className="w-3.5 h-3.5 accent-[var(--brand-cyan)]"
            />
            <div className="flex-1 min-w-0">
              <p className="font-medium text-[var(--text-primary)]">{check.label}</p>
              <p className="text-[10px] text-[var(--text-secondary)]">{check.detail}</p>
            </div>
            {check.passed ? (
              <span className="text-green-600 text-xs">✓</span>
            ) : (
              <span className="text-amber-600 text-xs">{check.affected_ids.length}</span>
            )}
          </div>
        ))}
      </div>

      {/* Action items */}
      {actionItems.length > 0 && (
        <div>
          <h4 className="text-[11px] font-semibold text-[var(--text-secondary)] mb-2">
            行动清单 ({actionItems.filter(a => !a.done).length} 项待处理)
          </h4>
          <div className="space-y-1">
            {actionItems.map((item) => (
              <div
                key={item.key}
                className={`flex items-center gap-2 p-2 rounded text-xs border ${
                  item.done ? "bg-gray-50 border-gray-200 opacity-50" : "bg-white border-[var(--border-default)]"
                }`}
              >
                <input
                  type="checkbox"
                  checked={item.done}
                  onChange={() => toggleDone(item.key)}
                  className="w-3 h-3 accent-[var(--brand-violet)] flex-shrink-0"
                />
                <span className="text-[10px] text-[var(--text-tertiary)] flex-shrink-0">{item.label}:</span>
                <button
                  onClick={() => {
                    if (item.targetType === "node") onNavigateToNode?.(item.targetId);
                  }}
                  className="text-[var(--brand-violet)] hover:underline truncate text-left"
                >
                  {item.detail}
                </button>
              </div>
            ))}
          </div>
          <p className="text-[9px] text-[var(--text-tertiary)] mt-1">
            完成 {totalDone}/{checks.length} 项检查 · {actionItems.filter(a => !a.done).length} 项待处理
          </p>
        </div>
      )}
    </div>
  );
}
