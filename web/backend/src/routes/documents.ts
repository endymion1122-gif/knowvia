import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import path from "path";
import fs from "fs";
import multer from "multer";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";
import { convertToMarkdown, isConvertible } from "../utils/document-converter.js";

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

  // Async: convert to Markdown for AI processing
  const converterMessage = isConvertible(file.originalname)
    ? "文档已上传，正在后台转换为 Markdown..."
    : null;
  setImmediate(async () => {
    if (isConvertible(file.originalname)) {
      const result = await convertToMarkdown(file.path);
      if (result.markdown && !result.error) {
        db.prepare("UPDATE documents SET markdown_content = ? WHERE id = ?")
          .run(result.markdown.slice(0, 1_000_000), id); // cap at ~1MB
      }
    }
  });

  const doc = db.prepare("SELECT * FROM documents WHERE id = ?").get(id);
  res.json({ document: doc, converterMessage });
});

// POST /api/documents/import-url — fetch a webpage and store as document
router.post("/import-url", async (req: AuthRequest, res: Response) => {
  const { url } = req.body;
  if (!url?.trim()) { res.status(400).json({ error: "请提供网页 URL" }); return; }

  try {
    const response = await fetch(url.trim(), {
      headers: { "User-Agent": "Knowvia/1.0" },
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) { res.status(502).json({ error: `无法访问该网页: HTTP ${response.status}` }); return; }
    const html = await response.text();

    const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
    const title = titleMatch?.[1]?.trim() || new URL(url).hostname;
    const body = html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "")
      .replace(/<[^>]+>/g, "\n")
      .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"').replace(/&#x27;/g, "'")
      .replace(/\n{3,}/g, "\n\n").trim().slice(0, 50000);

    const db = getDb();
    const id = uuid();
    const filePath = path.join(UPLOAD_DIR, `${id}-import.txt`);
    fs.writeFileSync(filePath, `# ${title}\n\n来源: ${url}\n\n${body}`);

    db.prepare("INSERT INTO documents (id, user_id, title, file_type, file_path, source_url, markdown_content) VALUES (?,?,?,?,?,?,?)")
      .run(id, req.userId, title, "txt", filePath, url.trim(), `# ${title}\n\n${body.slice(0, 10000)}`);

    const doc = db.prepare("SELECT * FROM documents WHERE id = ?").get(id);
    res.json({ document: doc });
  } catch (e: any) {
    res.status(502).json({ error: `网页导入失败: ${e.message}` });
  }
});

// GET /api/documents (with pagination)
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { page, limit } = req.query;
  const pageNum = Math.max(1, parseInt(page as string) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(limit as string) || 50));
  const total = (db.prepare("SELECT COUNT(*) as c FROM documents WHERE user_id = ?").get(req.userId) as any).c;
  const docs = db.prepare("SELECT * FROM documents WHERE user_id = ? ORDER BY updated_at DESC LIMIT ? OFFSET ?")
    .all(req.userId, pageSize, (pageNum - 1) * pageSize);
  res.json({
    documents: docs,
    pagination: { page: pageNum, limit: pageSize, total, totalPages: Math.ceil(total / pageSize) },
  });
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

// GET /api/documents/:id/markdown — get converted markdown for AI processing
router.get("/:id/markdown", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const doc = db.prepare("SELECT id, markdown_content FROM documents WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!doc) { res.status(404).json({ error: "资料不存在" }); return; }
  res.json({ markdown: doc.markdown_content || "" });
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
