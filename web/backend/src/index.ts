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
