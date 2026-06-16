import { useState } from "react";

interface EvidenceChainProps {
  nodes: any[];
  relations: any[];
  evidences?: any[];
}

const STRENGTH_COLORS: Record<string, string> = {
  strong: "bg-green-100 border-green-400 text-green-700",
  medium: "bg-amber-100 border-amber-400 text-amber-700",
  weak: "bg-red-100 border-red-400 text-red-700",
};

const TYPE_ICONS: Record<string, string> = {
  concept: "💡", claim: "💬", viewpoint: "💬", argument: "💬",
  evidence: "📊", question: "❓", summary: "📋",
};

export function EvidenceChain({ nodes, relations, evidences = [] }: EvidenceChainProps) {
  const [selectedClaim, setSelectedClaim] = useState<string | null>(null);

  // Find claim/viewpoint nodes
  const claims = nodes.filter((n) =>
    ["claim", "viewpoint", "argument"].includes(n.card_type)
  );
  const evidenceNodes = nodes.filter((n) => n.card_type === "evidence");

  // Build evidence chains: for each claim, find relations to evidence nodes
  const chains = claims.map((claim) => {
    const supportRels = relations.filter(
      (r) =>
        (r.source_card_id === claim.id || r.target_card_id === claim.id) &&
        evidenceNodes.some((e) => e.id === r.source_card_id || e.id === r.target_card_id)
    );
    const linkedEvidence = supportRels.map((rel) => {
      const evNodeId = rel.source_card_id === claim.id ? rel.target_card_id : rel.source_card_id;
      const evNode = evidenceNodes.find((e) => e.id === evNodeId);
      const evData = evidences.filter((e: any) => e.node_id === evNodeId);
      return { relation: rel, evidenceNode: evNode, evidenceData: evData };
    }).filter((x) => x.evidenceNode);

    return { claim, links: linkedEvidence };
  });

  if (claims.length === 0) {
    return (
      <div className="h-96 flex items-center justify-center bg-[var(--bg-page)] rounded-lg border border-dashed border-[var(--border-default)]">
        <p className="text-sm text-[var(--text-tertiary)]">暂无观点节点，无法生成证据链。请先提取节点并标记观点和证据类型。</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {chains.map(({ claim, links }) => (
        <div
          key={claim.id}
          className={`bg-white rounded-xl border-2 transition-all ${
            selectedClaim === claim.id
              ? "border-[var(--brand-indigo)] shadow-md"
              : "border-[var(--border-default)]"
          }`}
          onClick={() => setSelectedClaim(selectedClaim === claim.id ? null : claim.id)}
        >
          {/* Claim header */}
          <div className="p-4 cursor-pointer flex items-start gap-3">
            <span className="text-lg flex-shrink-0">{TYPE_ICONS[claim.card_type] || "◈"}</span>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-[var(--text-primary)]">{claim.title}</p>
              <p className="text-xs text-[var(--text-secondary)] mt-0.5 line-clamp-2">
                {claim.user_summary || claim.ai_generated_text || claim.content}
              </p>
              {claim.source_citation && (
                <span className="text-[10px] text-[var(--text-tertiary)]">来源: {claim.source_citation}</span>
              )}
            </div>
            <div className="flex items-center gap-1 flex-shrink-0">
              <span className="text-[10px] text-[var(--text-tertiary)]">
                {links.length} 条证据
              </span>
              <span className={`text-xs transition-transform ${selectedClaim === claim.id ? "rotate-90" : ""}`}>▶</span>
            </div>
          </div>

          {/* Evidence items (expanded) */}
          {selectedClaim === claim.id && (
            <div className="border-t border-[var(--border-default)] p-4 space-y-3 bg-[var(--bg-page)] rounded-b-xl">
              {links.length === 0 ? (
                <p className="text-xs text-[var(--text-tertiary)]">暂无关联证据。在节点编辑器中为此观点添加证据。</p>
              ) : (
                links.map((link, i) => (
                  <div key={i} className="flex items-start gap-3 bg-white p-3 rounded-lg border border-[var(--border-default)]">
                    {/* Mini flow: claim → relation → evidence */}
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <div className="w-2 h-2 rounded-full bg-[var(--brand-violet)]" />
                      <div className="w-8 h-0.5 bg-[var(--border-default)]" />
                      <span className="text-[9px] px-1 py-0.5 bg-[var(--primary-100)] rounded text-[var(--brand-indigo)]">
                        {link.relation.relation_type}
                      </span>
                      <div className="w-8 h-0.5 bg-[var(--border-default)]" />
                      <div className="w-2 h-2 rounded-full bg-green-400" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-medium text-[var(--text-primary)]">
                        {link.evidenceNode?.title || "证据"}
                      </p>
                      <p className="text-[10px] text-[var(--text-secondary)] mt-0.5">
                        {link.evidenceNode?.content || link.evidenceNode?.ai_generated_text}
                      </p>
                      {(link.evidenceData).map((ev: any, j: number) => (
                        <div key={j} className="mt-1 flex items-center gap-2">
                          <span className={`text-[9px] px-1 py-0.5 rounded border ${STRENGTH_COLORS[ev.evidence_strength] || "bg-gray-100"}`}>
                            {ev.evidence_strength === "strong" ? "强证据" : ev.evidence_strength === "medium" ? "中证据" : "弱证据"}
                          </span>
                          {ev.source_location && <span className="text-[9px] text-[var(--text-tertiary)]">{ev.source_location}</span>}
                          <span className="text-[9px] text-[var(--text-tertiary)]">{ev.evidence_type}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                ))
              )}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
