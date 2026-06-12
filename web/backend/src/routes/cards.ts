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

function safeJsonParse(s: string, fallback: any) {
  try { return JSON.parse(s); } catch { return fallback; }
}

export default router;
