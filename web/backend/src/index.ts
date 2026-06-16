import express from "express";
import cors from "cors";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import { authMiddleware } from "./middleware/auth.js";
import { apiRateLimit, authRateLimit } from "./middleware/rateLimit.js";
import { securityHeaders } from "./middleware/security.js";
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
app.use(securityHeaders);
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

// Health check (no auth, no rate limit)
app.get("/api/health", (_req, res) => {
  const db = getDb();
  const stats = {
    users: (db.prepare("SELECT COUNT(*) as c FROM users").get() as any).c,
    documents: (db.prepare("SELECT COUNT(*) as c FROM documents").get() as any).c,
    cards: (db.prepare("SELECT COUNT(*) as c FROM knowledge_cards").get() as any).c,
    pathways: (db.prepare("SELECT COUNT(*) as c FROM knowledge_pathways").get() as any).c,
  };
  res.json({ status: "healthy", uptime: process.uptime(), memory: process.memoryUsage().heapUsed, stats });
});

// Auth routes (rate limited)
app.use("/api/auth", authRateLimit, authRoutes);

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

// Protected routes (rate limited)
app.use("/api/documents", apiRateLimit, authMiddleware, documentRoutes);

// AI routes (explain, extract-concepts)
app.use("/api/ai", apiRateLimit, authMiddleware, aiRoutes);

// Annotation routes (CRUD)
app.use("/api/annotations", apiRateLimit, authMiddleware, annotationRoutes);

// Knowledge card routes (CRUD)
app.use("/api/cards", apiRateLimit, authMiddleware, cardRoutes);

// Knowledge pathway routes (goal priming + CRUD)
app.use("/api/pathways", apiRateLimit, authMiddleware, pathwayRoutes);

// Relation routes (node connections)
app.use("/api/relations", apiRateLimit, authMiddleware, relationRoutes);

// Evidence routes (source tracing)
app.use("/api/evidences", apiRateLimit, authMiddleware, evidenceRoutes);

// Export routes (markdown report generation)
app.use("/api/exports", apiRateLimit, authMiddleware, exportRoutes);

// Search routes (FTS5 full-text search)
app.use("/api/search", apiRateLimit, authMiddleware, searchRoutes);

// Debug test route
app.post("/api/ping", (_req, res) => { res.json({ pong: true }); });

// Error handling middleware
app.use((err: any, _req: any, res: any, _next: any) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ error: "服务器内部错误" });
});

// Serve frontend in production (supports Docker, Railway, and local dev)
const frontendDist = process.env.FRONTEND_DIST ||
  path.join(__dirname, "..", "frontend-dist");
if (fs.existsSync(frontendDist)) {
  app.use(express.static(frontendDist));
  app.get("/{*splat}", (_req, res) => {
    if (!_req.path.startsWith("/api")) {
      res.sendFile(path.join(frontendDist, "index.html"));
    }
  });
}

getDb();
app.listen(PORT, () => console.log(`Knowvia API running on http://localhost:${PORT}`));
