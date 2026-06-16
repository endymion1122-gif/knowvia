import { useMemo, useCallback } from "react";
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  Handle,
  Position,
  type Node,
  type Edge,
  type NodeProps,
  useNodesState,
  useEdgesState,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";

/* ---------- constants ---------- */

const TYPE_COLORS: Record<string, string> = {
  concept: "#6366f1", claim: "#f59e0b", viewpoint: "#f59e0b",
  evidence: "#10b981", question: "#ef4444", summary: "#8b5cf6",
  model: "#06b6d4", case: "#f97316", reflection: "#ec4899",
  note: "#6b7280", argument: "#f59e0b",
};

const REL_LABELS: Record<string, string> = {
  definition: "定义", support: "支撑", oppose: "反对", cause: "因果",
  example: "例证", include: "包含", precondition: "前提",
  application: "应用", evolution: "演变", contrast: "对比",
};

/* ---------- custom node ---------- */

interface PathwayNodeData {
  title: string;
  cardType: string;
  summary: string;
  confidence: number;
}

function PathwayNode({ data, selected }: NodeProps) {
  const { title, cardType, summary, confidence } = data as unknown as PathwayNodeData;
  const color = TYPE_COLORS[cardType] || "#6b7280";
  return (
    <div
      className="bg-white rounded-xl border-2 shadow-md px-4 py-3 text-xs w-56"
      style={{ borderColor: selected ? "#4f46e5" : color }}
    >
      <Handle type="target" position={Position.Left} style={{ background: color }} />
      <div className="flex items-center gap-1.5 mb-1">
        <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: color }} />
        <span className="font-semibold text-[var(--text-primary)] truncate">{title}</span>
      </div>
      <p className="text-[10px] text-[var(--text-secondary)] line-clamp-2 leading-relaxed">{summary}</p>
      <div className="flex items-center gap-1 mt-2">
        <div className="flex-1 h-1 bg-gray-100 rounded-full overflow-hidden">
          <div className="h-1 rounded-full transition-all" style={{ width: `${Math.round(confidence * 100)}%`, backgroundColor: color }} />
        </div>
        <span className="text-[9px] tabular-nums text-[var(--text-tertiary)]">{Math.round(confidence * 100)}%</span>
      </div>
      <Handle type="source" position={Position.Right} style={{ background: color }} />
    </div>
  );
}

const nodeTypes = { pathwayNode: PathwayNode };

/* ---------- main component ---------- */

interface PathwayGraphProps {
  nodes: any[];
  relations: any[];
  onNodeClick?: (nodeId: string) => void;
}

export function PathwayGraph({ nodes, relations, onNodeClick }: PathwayGraphProps) {
  const rfNodes: Node[] = useMemo(() => {
    const cols = Math.max(2, Math.ceil(Math.sqrt(nodes.length || 1)));
    return nodes.map((n, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      return {
        id: n.id,
        type: "pathwayNode",
        position: { x: col * 310 + 40, y: row * 160 + 40 },
        data: {
          title: n.title || "?",
          cardType: n.card_type || "note",
          summary: n.user_summary || n.ai_generated_text || n.content?.slice(0, 80) || "",
          confidence: n.confidence_score ?? 0.8,
        },
      };
    });
  }, [nodes]);

  const rfEdges: Edge[] = useMemo(() => {
    return relations.map((r, i) => ({
      id: r.id || `e-${i}`,
      source: r.source_card_id,
      target: r.target_card_id,
      label: REL_LABELS[r.relation_type] || r.relation_type,
      animated: true,
      style: { stroke: "#c7d2fe", strokeWidth: 2 },
      labelStyle: { fontSize: 10, fill: "#4f46e5", fontWeight: 600 },
      labelBgStyle: { fill: "#eef2ff", fillOpacity: 0.95 },
      labelBgPadding: [6, 3] as [number, number],
    }));
  }, [relations]);

  const [flowNodes, , onNodesChange] = useNodesState(rfNodes);
  const [flowEdges, , onEdgesChange] = useEdgesState(rfEdges);

  useMemo(() => {
    flowNodes.splice(0, flowNodes.length, ...rfNodes);
    flowEdges.splice(0, flowEdges.length, ...rfEdges);
  }, [rfNodes, rfEdges]);

  const handleNodeClick = useCallback(
    (_: any, node: Node) => onNodeClick?.(node.id),
    [onNodeClick],
  );

  if (nodes.length === 0) {
    return (
      <div className="h-96 flex items-center justify-center bg-[var(--bg-page)] rounded-lg border border-dashed border-[var(--border-default)]">
        <p className="text-sm text-[var(--text-tertiary)]">暂无节点数据。上传资料并提取节点后可查看知识路径图。</p>
      </div>
    );
  }

  return (
    <div className="h-[600px] w-full rounded-lg border border-[var(--border-default)] overflow-hidden bg-[var(--bg-page)]">
      <ReactFlow
        nodes={flowNodes}
        edges={flowEdges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onNodeClick={handleNodeClick}
        nodeTypes={nodeTypes}
        fitView
        fitViewOptions={{ padding: 0.3 }}
      >
        <Background color="#e5e7eb" gap={24} />
        <Controls position="bottom-right" />
        <MiniMap
          nodeColor={(n) => TYPE_COLORS[(n.data as any)?.cardType] || "#6b7280"}
          style={{ backgroundColor: "#f9fafb" }}
          pannable
          zoomable
        />
      </ReactFlow>
    </div>
  );
}
