export function CardsPage() {
  return (
    <div className="p-8 max-w-5xl">
      <h2 className="text-2xl font-semibold text-[var(--deep-indigo)] mb-1">知识节点</h2>
      <p className="text-xs text-[var(--tertiary-text)] mb-8">概念 · 观点 · 证据 · 模型 · 反思 — 知识路径的基本构成单元</p>

      <div className="bg-white p-10 rounded-xl border border-dashed border-[var(--cool-gray)] text-center">
        <p className="text-sm text-[var(--secondary-text)]">知识节点管理即将上线。</p>
        <p className="text-xs text-[var(--tertiary-text)] mt-2">
          配合专题路径功能一起开放。支持概念、观点、证据、问题等节点类型。
        </p>
      </div>
    </div>
  );
}
