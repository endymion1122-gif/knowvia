import { useState, useEffect } from "react";

interface SourceQualityData {
  pathway_id: string;
  total_sources: number;
  metadata_completeness: number;
  breakdown: {
    complete: number; missingAuthor: number; missingYear: number;
    missingBoth: number; hasNote: number; hasUrl: number; citable: number;
  };
  authority_ratio: number;
  suggestions: { id: string; title: string; missing_fields: string[]; suggestion: string }[];
  summary: string;
}

interface SourceQualityProps {
  pathwayId: string;
  onNavigateToSource?: (sourceId: string) => void;
}

export function SourceQuality({ pathwayId, onNavigateToSource }: SourceQualityProps) {
  const [data, setData] = useState<SourceQualityData | null>(null);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem("token");
    fetch(`/api/pathways/${pathwayId}/source-quality`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then(r => r.json())
      .then(setData)
      .finally(() => setLoading(false));
  }, [pathwayId]);

  if (loading) return <p className="text-xs text-[var(--tertiary-text)] animate-pulse">分析来源质量...</p>;
  if (!data || data.total_sources === 0) {
    return (
      <div className="bg-white p-4 rounded-xl border border-[var(--cool-gray)]">
        <p className="text-xs text-[var(--tertiary-text)]">暂无来源资料。上传并关联文档后可见来源质量分析。</p>
      </div>
    );
  }

  const b = data.breakdown;

  return (
    <div className="space-y-3">
      {/* Score */}
      <div className="bg-white p-4 rounded-xl border border-[var(--cool-gray)]">
        <div className="flex items-center justify-between mb-2">
          <h4 className="text-xs font-semibold text-[var(--primary-text)]">来源元数据完整度</h4>
          <span className={`text-sm font-bold ${data.metadata_completeness >= 80 ? "text-green-600" : data.metadata_completeness >= 50 ? "text-amber-600" : "text-red-600"}`}>
            {data.metadata_completeness}%
          </span>
        </div>
        <div className="w-full h-1.5 bg-gray-100 rounded-full overflow-hidden mb-2">
          <div
            className={`h-1.5 rounded-full ${data.metadata_completeness >= 80 ? "bg-green-500" : data.metadata_completeness >= 50 ? "bg-amber-500" : "bg-red-500"}`}
            style={{ width: `${data.metadata_completeness}%` }}
          />
        </div>
        <div className="grid grid-cols-3 gap-1 text-[10px] text-[var(--secondary-text)]">
          <span>✓ {b.complete} 完整</span>
          <span>⚠ {b.missingAuthor} 缺作者</span>
          <span>⚠ {b.missingYear} 缺年份</span>
        </div>
        <div className="grid grid-cols-3 gap-1 text-[10px] text-[var(--secondary-text)] mt-0.5">
          <span>🔗 {b.hasUrl} 有链接</span>
          <span>📝 {b.hasNote} 有备注</span>
          <span>📖 {b.citable} 可引用</span>
        </div>
        <p className="text-[10px] text-[var(--tertiary-text)] mt-1.5">{data.summary}</p>
      </div>

      {/* Authority */}
      <div className="bg-white p-3 rounded-xl border border-[var(--cool-gray)]">
        <div className="flex items-center justify-between">
          <span className="text-[11px] font-semibold text-[var(--primary-text)]">权威来源比例</span>
          <span className="text-sm font-bold text-[var(--slate-blue)]">{data.authority_ratio}%</span>
        </div>
        <p className="text-[10px] text-[var(--tertiary-text)] mt-0.5">
          {data.authority_ratio >= 60 ? "来源可靠性良好" : data.authority_ratio >= 30 ? "建议补充更多可引用来源" : "来源可靠性较低，写作前需补充"}
        </p>
      </div>

      {/* Suggestions */}
      {data.suggestions.length > 0 && (
        <div>
          <button
            onClick={() => setExpanded(!expanded)}
            className="text-[11px] font-semibold text-[var(--slate-blue)] hover:underline flex items-center gap-1"
          >
            补全建议 ({data.suggestions.length})
            <span className={`text-[10px] transition-transform ${expanded ? "rotate-90" : ""}`}>▶</span>
          </button>
          {expanded && (
            <div className="mt-2 space-y-1.5">
              {data.suggestions.map((s) => (
                <div key={s.id} className="bg-white p-2.5 rounded-lg border border-[var(--cool-gray)] text-xs">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-[var(--primary-text)] truncate">{s.title}</p>
                      <p className="text-[10px] text-[var(--secondary-text)] mt-0.5">{s.suggestion}</p>
                      <div className="flex gap-1 mt-1">
                        {s.missing_fields.map((f) => (
                          <span key={f} className="text-[9px] px-1 py-0.5 bg-red-50 text-red-600 rounded">{f}</span>
                        ))}
                      </div>
                    </div>
                    <button
                      onClick={() => onNavigateToSource?.(s.id)}
                      className="text-[10px] text-[var(--soft-violet)] hover:underline flex-shrink-0"
                    >
                      编辑
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
