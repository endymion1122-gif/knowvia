import express from "express";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import { authMiddleware } from "./middleware/auth.js";
import authRoutes from "./routes/auth.js";
import documentRoutes from "./routes/documents.js";
import { getDb } from "./db/schema.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT || 3001;

const app = express();

app.use(cors({ origin: ["http://localhost:5173", "http://localhost:3000"], credentials: true }));
app.use(express.json({ limit: "10mb" }));

// Serve uploaded files
app.use("/uploads", express.static(path.join(__dirname, "..", "uploads")));

// Auth routes (no middleware)
app.use("/api/auth", authRoutes);

// Protected routes
app.use("/api/documents", authMiddleware, documentRoutes);

// Serve frontend in production
const frontendDist = path.join(__dirname, "..", "..", "frontend", "dist");
app.use(express.static(frontendDist));
app.get("/{*splat}", (_req, res) => {
  res.sendFile(path.join(frontendDist, "index.html"));
});

// Init DB on startup
getDb();

app.listen(PORT, () => {
  console.log(`Knowvia API running on http://localhost:${PORT}`);
});
