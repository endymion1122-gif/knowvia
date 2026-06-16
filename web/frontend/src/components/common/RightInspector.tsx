interface MetricItem {
  label: string;
  value: number; // 0-100
  color?: string;
}

interface RightInspectorProps {
  title?: string;
  score?: number;
  scoreLabel?: string;
  metrics?: MetricItem[];
  aiSuggestions?: string[];
  exportActions?: { label: string; onClick: () => void; primary?: boolean }[];
  children?: React.ReactNode;
}

export function RightInspector({
  title = "质量评估",
  score,
  scoreLabel = "综合评分",
  metrics = [],
  aiSuggestions = [],
  exportActions = [],
  children,
}: RightInspectorProps) {
  const hasContent = score != null || metrics.length > 0 || aiSuggestions.length > 0 || exportActions.length > 0;

  return (
    <div className="w-[288px] flex-shrink-0 space-y-4">
      {/* Score Card */}
      {score != null && (
        <div className="bg-white rounded-2xl border border-[var(--border-default)] shadow-[var(--shadow-card)] p-5">
          <h3 className="text-[13px] font-semibold text-[var(--text-secondary)] mb-4">{title}</h3>
          <div className="flex items-center gap-4 mb-4">
            <div
              className="w-[72px] h-[72px] rounded-full flex items-center justify-center text-lg font-bold text-white flex-shrink-0"
              style={{
                background: `conic-gradient(${score >= 80 ? "var(--brand-teal)" : score >= 50 ? "var(--warning)" : "var(--error)"} ${score * 3.6}deg, var(--border-light) ${score * 3.6}deg)`,
              }}
            >
              <div className="w-[56px] h-[56px] rounded-full bg-white flex items-center justify-center">
                <span className="text-xl font-bold text-[var(--text-primary)]">{score}</span>
              </div>
            </div>
            <div>
              <p className="text-xs text-[var(--text-tertiary)]">{scoreLabel}</p>
              <p className="text-[11px] text-[var(--text-tertiary)] mt-0.5">
                {score >= 80 ? "准备充分" : score >= 50 ? "需补充" : "需完善"}
              </p>
            </div>
          </div>

          {metrics.map((m) => (
            <div key={m.label} className="flex items-center gap-2 mb-2 last:mb-0">
              <span className="text-[11px] text-[var(--text-secondary)] w-20 flex-shrink-0">{m.label}</span>
              <div className="flex-1 h-1.5 bg-[var(--border-light)] rounded-full overflow-hidden">
                <div
                  className="h-full rounded-full transition-all"
                  style={{
                    width: `${m.value}%`,
                    backgroundColor: m.color || (m.value >= 80 ? "var(--brand-teal)" : m.value >= 50 ? "var(--warning)" : "var(--error)"),
                  }}
                />
              </div>
              <span className="text-[11px] text-[var(--text-tertiary)] w-8 text-right">{m.value}%</span>
            </div>
          ))}
        </div>
      )}

      {/* AI Suggestions */}
      {aiSuggestions.length > 0 && (
        <div className="bg-white rounded-2xl border border-[var(--border-default)] shadow-[var(--shadow-card)] p-5">
          <h3 className="text-[13px] font-semibold text-[var(--text-secondary)] mb-3">🤖 AI 建议</h3>
          <div className="space-y-2">
            {aiSuggestions.map((s, i) => (
              <button key={i} className="w-full text-left p-2.5 rounded-xl bg-[var(--primary-50)] hover:bg-[var(--primary-100)] transition-colors text-xs text-[var(--text-secondary)] leading-relaxed">
                {s}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Export Actions */}
      {exportActions.length > 0 && (
        <div className="bg-white rounded-2xl border border-[var(--border-default)] shadow-[var(--shadow-card)] p-5">
          <h3 className="text-[13px] font-semibold text-[var(--text-secondary)] mb-3">导出与分享</h3>
          <div className="space-y-2">
            {exportActions.map((a) => (
              <button
                key={a.label}
                onClick={a.onClick}
                className={`w-full h-9 rounded-xl text-xs font-medium transition-all duration-200 ${a.primary
                  ? "bg-[var(--brand-violet)] text-white hover:bg-[var(--primary-400)] shadow-[var(--shadow-card)]"
                  : "bg-[var(--bg-page)] text-[var(--text-secondary)] hover:bg-[var(--border-light)] border border-[var(--border-default)]"
                }`}
              >
                {a.label}
              </button>
            ))}
          </div>
        </div>
      )}

      {children}
    </div>
  );
}
