import { useMemo, useState } from "react";

interface ComparisonMatrixProps {
  nodes: any[];
  relations: any[];
}

export function ComparisonMatrix({ nodes, relations }: ComparisonMatrixProps) {
  // Group nodes by type for comparison dimensions
  const concepts = nodes.filter((n) => n.card_type === "concept");
  const claims = nodes.filter((n) => ["claim", "viewpoint", "argument"].includes(n.card_type));
  const evidence = nodes.filter((n) => n.card_type === "evidence");

  // Build a comparison table: concepts as rows, comparison dimensions as columns
  const dimensions = useMemo(() => {
    const dims: string[] = [];
    if (claims.length > 0) dims.push("主要观点");
    if (evidence.length > 0) dims.push("证据支持");
    dims.push("置信度", "状态");
    return dims;
  }, [claims, evidence]);

  const allNodes = [...concepts, ...claims, ...evidence];
  if (allNodes.length < 2) {
    return (
      <div className="h-96 flex items-center justify-center bg-[var(--page-bg)] rounded-lg border border-dashed border-[var(--border-default)]">
        <p className="text-sm text-[var(--text-tertiary)]">节点数量不足。需要至少 2 个节点才能生成比较矩阵。</p>
      </div>
    );
  }

  // Find relations between nodes for contextual info
  const nodeRelations = useMemo(() => {
    const map: Record<string, string[]> = {};
    for (const rel of relations) {
      const src = allNodes.find((n) => n.id === rel.source_card_id);
      const tgt = allNodes.find((n) => n.id === rel.target_card_id);
      if (src && tgt) {
        map[rel.source_card_id] = [...(map[rel.source_card_id] || []), `→ ${tgt.title}`];
        map[rel.target_card_id] = [...(map[rel.target_card_id] || []), `← ${src.title}`];
      }
    }
    return map;
  }, [allNodes, relations]);

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-xs border-collapse bg-white rounded-lg overflow-hidden border border-[var(--border-default)]">
        <thead>
          <tr className="bg-[var(--surface-lavender)]">
            <th className="text-left p-3 font-semibold text-[var(--brand-navy)] border-b border-[var(--border-default)] sticky left-0 bg-[var(--surface-lavender)]">
              节点
            </th>
            {dimensions.map((dim) => (
              <th key={dim} className="text-left p-3 font-semibold text-[var(--text-secondary)] border-b border-[var(--border-default)]">
                {dim}
              </th>
            ))}
            <th className="text-left p-3 font-semibold text-[var(--text-secondary)] border-b border-[var(--border-default)]">
              关联
            </th>
          </tr>
        </thead>
        <tbody>
          {allNodes.map((node) => {
            const rels = nodeRelations[node.id] || [];
            return (
              <tr key={node.id} className="border-b border-[var(--border-default)] hover:bg-[var(--page-bg)] transition-colors">
                <td className="p-3 sticky left-0 bg-white border-r border-[var(--border-default)]">
                  <div className="flex items-center gap-2">
                    <span className="w-1.5 h-1.5 rounded-full flex-shrink-0"
                      style={{ backgroundColor: node.card_type === "concept" ? "#6366f1" : node.card_type === "evidence" ? "#10b981" : "#f59e0b" }} />
                    <div>
                      <p className="font-medium text-[var(--text-primary)]">{node.title}</p>
                      <p className="text-[10px] text-[var(--text-tertiary)]">{node.card_type}</p>
                    </div>
                  </div>
                </td>
                {dimensions.includes("主要观点") && (
                  <td className="p-3 text-[var(--text-secondary)]">
                    {node.card_type === "claim" || node.card_type === "viewpoint"
                      ? node.user_summary || node.ai_generated_text?.slice(0, 60) || node.content?.slice(0, 60)
                      : node.card_type === "concept" ? "基础概念" : "—"}
                  </td>
                )}
                {dimensions.includes("证据支持") && (
                  <td className="p-3">
                    {node.card_type === "evidence"
                      ? <span className="text-[10px] text-[var(--brand-cyan)]">✓ 证据节点</span>
                      : <span className="text-[10px] text-[var(--text-tertiary)]">—</span>}
                  </td>
                )}
                <td className="p-3">
                  <div className="w-16 bg-gray-100 rounded-full h-1.5 overflow-hidden">
                    <div className="h-1.5 rounded-full"
                      style={{
                        width: `${Math.round((node.confidence_score || 0.8) * 100)}%`,
                        backgroundColor: node.card_type === "concept" ? "#6366f1" : node.card_type === "evidence" ? "#10b981" : "#f59e0b",
                      }} />
                  </div>
                  <span className="text-[9px] text-[var(--text-tertiary)]">{Math.round((node.confidence_score || 0.8) * 100)}%</span>
                </td>
                <td className="p-3">
                  {node.user_confirmed
                    ? <span className="text-[10px] text-green-600">✓ 已确认</span>
                    : <span className="text-[10px] text-amber-600">待确认</span>}
                </td>
                <td className="p-3 text-[10px] text-[var(--text-tertiary)]">
                  {rels.length > 0 ? rels.join(", ") : "—"}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
