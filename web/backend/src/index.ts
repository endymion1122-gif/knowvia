import express from "express";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import { authMiddleware } from "./middleware/auth.js";
import authRoutes from "./routes/auth.js";
import documentRoutes from "./routes/documents.js";
import aiRoutes from "./routes/ai.js";
import annotationRoutes from "./routes/annotations.js";
import cardRoutes from "./routes/cards.js";
import pathwayRoutes from "./routes/pathways.js";
import relationRoutes from "./routes/relations.js";
import evidenceRoutes from "./routes/evidences.js";
import exportRoutes from "./routes/exports.js";
import searchRoutes from "./routes/search.js";
import { getDb } from "./db/schema.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT || 3001;

const app = express();

app.use(cors({ origin: ["http://localhost:5173", "http://localhost:3000"], credentials: true }));
app.use(express.json({ limit: "10mb" }));

// Request logging
app.use((req, _res, next) => {
  const start = Date.now();
  _res.on("finish", () => {
    const ms = Date.now() - start;
    if (req.path.startsWith("/api")) {
      console.log(`${req.method} ${req.path} ${_res.statusCode} ${ms}ms`);
    }
  });
  next();
});

// Serve uploaded files
app.use("/uploads", express.static(path.join(__dirname, "..", "uploads")));

// Auth routes (no middleware)
app.use("/api/auth", authRoutes);

// Public share view (no auth required)
app.get("/api/share/:token", (req, res) => {
  const db = getDb();
  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE share_token = ? AND is_public = 1")
    .get(req.params.token) as any;
  if (!pathway) { res.status(404).json({ error: "分享链接无效或已关闭" }); return; }

  const cards = db.prepare(`
    SELECT c.* FROM knowledge_cards c
    JOIN pathway_cards pc ON pc.card_id = c.id
    WHERE pc.pathway_id = ?
  `).all(pathway.id);
  const relations = db.prepare("SELECT * FROM knowledge_relations WHERE pathway_id = ?").all(pathway.id);
  const docIds = db.prepare("SELECT document_id FROM pathway_documents WHERE pathway_id = ?")
    .all(pathway.id).map((r: any) => r.document_id);
  const documents = docIds.length > 0
    ? db.prepare(`SELECT id, title, author, publication_year, source_url FROM documents WHERE id IN (${docIds.map(() => "?").join(",")})`).all(...docIds)
    : [];

  res.json({
    pathway: { ...pathway, tags: safeJson(pathway.tags) },
    cards,
    relations,
    documents,
  });
});

function safeJson(s: string) { try { return JSON.parse(s); } catch { return []; } }

// Protected routes
app.use("/api/documents", authMiddleware, documentRoutes);

// AI routes (explain, extract-concepts)
app.use("/api/ai", authMiddleware, aiRoutes);

// Annotation routes (CRUD)
app.use("/api/annotations", authMiddleware, annotationRoutes);

// Knowledge card routes (CRUD)
app.use("/api/cards", authMiddleware, cardRoutes);

// Knowledge pathway routes (goal priming + CRUD)
app.use("/api/pathways", authMiddleware, pathwayRoutes);

// Relation routes (node connections)
app.use("/api/relations", authMiddleware, relationRoutes);

// Evidence routes (source tracing)
app.use("/api/evidences", authMiddleware, evidenceRoutes);

// Export routes (markdown report generation)
app.use("/api/exports", authMiddleware, exportRoutes);

// Search routes (FTS5 full-text search)
app.use("/api/search", authMiddleware, searchRoutes);

// Debug test route
app.post("/api/ping", (_req, res) => { res.json({ pong: true }); });

// Error handling middleware
app.use((err: any, _req: any, res: any, _next: any) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ error: "服务器内部错误" });
});

// Serve frontend in production
const frontendDist = path.join(__dirname, "..", "..", "frontend", "dist");
app.use(express.static(frontendDist));
app.get("/{*splat}", (_req, res) => {
  if (!_req.path.startsWith("/api")) {
    res.sendFile(path.join(frontendDist, "index.html"));
  }
});

getDb();
app.listen(PORT, () => console.log(`Knowvia API running on http://localhost:${PORT}`));
