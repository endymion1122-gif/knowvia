import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import path from "path";
import fs from "fs";
import multer from "multer";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

const UPLOAD_DIR = path.join(process.cwd(), "uploads");
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: UPLOAD_DIR,
  filename: (_req, file, cb) => {
    cb(null, `${uuid()}-${file.originalname}`);
  },
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

// POST /api/documents/upload
router.post("/upload", upload.single("file"), (req: AuthRequest, res: Response) => {
  const file = req.file;
  if (!file) {
    res.status(400).json({ error: "请选择文件" });
    return;
  }

  const ext = path.extname(file.originalname).toLowerCase();
  const allowed = [".pdf", ".txt", ".md", ".markdown"];
  if (!allowed.includes(ext)) {
    res.status(400).json({ error: "暂不支持该文件类型。支持 PDF、TXT 和 Markdown。" });
    return;
  }

  const fileType = ext === ".markdown" ? "md" : ext.slice(1);
  const id = uuid();
  const db = getDb();

  db.prepare(`
    INSERT INTO documents (id, user_id, title, file_type, file_path)
    VALUES (?, ?, ?, ?, ?)
  `).run(id, req.userId, file.originalname, fileType, file.path);

  const doc = db.prepare("SELECT * FROM documents WHERE id = ?").get(id);
  res.json({ document: doc });
});

// GET /api/documents
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const docs = db.prepare("SELECT * FROM documents WHERE user_id = ? ORDER BY updated_at DESC").all(req.userId);
  res.json({ documents: docs });
});

// PATCH /api/documents/:id
router.patch("/:id", (req: AuthRequest, res: Response) => {
  const { title, tags, reading_status, last_read_page, author, source_url, source_note } = req.body;
  const db = getDb();
  const doc = db.prepare("SELECT * FROM documents WHERE id = ? AND user_id = ?").get(req.params.id, req.userId) as any;
  if (!doc) {
    res.status(404).json({ error: "资料不存在" });
    return;
  }

  db.prepare(`
    UPDATE documents SET
      title = COALESCE(?, title),
      tags = COALESCE(?, tags),
      reading_status = COALESCE(?, reading_status),
      last_read_page = COALESCE(?, last_read_page),
      author = COALESCE(?, author),
      source_url = COALESCE(?, source_url),
      source_note = COALESCE(?, source_note),
      updated_at = datetime('now')
    WHERE id = ?
  `).run(
    title, tags ? JSON.stringify(tags) : null, reading_status,
    last_read_page, author, source_url, source_note, req.params.id
  );

  const updated = db.prepare("SELECT * FROM documents WHERE id = ?").get(req.params.id);
  res.json({ document: updated });
});

// DELETE /api/documents/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const doc = db.prepare("SELECT * FROM documents WHERE id = ? AND user_id = ?").get(req.params.id, req.userId);
  if (!doc) {
    res.status(404).json({ error: "资料不存在" });
    return;
  }
  // Delete file
  try { fs.unlinkSync((doc as any).file_path); } catch {}
  db.prepare("DELETE FROM documents WHERE id = ?").run(req.params.id);
  res.json({ success: true });
});

export default router;
