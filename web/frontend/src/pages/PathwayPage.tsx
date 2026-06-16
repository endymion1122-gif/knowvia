import { useState, useEffect, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { api } from "../services/api";
import { PathwayGraph } from "../components/pathway/PathwayGraph";
import { EvidenceChain } from "../components/pathway/EvidenceChain";
import { ComparisonMatrix } from "../components/pathway/ComparisonMatrix";
import { WritingChecklist } from "../components/pathway/WritingChecklist";
import { SourceQuality } from "../components/pathway/SourceQuality";
import { RightInspector } from "../components/common/RightInspector";
import { Card } from "../components/common/Card";

const RELATION_LABELS: Record<string, string> = {
  definition: "定义", support: "支撑", oppose: "反对", cause: "因果",
  example: "例证", include: "包含", precondition: "前提",
  application: "应用", evolution: "演变", contrast: "对比",
};

function getAISettings() {
  try { return JSON.parse(localStorage.getItem("ai_settings") || "{}"); }
  catch { return {}; }
}

export function PathwayPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [pathway, setPathway] = useState<any>(null);
  const [nodes, setNodes] = useState<any[]>([]);
  const [relations, setRelations] = useState<any[]>([]);
  const [documents, setDocuments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [uploading, setUploading] = useState(false);
  const [extracting, setExtracting] = useState(false);
  const [extractResult, setExtractResult] = useState<any>(null);
  const [exporting, setExporting] = useState(false);
  const [sharing, setSharing] = useState(false);
  const [shareUrl, setShareUrl] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<"edit" | "graph" | "evidence" | "matrix" | "writing">("edit");

  const [editingNode, setEditingNode] = useState<string | null>(null);
  const [editSummary, setEditSummary] = useState("");
  const [editType, setEditType] = useState("concept");
  const [editTitle, setEditTitle] = useState("");

  const [showAddRelation, setShowAddRelation] = useState(false);
  const [relSource, setRelSource] = useState("");
  const [relTarget, setRelTarget] = useState("");
  const [relType, setRelType] = useState("support");

  const loadData = useCallback(async () => {
    if (!id) return;
    try {
      const [pw, cs, rs, ds] = await Promise.all([
        api.pathways.get(id),
        api.cards.list(),
        api.relations.list(id),
        api.pathways.getDocuments(id),
      ]);
      setPathway(pw.pathway);
      const pwCards = cs.cards.filter((c: any) =>
        ds.documents.some((d: any) => d.id === c.source_document_id)
      );
      setNodes(pwCards);
      setRelations(rs.relations);
      setDocuments(ds.documents);
    } catch (e: any) { setError(e.message); }
    finally { setLoading(false); }
  }, [id]);

  useEffect(() => { loadData(); }, [loadData]);

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !id) return;
    setUploading(true);
    try {
      const { document } = await api.documents.upload(file);
      await api.pathways.linkDocument(id, document.id);
      await loadData();
    } catch (err: any) { setError(err.message); }
    finally { setUploading(false); }
  };

  const handleExtract = async () => {
    if (!id || documents.length === 0) return;
    setExtracting(true);
    setExtractResult(null);
    try {
      const ai = getAISettings();
      const docMarkdown = await fetch(`/api/documents/${documents[0].id}/markdown`, {
        headers: { Authorization: `Bearer ${localStorage.getItem("token")}` },
      }).then(r => r.json());

      const result = await api.ai.extractNodes({
        markdown_content: docMarkdown.markdown || documents[0].title || "",
        goal: pathway?.goal,
        existing_knowledge: pathway?.existing_knowledge,
        output_target: pathway?.output_target,
        apiKey: ai.apiKey, endpoint: ai.apiEndpoint, model: ai.modelName,
      });
      setExtractResult(result);

      for (const node of result.nodes || []) {
        await api.cards.create({
          title: node.title || node.text?.slice(0, 40),
          content: node.text,
          card_type: node.node_type === "viewpoint" ? "claim" : node.node_type,
          source_document_id: documents[0]?.id,
          source_document_title: documents[0]?.title,
          page_number: node.source_page,
          ai_generated_text: node.text,
          confidence_score: node.confidence,
          source_citation: `p.${node.source_page || "?"}`,
        });
      }

      const updated = await api.cards.list();
      const newNodes = updated.cards.filter((c: any) =>
        documents.some((d: any) => d.id === c.source_document_id)
      );
      for (const rel of result.suggested_relations || []) {
        if (rel.source_index < newNodes.length && rel.target_index < newNodes.length) {
          await api.relations.create({
            pathway_id: id,
            source_card_id: newNodes[rel.source_index].id,
            target_card_id: newNodes[rel.target_index].id,
            relation_type: rel.relation_type,
            note: rel.reasoning || "",
          });
        }
      }

      await loadData();
    } catch (err: any) { setError(err.message); }
    finally { setExtracting(false); }
  };

  const handleSaveNode = async (nodeId: string) => {
    await api.cards.update(nodeId, {
      user_summary: editSummary,
      card_type: editType,
      title: editTitle,
      user_confirmed: 1,
      calibration_status: "confirmed",
    });
    setEditingNode(null);
    await loadData();
  };

  const handleAddRelation = async () => {
    if (!id || !relSource || !relTarget) return;
    await api.relations.create({
      pathway_id: id, source_card_id: relSource,
      target_card_id: relTarget, relation_type: relType,
    });
    setShowAddRelation(false);
    setRelSource(""); setRelTarget(""); setRelType("support");
    await loadData();
  };

  const handleShare = async () => {
    if (!id) return;
    setSharing(true);
    try {
      const result = await api.pathways.share(id);
      setShareUrl(result.shared ? result.share_url : null);
      if (result.shared && result.share_url) {
        const fullUrl = window.location.origin + "/api" + result.share_url;
        await navigator.clipboard.writeText(fullUrl);
        alert("分享链接已复制到剪贴板！");
      }
    } catch (e: any) { alert("分享失败: " + e.message); }
    finally { setSharing(false); }
  };

  const handleExport = async (type: string) => {
    if (!id) return;
    setExporting(true);
    try {
      const { export: exp } = await api.exports.create(id, type);
      window.open(`/api/exports/${exp.id}/download`, "_blank");
    } catch (err: any) { setError(err.message); }
    finally { setExporting(false); }
  };

  if (loading) return <div className="p-8 text-sm text-[var(--text-tertiary)]">加载中...</div>;
  if (!pathway) return <div className="p-8 text-sm text-red-500">路径不存在</div>;

  // List view (no id param)
  if (!id) {
    return <PathwayListView />;
  }

  return (
    <div className="p-8 max-w-6xl">
      <div className="flex items-center justify-between mb-6">
        <div>
          <button onClick={() => navigate("/pathways")} className="text-xs text-[var(--brand-violet)] hover:underline mb-1 block">← 路径列表</button>
          <h2 className="text-[28px] font-bold text-[var(--text-primary)] tracking-tight">{pathway.title}</h2>
          <span className={`text-[10px] px-1.5 py-0.5 rounded ${pathway.status === "draft" ? "bg-amber-100 text-amber-700" : "bg-green-100 text-green-700"}`}>
            {pathway.status === "draft" ? "草稿" : "已完成"}
          </span>
        </div>
        <div className="flex gap-2">
          <div className="flex bg-[var(--bg-page)] rounded-lg p-0.5 mr-1">
            {([
              ["edit", "编辑"],
              ["graph", "路径图"],
              ["evidence", "证据链"],
              ["matrix", "矩阵"],
              ["writing", "写作"],
            ] as const).map(([key, label]) => (
              <button key={key}
                onClick={() => setViewMode(key)}
                className={`px-2 py-1 rounded-md text-xs font-semibold transition-colors ${viewMode === key ? "bg-white text-[var(--brand-indigo)] shadow-sm" : "text-[var(--text-tertiary)]"}`}>
                {label}
              </button>
            ))}
          </div>
          <button onClick={() => handleExport("markdown_report")} disabled={exporting || nodes.length === 0}
            className="px-3 py-1.5 bg-[var(--brand-teal)] text-white text-xs font-semibold rounded hover:opacity-90 disabled:opacity-40">
            导出报告
          </button>
          <button onClick={() => handleExport("summary_outline")} disabled={exporting || nodes.length === 0}
            className="px-3 py-1.5 bg-[var(--text-secondary)] text-white text-xs font-semibold rounded hover:opacity-90 disabled:opacity-40">
            导出提纲
          </button>
          <button onClick={handleShare} disabled={sharing}
            className={`px-3 py-1.5 text-xs font-semibold rounded ${shareUrl ? "bg-green-100 text-green-700" : "bg-[var(--teal-100)] text-[var(--brand-teal)] hover:opacity-90"} disabled:opacity-40`}>
            {sharing ? "..." : shareUrl ? "✓ 已分享" : "分享"}
          </button>
        </div>
      </div>

      {error && <p className="text-sm text-red-500 mb-4">{error}</p>}

      <div className="grid grid-cols-3 gap-4 mb-6">
        {[ { label: "学习目标", value: pathway.goal }, { label: "已有知识", value: pathway.existing_knowledge }, { label: "预期输出", value: pathway.output_target } ].map((item) => (
          <div key={item.label} className="bg-[var(--primary-100)] p-4 rounded-lg">
            <p className="text-[10px] font-semibold text-[var(--text-secondary)] mb-1">{item.label}</p>
            <p className="text-xs text-[var(--text-secondary)]">{item.value || "未填写"}</p>
          </div>
        ))}
      </div>

      {viewMode === "graph" ? (
        <div className="space-y-4">
          <PathwayGraph nodes={nodes} relations={relations} onNodeClick={(nodeId) => {
            const node = nodes.find((n) => n.id === nodeId);
            if (node) {
              setEditingNode(node.id);
              setEditTitle(node.title);
              setEditType(node.card_type);
              setEditSummary(node.user_summary || "");
              setViewMode("edit");
            }
          }} />
        </div>
      ) : viewMode === "evidence" ? (
        <div className="space-y-4">
          <EvidenceChain nodes={nodes} relations={relations} />
        </div>
      ) : viewMode === "matrix" ? (
        <div className="space-y-4">
          <ComparisonMatrix nodes={nodes} relations={relations} />
        </div>
      ) : viewMode === "writing" ? (
        <div className="max-w-2xl space-y-6">
          <WritingChecklist
            pathwayId={id!}
            nodes={nodes}
            documents={documents}
            onNavigateToNode={(nodeId) => {
              const node = nodes.find((n) => n.id === nodeId);
              if (node) {
                setEditingNode(node.id);
                setEditTitle(node.title);
                setEditType(node.card_type);
                setEditSummary(node.user_summary || "");
                setViewMode("edit");
              }
            }}
          />
          <SourceQuality
            pathwayId={id!}
            onNavigateToSource={(sourceId) => {
              navigate(`/reader/${sourceId}`);
            }}
          />
        </div>
      ) : (
      <div className="grid grid-cols-3 gap-6">
        {/* Left: Documents */}
        <div className="space-y-4">
          <div className="bg-white p-4 rounded-lg border border-[var(--border-default)]">
            <h3 className="text-sm font-semibold text-[var(--text-primary)] mb-3">📄 学习资料</h3>
            {documents.length === 0 ? (
              <p className="text-xs text-[var(--text-tertiary)] mb-3">还没有添加资料</p>
            ) : (
              <div className="space-y-1 mb-3">
                {documents.map((d: any) => (
                  <div key={d.id} className="text-xs p-2 bg-[var(--bg-page)] rounded flex items-center justify-between">
                    <span className="truncate">{d.title}</span>
                    <button onClick={() => navigate(`/reader/${d.id}`)} className="text-[10px] text-[var(--brand-violet)] hover:underline ml-1 flex-shrink-0">查看</button>
                  </div>
                ))}
              </div>
            )}
            <label className={`block w-full py-1.5 text-center text-xs font-semibold rounded cursor-pointer ${uploading ? "bg-gray-200 text-gray-400" : "bg-[var(--brand-indigo)] text-white hover:opacity-90"}`}>
              {uploading ? "上传中..." : "上传资料"}
              <input type="file" accept=".pdf,.txt,.md,.docx,.pptx" onChange={handleUpload} className="hidden" disabled={uploading} />
            </label>
          </div>
          <button onClick={handleExtract} disabled={extracting || documents.length === 0}
            className="w-full py-2 bg-[var(--brand-violet)] text-white text-xs font-semibold rounded hover:opacity-90 disabled:opacity-40">
            {extracting ? "AI 提取中..." : "🤖 AI 提取知识节点"}
          </button>
          {extractResult && (
            <p className="text-[10px] text-[var(--text-tertiary)]">
              提取了 {extractResult.nodes?.length || 0} 个节点和 {extractResult.suggested_relations?.length || 0} 个关系
              {extractResult.mode === "demo" ? " (Demo)" : ""}
            </p>
          )}
        </div>

        {/* Center: Nodes */}
        <div className="space-y-2">
          <h3 className="text-sm font-semibold text-[var(--text-primary)]">🧩 知识节点 ({nodes.length})</h3>
          {nodes.length === 0 ? (
            <p className="text-xs text-[var(--text-tertiary)]">上传资料后点击「AI 提取知识节点」</p>
          ) : (
            nodes.map((node) => (
              <div key={node.id} className="bg-white p-3 rounded-lg border border-[var(--border-default)] text-xs">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--primary-100)] text-[var(--brand-indigo)] font-semibold">{node.card_type}</span>
                  <span className="text-[10px] text-[var(--text-tertiary)]">
                    {node.user_confirmed ? "✓ 已确认" : "待确认"} · 置信度 {Math.round((node.confidence_score || 0.8) * 100)}%
                  </span>
                </div>
                {editingNode === node.id ? (
                  <div className="space-y-1.5">
                    <input value={editTitle} onChange={(e) => setEditTitle(e.target.value)} className="w-full px-2 py-1 border rounded text-xs" />
                    <select value={editType} onChange={(e) => setEditType(e.target.value)} className="w-full px-2 py-1 border rounded text-xs">
                      {["concept","claim","evidence","question","summary","reflection","note"].map(t => (<option key={t} value={t}>{t}</option>))}
                    </select>
                    <textarea value={editSummary} onChange={(e) => setEditSummary(e.target.value)} placeholder="用你自己的话转述..." className="w-full px-2 py-1 border rounded text-xs h-14 resize-none" />
                    <div className="flex gap-1">
                      <button onClick={() => handleSaveNode(node.id)} className="flex-1 py-1 bg-[var(--brand-indigo)] text-white rounded text-xs">保存</button>
                      <button onClick={() => setEditingNode(null)} className="px-2 py-1 text-xs text-[var(--text-tertiary)]">取消</button>
                    </div>
                  </div>
                ) : (
                  <>
                    <p className="font-medium text-[var(--text-primary)]">{node.title}</p>
                    <p className="text-[var(--text-secondary)] mt-0.5 line-clamp-2">{node.ai_generated_text || node.content}</p>
                    {node.user_summary && <p className="text-[var(--brand-violet)] mt-1 italic">💬 {node.user_summary}</p>}
                    <div className="flex items-center justify-between mt-2">
                      <span className="text-[10px] text-[var(--text-tertiary)]">{node.source_citation || `p.${node.page_number || "?"}`}</span>
                      <button onClick={() => { setEditingNode(node.id); setEditTitle(node.title); setEditType(node.card_type); setEditSummary(node.user_summary || ""); }}
                        className="text-[10px] text-[var(--brand-teal)] hover:underline">编辑转述</button>
                    </div>
                  </>
                )}
              </div>
            ))
          )}
        </div>

        {/* Right: Relations */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-[var(--text-primary)]">🔗 知识关系 ({relations.length})</h3>
            <button onClick={() => setShowAddRelation(!showAddRelation)} className="text-[10px] text-[var(--brand-teal)] hover:underline">+ 添加</button>
          </div>
          {showAddRelation && (
            <div className="bg-white p-3 rounded-lg border border-[var(--brand-teal)] text-xs space-y-1.5">
              <select value={relSource} onChange={(e) => setRelSource(e.target.value)} className="w-full px-2 py-1 border rounded text-xs">
                <option value="">源节点</option>
                {nodes.map((n) => <option key={n.id} value={n.id}>{n.title}</option>)}
              </select>
              <select value={relType} onChange={(e) => setRelType(e.target.value)} className="w-full px-2 py-1 border rounded text-xs">
                {Object.entries(RELATION_LABELS).map(([k, v]) => (<option key={k} value={k}>{v} ({k})</option>))}
              </select>
              <select value={relTarget} onChange={(e) => setRelTarget(e.target.value)} className="w-full px-2 py-1 border rounded text-xs">
                <option value="">目标节点</option>
                {nodes.map((n) => <option key={n.id} value={n.id}>{n.title}</option>)}
              </select>
              <button onClick={handleAddRelation} disabled={!relSource || !relTarget}
                className="w-full py-1 bg-[var(--brand-teal)] text-white rounded text-xs disabled:opacity-40">创建关系</button>
            </div>
          )}
          {relations.length === 0 ? (
            <p className="text-xs text-[var(--text-tertiary)]">AI 提取后会自动建议关系，也可以手动添加</p>
          ) : (
            relations.map((rel) => {
              const src = nodes.find((n) => n.id === rel.source_card_id);
              const tgt = nodes.find((n) => n.id === rel.target_card_id);
              return (
                <div key={rel.id} className="bg-white p-2 rounded-lg border border-[var(--border-default)] text-xs flex items-center justify-between">
                  <div className="flex items-center gap-1.5 flex-1 min-w-0">
                    <span className="font-medium truncate">{src?.title || "?"}</span>
                    <span className="text-[10px] px-1 py-0.5 bg-[var(--teal-100)] rounded text-[var(--brand-teal)] flex-shrink-0">{RELATION_LABELS[rel.relation_type] || rel.relation_type}</span>
                    <span className="font-medium truncate">{tgt?.title || "?"}</span>
                  </div>
                  <button onClick={async () => { await api.relations.delete(rel.id); await loadData(); }}
                    className="text-[10px] text-[var(--text-tertiary)] hover:text-red-500 ml-1 flex-shrink-0">✕</button>
                </div>
              );
            })
          )}
        </div>
      </div>
      )}
      <RightInspector
        score={nodes.length > 0 ? Math.min(100, Math.round((nodes.filter((n: any) => n.user_confirmed).length / Math.max(1, nodes.length)) * 85 + 15)) : undefined}
        scoreLabel="节点校准率"
        metrics={[
          { label: "资料完整性", value: documents.length > 0 ? 80 : 0 },
          { label: "节点确认率", value: nodes.length > 0 ? Math.round((nodes.filter((n: any) => n.user_confirmed).length / nodes.length) * 100) : 0 },
          { label: "关系密度", value: nodes.length > 0 ? Math.min(100, Math.round((relations.length / nodes.length) * 100)) : 0 },
        ]}
        aiSuggestions={documents.length === 0 ? ["上传资料以开始构建知识路径", "添加至少 2 份文档效果最佳"] : nodes.length === 0 ? ["点击「AI 提取知识节点」开始分析"] : nodes.filter((n: any) => !n.user_confirmed).length > 0 ? [`还有 ${nodes.filter((n: any) => !n.user_confirmed).length} 个节点待确认`, "建议用自己的话转述每个概念"] : ["所有节点已确认，干得好！", "可以尝试建立更多节点间关系"]}
        exportActions={[
          { label: "导出 Markdown 报告", onClick: () => handleExport("markdown_report"), primary: true },
          { label: "导出综述提纲", onClick: () => handleExport("summary_outline") },
        ]}
      />
    </div>
  );
}

/** Pathway list view (when no id in URL) */
function PathwayListView() {
  const navigate = useNavigate();
  const [pathways, setPathways] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.pathways.list().then(({ pathways }) => { setPathways(pathways); setLoading(false); });
  }, []);

  if (loading) return <div className="p-8 text-sm text-[var(--text-tertiary)]">加载中...</div>;

  return (
    <div className="p-8 max-w-5xl">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-[28px] font-bold text-[var(--text-primary)] tracking-tight mb-1">专题路径</h2>
          <p className="text-xs text-[var(--text-tertiary)]">Knowledge Pathway — 围绕主题的结构化知识脉络</p>
        </div>
        <button onClick={() => navigate("/init")}
          className="px-4 py-2 bg-[var(--brand-indigo)] text-white rounded-lg text-sm font-semibold hover:opacity-90">
          + 新建路径
        </button>
      </div>
      {pathways.length === 0 ? (
        <div className="bg-white p-10 rounded-xl border border-dashed border-[var(--border-default)] text-center">
          <p className="text-sm text-[var(--text-secondary)]">还没有知识路径。</p>
          <p className="text-xs text-[var(--text-tertiary)] mt-2">创建你的第一条学习路径，上传资料并让 AI 帮你提取知识节点。</p>
        </div>
      ) : (
        <div className="space-y-2">
          {pathways.map((p: any) => (
            <div key={p.id} className="flex items-center gap-4 bg-white p-4 rounded-lg border border-[var(--border-default)]">
              <span className="text-lg">🔗</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-[var(--text-primary)] truncate">{p.title}</p>
                <p className="text-[10px] text-[var(--text-tertiary)]">
                  {p.status === "draft" ? "草稿" : "已完成"} · {p.goal?.slice(0, 40) || "未设定目标"}
                </p>
              </div>
              <button onClick={() => navigate(`/pathway/${p.id}`)} className="text-xs text-[var(--brand-indigo)] hover:underline">打开</button>
              <button onClick={async () => { if (confirm("删除此路径？")) { await api.pathways.delete(p.id); setPathways(prev => prev.filter(x => x.id !== p.id)); } }}
                className="text-xs text-red-400 hover:text-red-600">删除</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
