import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

// POST /api/exports — generate an export for a pathway
router.post("/", (req: AuthRequest, res: Response) => {
  const { pathway_id, export_type } = req.body;
  if (!pathway_id || !export_type) {
    res.status(400).json({ error: "pathway_id 和 export_type 为必填项" });
    return;
  }

  const db = getDb();
  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(pathway_id, req.userId) as any;
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }

  const nodes = db.prepare(
    "SELECT * FROM knowledge_cards WHERE id IN (SELECT card_id FROM pathway_cards WHERE pathway_id = ?)"
  ).all(pathway_id) as any[];

  const relations = db.prepare(
    "SELECT * FROM knowledge_relations WHERE pathway_id = ?"
  ).all(pathway_id) as any[];

  let content = "";
  if (export_type === "markdown_report") {
    content = buildMarkdownReport(pathway, nodes, relations);
  } else if (export_type === "summary_outline") {
    content = buildSummaryOutline(pathway, nodes);
  } else {
    res.status(400).json({ error: "不支持的导出类型。支持：markdown_report, summary_outline" });
    return;
  }

  const id = uuid();
  db.prepare("INSERT INTO exports (id, pathway_id, user_id, export_type, export_content) VALUES (?,?,?,?,?)")
    .run(id, pathway_id, req.userId, export_type, content);
  const exp = db.prepare("SELECT * FROM exports WHERE id = ?").get(id);
  res.status(201).json({ export: { ...exp as any, download_url: `/api/exports/${id}/download` } });
});

// GET /api/exports — list exports for a pathway
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { pathway_id } = req.query;
  if (!pathway_id) { res.status(400).json({ error: "请提供 pathway_id" }); return; }
  const rows = db.prepare(
    "SELECT id, pathway_id, export_type, created_at FROM exports WHERE pathway_id = ? AND user_id = ? ORDER BY created_at DESC"
  ).all(pathway_id, req.userId);
  res.json({ exports: rows });
});

// GET /api/exports/:id/download — download export content
router.get("/:id/download", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const exp = db.prepare("SELECT * FROM exports WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!exp) { res.status(404).json({ error: "导出不存在" }); return; }
  res.setHeader("Content-Type", "text/markdown; charset=utf-8");
  res.setHeader("Content-Disposition", `attachment; filename="pathway-${exp.pathway_id}-${exp.export_type}.md"`);
  res.send(exp.export_content);
});

// DELETE /api/exports/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  db.prepare("DELETE FROM exports WHERE id = ? AND user_id = ?").run(req.params.id, req.userId);
  res.json({ success: true });
});

function buildMarkdownReport(pathway: any, nodes: any[], relations: any[]): string {
  let md = `# ${pathway.title}\n\n`;
  md += `## 学习目标\n${pathway.goal || "未指定"}\n\n`;
  md += `## 已有知识\n${pathway.existing_knowledge || "未指定"}\n\n`;
  md += `## 预期输出\n${pathway.output_target || "未指定"}\n\n`;
  md += `---\n\n## 知识节点\n\n`;
  for (const n of nodes) {
    md += `### ${n.title} (${n.card_type})\n`;
    md += `- AI 生成：${n.ai_generated_text || n.content}\n`;
    if (n.user_summary) md += `- 我的理解：${n.user_summary}\n`;
    if (n.source_page) md += `- 来源页码：${n.source_page}\n`;
    md += `\n`;
  }
  if (relations.length > 0) {
    md += `---\n\n## 知识关系\n\n`;
    for (const r of relations) {
      const src = nodes.find((n) => n.id === r.source_card_id);
      const tgt = nodes.find((n) => n.id === r.target_card_id);
      if (src && tgt) {
        md += `- **${src.title}** → ${r.relation_type} → **${tgt.title}**\n`;
      }
    }
  }
  md += `\n---\n*由知径 Knowvia 生成 · ${new Date().toLocaleDateString("zh-CN")}*\n`;
  return md;
}

function buildSummaryOutline(pathway: any, nodes: any[]): string {
  let md = `# ${pathway.title} — 综述提纲\n\n`;
  md += `## 研究问题\n${pathway.goal || "待定"}\n\n`;
  md += `## 核心概念\n`;
  const concepts = nodes.filter((n) => n.card_type === "concept");
  for (const c of concepts) md += `- ${c.title}：${c.user_summary || c.content}\n`;
  md += `\n## 主要观点\n`;
  const claims = nodes.filter((n) => n.card_type === "claim" || n.card_type === "argument");
  for (const c of claims) md += `- ${c.title}：${c.user_summary || c.content}\n`;
  md += `\n## 关键证据\n`;
  const evidences = nodes.filter((n) => n.card_type === "evidence");
  for (const e of evidences) md += `- ${e.title}（来源：p.${e.source_page || "?"}）\n`;
  md += `\n## 待研究问题\n`;
  const questions = nodes.filter((n) => n.card_type === "question");
  for (const q of questions) md += `- ${q.title}\n`;
  return md;
}

export default router;
