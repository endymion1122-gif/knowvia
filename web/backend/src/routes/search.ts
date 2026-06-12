import { Router, Response } from "express";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

// Initialize FTS5 virtual table on first use
let ftsReady = false;
function ensureFTS(db: any) {
  if (ftsReady) return;
  // Create FTS5 virtual tables
  db.exec(`
    CREATE VIRTUAL TABLE IF NOT EXISTS docs_fts USING fts5(title, content, content=documents, content_rowid='rowid');
    CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts USING fts5(title, content, content=knowledge_cards, content_rowid='rowid');
    CREATE VIRTUAL TABLE IF NOT EXISTS annotations_fts USING fts5(selected_text, note, content=annotations, content_rowid='rowid');
  `);
  // Create triggers to keep FTS in sync
  db.exec(`
    CREATE TRIGGER IF NOT EXISTS docs_fts_insert AFTER INSERT ON documents BEGIN
      INSERT INTO docs_fts(rowid, title, content) VALUES (new.rowid, new.title, new.markdown_content);
    END;
    CREATE TRIGGER IF NOT EXISTS docs_fts_delete AFTER DELETE ON documents BEGIN
      INSERT INTO docs_fts(docs_fts, rowid, title, content) VALUES('delete', old.rowid, old.title, old.markdown_content);
    END;
    CREATE TRIGGER IF NOT EXISTS docs_fts_update AFTER UPDATE ON documents BEGIN
      INSERT INTO docs_fts(docs_fts, rowid, title, content) VALUES('delete', old.rowid, old.title, old.markdown_content);
      INSERT INTO docs_fts(rowid, title, content) VALUES (new.rowid, new.title, new.markdown_content);
    END;

    CREATE TRIGGER IF NOT EXISTS cards_fts_insert AFTER INSERT ON knowledge_cards BEGIN
      INSERT INTO cards_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
    END;
    CREATE TRIGGER IF NOT EXISTS cards_fts_delete AFTER DELETE ON knowledge_cards BEGIN
      INSERT INTO cards_fts(cards_fts, rowid, title, content) VALUES('delete', old.rowid, old.title, old.content);
    END;
    CREATE TRIGGER IF NOT EXISTS cards_fts_update AFTER UPDATE ON knowledge_cards BEGIN
      INSERT INTO cards_fts(cards_fts, rowid, title, content) VALUES('delete', old.rowid, old.title, old.content);
      INSERT INTO cards_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
    END;

    CREATE TRIGGER IF NOT EXISTS anns_fts_insert AFTER INSERT ON annotations BEGIN
      INSERT INTO annotations_fts(rowid, selected_text, note) VALUES (new.rowid, new.selected_text, new.note);
    END;
    CREATE TRIGGER IF NOT EXISTS anns_fts_delete AFTER DELETE ON annotations BEGIN
      INSERT INTO annotations_fts(annotations_fts, rowid, selected_text, note) VALUES('delete', old.rowid, old.selected_text, old.note);
    END;
    CREATE TRIGGER IF NOT EXISTS anns_fts_update AFTER UPDATE ON annotations BEGIN
      INSERT INTO annotations_fts(annotations_fts, rowid, selected_text, note) VALUES('delete', old.rowid, old.selected_text, old.note);
      INSERT INTO annotations_fts(rowid, selected_text, note) VALUES (new.rowid, new.selected_text, new.note);
    END;
  `);
  ftsReady = true;
}

// GET /api/search?q=keyword
router.get("/", (req: AuthRequest, res: Response) => {
  const { q } = req.query;
  if (!q || typeof q !== "string" || !q.trim()) {
    res.status(400).json({ error: "请提供搜索关键词" });
    return;
  }

  const db = getDb();
  ensureFTS(db);

  const query = q.trim();
  const results: any = { documents: [], cards: [], annotations: [] };

  try {
    // Search documents
    const docRows = db.prepare(`
      SELECT d.* FROM documents d
      JOIN docs_fts fts ON d.rowid = fts.rowid
      WHERE docs_fts MATCH ? AND d.user_id = ?
      ORDER BY rank LIMIT 20
    `).all(query, req.userId);
    results.documents = docRows;

    // Search cards
    const cardRows = db.prepare(`
      SELECT c.* FROM knowledge_cards c
      JOIN cards_fts fts ON c.rowid = fts.rowid
      WHERE cards_fts MATCH ? AND c.user_id = ?
      ORDER BY rank LIMIT 20
    `).all(query, req.userId);
    results.cards = cardRows;

    // Search annotations
    const annRows = db.prepare(`
      SELECT a.* FROM annotations a
      JOIN annotations_fts fts ON a.rowid = fts.rowid
      WHERE annotations_fts MATCH ? AND a.user_id = ?
      ORDER BY rank LIMIT 20
    `).all(query, req.userId);
    results.annotations = annRows;
  } catch (e: any) {
    // FTS may throw on special characters — return empty
    results.error = e.message;
  }

  res.json(results);
});

export default router;
