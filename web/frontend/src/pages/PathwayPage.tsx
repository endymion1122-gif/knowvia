export function PathwayPage() {
  return (
    <div className="p-8 max-w-5xl">
      <h2 className="text-2xl font-semibold text-[var(--deep-indigo)] mb-1">专题路径库</h2>
      <p className="text-xs text-[var(--tertiary-text)] mb-8">Knowledge Pathway — 围绕主题、理论或研究问题的结构化知识脉络</p>

      <div className="bg-white p-10 rounded-xl border border-dashed border-[var(--cool-gray)] text-center">
        <p className="text-sm text-[var(--secondary-text)]">专题路径功能即将上线。</p>
        <p className="text-xs text-[var(--tertiary-text)] mt-2">
          即将支持：路径总览 · 概念关系图 · 观点—证据链 · 文献贡献矩阵 · 学习路线图
        </p>
      </div>
    </div>
  );
}
