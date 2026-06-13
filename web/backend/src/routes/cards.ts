import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

// POST /api/cards — create a knowledge card
router.post("/", (req: AuthRequest, res: Response) => {
  const {
    title, content, card_type, tags,
    source_document_id, source_document_title, page_number,
    calibration_note,
  } = req.body;

  if (!title?.trim() || !content?.trim()) {
    res.status(400).json({ error: "标题和内容为必填项" });
    return;
  }

  const db = getDb();
  const id = uuid();
  db.prepare(`
    INSERT INTO knowledge_cards (id, user_id, title, content, card_type, tags,
      source_document_id, source_document_title, page_number,
      calibration_status, calibration_note)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pendingReview', ?)
  `).run(
    id, req.userId,
    title.trim(), content.trim(),
    card_type || "note",
    tags ? JSON.stringify(tags) : "[]",
    source_document_id || null,
    source_document_title || null,
    page_number || null,
    calibration_note || "",
  );

  const card = db.prepare("SELECT * FROM knowledge_cards WHERE id = ?").get(id);
  res.json({ card });
});

// GET /api/cards — list cards, optionally filter by document
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { document_id, card_type, calibration_status } = req.query;

  let sql = "SELECT * FROM knowledge_cards WHERE user_id = ?";
  const params: any[] = [req.userId];

  if (document_id) { sql += " AND source_document_id = ?"; params.push(document_id); }
  if (card_type) { sql += " AND card_type = ?"; params.push(card_type); }
  if (calibration_status) { sql += " AND calibration_status = ?"; params.push(calibration_status); }

  sql += " ORDER BY created_at DESC";
  const cards = db.prepare(sql).all(...params);
  // Parse tags JSON
  const parsed = (cards as any[]).map((c: any) => ({
    ...c,
    tags: safeJsonParse(c.tags, []),
    is_highlighted: !!c.is_highlighted,
    is_understood: !!c.is_understood,
  }));
  res.json({ cards: parsed });
});

// PATCH /api/cards/:id — update card (paraphrase, type, status, etc.)
router.patch("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const card = db.prepare("SELECT * FROM knowledge_cards WHERE id = ? AND user_id = ?").get(req.params.id, req.userId) as any;
  if (!card) { res.status(404).json({ error: "卡片不存在" }); return; }

  const {
    title, content, card_type, tags,
    calibration_status, calibration_note,
    is_highlighted, is_understood,
    source_document_title, page_number,
  } = req.body;

  db.prepare(`
    UPDATE knowledge_cards SET
      title = COALESCE(?, title),
      content = COALESCE(?, content),
      card_type = COALESCE(?, card_type),
      tags = COALESCE(?, tags),
      calibration_status = COALESCE(?, calibration_status),
      calibration_note = COALESCE(?, calibration_note),
      is_highlighted = COALESCE(?, is_highlighted),
      is_understood = COALESCE(?, is_understood),
      source_document_title = COALESCE(?, source_document_title),
      page_number = COALESCE(?, page_number),
      updated_at = datetime('now')
    WHERE id = ?
  `).run(
    title ?? null,
    content ?? null,
    card_type ?? null,
    tags ? JSON.stringify(tags) : null,
    calibration_status ?? null,
    calibration_note ?? null,
    is_highlighted != null ? (is_highlighted ? 1 : 0) : null,
    is_understood != null ? (is_understood ? 1 : 0) : null,
    source_document_title ?? null,
    page_number ?? null,
    req.params.id,
  );

  const updated = db.prepare("SELECT * FROM knowledge_cards WHERE id = ?").get(req.params.id);
  res.json({ card: updated });
});

// DELETE /api/cards/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  db.prepare("DELETE FROM knowledge_cards WHERE id = ? AND user_id = ?").run(req.params.id, req.userId);
  res.json({ success: true });
});

// POST /api/cards/batch-delete — delete multiple cards at once
router.post("/batch-delete", (req: AuthRequest, res: Response) => {
  const { ids } = req.body;
  if (!Array.isArray(ids) || ids.length === 0) {
    res.status(400).json({ error: "请提供要删除的卡片 ID 列表" });
    return;
  }
  const db = getDb();
  const placeholders = ids.map(() => "?").join(",");
  db.prepare(`DELETE FROM knowledge_cards WHERE id IN (${placeholders}) AND user_id = ?`)
    .run(...ids, req.userId);
  res.json({ success: true, deleted: ids.length });
});

// POST /api/cards/batch-export — export selected cards as markdown
router.post("/batch-export", (req: AuthRequest, res: Response) => {
  const { ids } = req.body;
  if (!Array.isArray(ids) || ids.length === 0) {
    res.status(400).json({ error: "请提供要导出的卡片 ID 列表" });
    return;
  }
  const db = getDb();
  const placeholders = ids.map(() => "?").join(",");
  const cards = db.prepare(`SELECT * FROM knowledge_cards WHERE id IN (${placeholders}) AND user_id = ?`)
    .all(...ids, req.userId) as any[];

  let md = "# 批量导出知识卡片\n\n";
  md += `导出时间：${new Date().toLocaleString("zh-CN")}\n\n---\n\n`;
  for (const c of cards) {
    md += `## ${c.title}\n`;
    md += `- 类型：${c.card_type}\n`;
    md += `- AI 生成：${c.ai_generated_text || c.content}\n`;
    if (c.user_summary) md += `- 我的理解：${c.user_summary}\n`;
    if (c.source_document_title) md += `- 来源：${c.source_document_title} p.${c.page_number || "?"}\n`;
    md += "\n";
  }
  res.json({ markdown: md, count: cards.length });
});

function safeJsonParse(s: string, fallback: any) {
  try { return JSON.parse(s); } catch { return fallback; }
}

export default router;
