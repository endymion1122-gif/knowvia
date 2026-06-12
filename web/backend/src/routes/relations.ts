import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

const VALID_RELATION_TYPES = [
  "definition", "support", "oppose", "cause", "example",
  "include", "precondition", "application", "evolution", "contrast",
];

// POST /api/relations — create a relation
router.post("/", (req: AuthRequest, res: Response) => {
  const { pathway_id, source_card_id, target_card_id, relation_type, note } = req.body;
  if (!pathway_id || !source_card_id || !target_card_id || !relation_type) {
    res.status(400).json({ error: "pathway_id, source_card_id, target_card_id, relation_type 为必填项" });
    return;
  }
  if (!VALID_RELATION_TYPES.includes(relation_type)) {
    res.status(400).json({ error: `无效的关系类型。支持：${VALID_RELATION_TYPES.join(", ")}` });
    return;
  }

  const db = getDb();
  const id = uuid();
  db.prepare(`
    INSERT INTO knowledge_relations (id, pathway_id, source_card_id, target_card_id, relation_type, note, ai_suggested, user_confirmed)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(id, pathway_id, source_card_id, target_card_id, relation_type, note || "", 0, 1);

  const rel = db.prepare("SELECT * FROM knowledge_relations WHERE id = ?").get(id);
  res.status(201).json({ relation: rel });
});

// GET /api/relations?pathway_id=xxx
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { pathway_id } = req.query;
  if (!pathway_id) { res.status(400).json({ error: "请提供 pathway_id" }); return; }
  const rels = db.prepare(
    "SELECT * FROM knowledge_relations WHERE pathway_id = ? ORDER BY created_at ASC"
  ).all(pathway_id);
  res.json({ relations: rels });
});

// PATCH /api/relations/:id
router.patch("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { relation_type, note, user_confirmed } = req.body;
  if (relation_type && !VALID_RELATION_TYPES.includes(relation_type)) {
    res.status(400).json({ error: "无效的关系类型" }); return;
  }
  db.prepare(`
    UPDATE knowledge_relations SET
      relation_type = COALESCE(?, relation_type),
      note = COALESCE(?, note),
      user_confirmed = COALESCE(?, user_confirmed)
    WHERE id = ?
  `).run(relation_type ?? null, note ?? null, user_confirmed != null ? (user_confirmed ? 1 : 0) : null, req.params.id);
  const updated = db.prepare("SELECT * FROM knowledge_relations WHERE id = ?").get(req.params.id);
  res.json({ relation: updated });
});

// DELETE /api/relations/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  db.prepare("DELETE FROM knowledge_relations WHERE id = ?").run(req.params.id);
  res.json({ success: true });
});

export default router;
