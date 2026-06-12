import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

// POST /api/pathways — create a new knowledge pathway with goal priming
router.post("/", (req: AuthRequest, res: Response) => {
  const { title, description, goal, existing_knowledge, output_target, tags } = req.body;
  if (!title?.trim()) {
    res.status(400).json({ error: "路径标题为必填项" });
    return;
  }

  const db = getDb();
  const id = uuid();
  db.prepare(`
    INSERT INTO knowledge_pathways (id, user_id, title, overview, goal, existing_knowledge, output_target, tags, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'draft')
  `).run(
    id, req.userId, title.trim(),
    description || "", goal || "", existing_knowledge || "",
    output_target || "", tags ? JSON.stringify(tags) : "[]",
  );

  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ?").get(id);
  res.status(201).json({ pathway: formatPathway(pathway) });
});

// GET /api/pathways — list user's pathways
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { status } = req.query;
  let sql = "SELECT * FROM knowledge_pathways WHERE user_id = ?";
  const params: any[] = [req.userId];
  if (status) { sql += " AND status = ?"; params.push(status); }
  sql += " ORDER BY updated_at DESC";
  const rows = db.prepare(sql).all(...params);
  res.json({ pathways: (rows as any[]).map(formatPathway) });
});

// GET /api/pathways/:id — get pathway detail
router.get("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }
  res.json({ pathway: formatPathway(pathway) });
});

// PATCH /api/pathways/:id — update pathway
router.patch("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const existing = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!existing) { res.status(404).json({ error: "路径不存在" }); return; }

  const { title, description, goal, existing_knowledge, output_target, status: st, tags, source_markdown } = req.body;
  db.prepare(`
    UPDATE knowledge_pathways SET
      title = COALESCE(?, title), overview = COALESCE(?, overview),
      goal = COALESCE(?, goal), existing_knowledge = COALESCE(?, existing_knowledge),
      output_target = COALESCE(?, output_target), status = COALESCE(?, status),
      tags = COALESCE(?, tags), source_markdown = COALESCE(?, source_markdown),
      updated_at = datetime('now')
    WHERE id = ?
  `).run(
    title ?? null, description ?? null, goal ?? null,
    existing_knowledge ?? null, output_target ?? null, st ?? null,
    tags ? JSON.stringify(tags) : null, source_markdown ?? null,
    req.params.id,
  );
  const updated = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ?").get(req.params.id);
  res.json({ pathway: formatPathway(updated) });
});

// DELETE /api/pathways/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  db.prepare("DELETE FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .run(req.params.id, req.userId);
  res.json({ success: true });
});

// POST /api/pathways/:id/link-document — link a document to a pathway
router.post("/:id/link-document", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { document_id } = req.body;
  if (!document_id) { res.status(400).json({ error: "请提供 document_id" }); return; }
  const pathway = db.prepare("SELECT id FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId);
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }
  db.prepare("INSERT OR IGNORE INTO pathway_documents (pathway_id, document_id) VALUES (?, ?)")
    .run(req.params.id, document_id);
  // Copy markdown if available
  const doc = db.prepare("SELECT markdown_content FROM documents WHERE id = ?").get(document_id) as any;
  if (doc?.markdown_content) {
    db.prepare("UPDATE knowledge_pathways SET source_markdown = COALESCE(NULLIF(source_markdown,''), ?) || ? WHERE id = ?")
      .run(doc.markdown_content, doc.markdown_content, req.params.id);
  }
  res.json({ success: true });
});

// GET /api/pathways/:id/documents — list documents in a pathway
router.get("/:id/documents", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const docs = db.prepare(`
    SELECT d.* FROM documents d
    JOIN pathway_documents pd ON pd.document_id = d.id
    WHERE pd.pathway_id = ? AND d.user_id = ?
  `).all(req.params.id, req.userId);
  res.json({ documents: docs });
});

function formatPathway(row: any) {
  if (!row) return null;
  return {
    ...row,
    tags: safeJsonParse(row.tags, []),
  };
}

function safeJsonParse(s: string, fallback: any) {
  try { return JSON.parse(s); } catch { return fallback; }
}

export default router;
