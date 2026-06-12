import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

// POST /api/evidences — add evidence to a node
router.post("/", (req: AuthRequest, res: Response) => {
  const { node_id, evidence_text, source_location, evidence_strength, evidence_type } = req.body;
  if (!node_id || !evidence_text?.trim()) {
    res.status(400).json({ error: "node_id 和 evidence_text 为必填项" });
    return;
  }

  const db = getDb();
  const id = uuid();
  db.prepare(`
    INSERT INTO evidences (id, node_id, evidence_text, source_location, evidence_strength, evidence_type)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(
    id, node_id, evidence_text.trim(),
    source_location || "", evidence_strength || "medium", evidence_type || "citation",
  );
  const ev = db.prepare("SELECT * FROM evidences WHERE id = ?").get(id);
  res.status(201).json({ evidence: ev });
});

// GET /api/evidences?node_id=xxx
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { node_id } = req.query;
  if (!node_id) { res.status(400).json({ error: "请提供 node_id" }); return; }
  const rows = db.prepare("SELECT * FROM evidences WHERE node_id = ? ORDER BY created_at DESC").all(node_id);
  res.json({ evidences: rows });
});

// PATCH /api/evidences/:id
router.patch("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { evidence_text, source_location, evidence_strength, evidence_type } = req.body;
  db.prepare(`
    UPDATE evidences SET
      evidence_text = COALESCE(?, evidence_text),
      source_location = COALESCE(?, source_location),
      evidence_strength = COALESCE(?, evidence_strength),
      evidence_type = COALESCE(?, evidence_type)
    WHERE id = ?
  `).run(evidence_text ?? null, source_location ?? null, evidence_strength ?? null, evidence_type ?? null, req.params.id);
  const updated = db.prepare("SELECT * FROM evidences WHERE id = ?").get(req.params.id);
  res.json({ evidence: updated });
});

// DELETE /api/evidences/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  db.prepare("DELETE FROM evidences WHERE id = ?").run(req.params.id);
  res.json({ success: true });
});

export default router;
