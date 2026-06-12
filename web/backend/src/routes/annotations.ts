import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

// POST /api/annotations
router.post("/", (req: AuthRequest, res: Response) => {
  const { document_id, selected_text, note, page_number } = req.body;
  if (!document_id || !selected_text?.trim()) {
    res.status(400).json({ error: "请选择文本" });
    return;
  }

  const db = getDb();
  const id = uuid();
  db.prepare(`
    INSERT INTO annotations (id, document_id, user_id, selected_text, note, page_number)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, document_id, req.userId, selected_text.trim(), note || "", page_number || null);

  const annotation = db.prepare("SELECT * FROM annotations WHERE id = ?").get(id);
  res.json({ annotation });
});

// GET /api/annotations?document_id=xxx
router.get("/", (req: AuthRequest, res: Response) => {
  const { document_id } = req.query;
  const db = getDb();
  let annotations;
  if (document_id) {
    annotations = db.prepare("SELECT * FROM annotations WHERE document_id = ? AND user_id = ? ORDER BY created_at DESC").all(document_id, req.userId);
  } else {
    annotations = db.prepare("SELECT * FROM annotations WHERE user_id = ? ORDER BY created_at DESC").all(req.userId);
  }
  res.json({ annotations });
});

// DELETE /api/annotations/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  db.prepare("DELETE FROM annotations WHERE id = ? AND user_id = ?").run(req.params.id, req.userId);
  res.json({ success: true });
});

export default router;
