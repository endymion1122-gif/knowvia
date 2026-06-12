import { describe, it, expect, beforeAll, afterAll } from "vitest";
import express from "express";
import cors from "cors";
import { getDb, closeDb } from "../src/db/schema.js";
import authRoutes from "../src/routes/auth.js";
import documentRoutes from "../src/routes/documents.js";
import aiRoutes from "../src/routes/ai.js";
import annotationRoutes from "../src/routes/annotations.js";
import cardRoutes from "../src/routes/cards.js";
import pathwayRoutes from "../src/routes/pathways.js";
import relationRoutes from "../src/routes/relations.js";
import evidenceRoutes from "../src/routes/evidences.js";
import exportRoutes from "../src/routes/exports.js";
import { authMiddleware } from "../src/middleware/auth.js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEST_DB = path.join(__dirname, "..", "test.db");

// Use test database
process.env.KNOWVIA_DB_PATH = TEST_DB;

let app: express.Express;
let server: any;
let token: string;
let userId: string;

beforeAll(async () => {
  // Clean test db
  const testDb = path.join(__dirname, "..", "test.db");
  if (fs.existsSync(testDb)) fs.unlinkSync(testDb);

  app = express();
  app.use(cors());
  app.use(express.json({ limit: "10mb" }));
  app.use("/api/auth", authRoutes);
  app.use("/api/documents", authMiddleware, documentRoutes);
  app.use("/api/ai", authMiddleware, aiRoutes);
  app.use("/api/annotations", authMiddleware, annotationRoutes);
  app.use("/api/cards", authMiddleware, cardRoutes);
  app.use("/api/pathways", authMiddleware, pathwayRoutes);
  app.use("/api/relations", authMiddleware, relationRoutes);
  app.use("/api/evidences", authMiddleware, evidenceRoutes);
  app.use("/api/exports", authMiddleware, exportRoutes);

  await new Promise<void>((resolve) => {
    server = app.listen(3099, () => resolve());
  });

  // Register and get token
  const res = await fetch("http://localhost:3099/api/auth/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: "testuser", password: "test123456" }),
  });
  const data = await res.json();
  token = data.token;
  userId = data.user.id;
});

afterAll(() => {
  server?.close();
  const testDb = path.join(__dirname, "..", "test.db");
  if (fs.existsSync(testDb)) fs.unlinkSync(testDb);
});

function authHeaders() {
  return { "Content-Type": "application/json", Authorization: `Bearer ${token}` };
}

describe("Auth API", () => {
  it("should register a new user", async () => {
    const res = await fetch("http://localhost:3099/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: "newuser", password: "pass123456" }),
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.token).toBeTruthy();
  });

  it("should reject duplicate username", async () => {
    const res = await fetch("http://localhost:3099/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: "testuser", password: "pass123456" }),
    });
    expect(res.status).toBe(409);
  });

  it("should login", async () => {
    const res = await fetch("http://localhost:3099/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: "testuser", password: "test123456" }),
    });
    expect(res.status).toBe(200);
  });
});

describe("Documents API", () => {
  it("should list documents (empty)", async () => {
    const res = await fetch("http://localhost:3099/api/documents", { headers: authHeaders() });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.documents).toEqual([]);
    expect(data.pagination).toBeTruthy();
  });

  it("should require auth", async () => {
    const res = await fetch("http://localhost:3099/api/documents");
    expect(res.status).toBe(401);
  });
});

describe("Pathways API", () => {
  let pathwayId: string;

  it("should create a pathway", async () => {
    const res = await fetch("http://localhost:3099/api/pathways", {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ title: "Test Pathway", goal: "Learn testing" }),
    });
    expect(res.status).toBe(201);
    const data = await res.json();
    expect(data.pathway.title).toBe("Test Pathway");
    pathwayId = data.pathway.id;
  });

  it("should list pathways", async () => {
    const res = await fetch("http://localhost:3099/api/pathways", { headers: authHeaders() });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.pathways.length).toBeGreaterThan(0);
    expect(data.pagination.total).toBeGreaterThan(0);
  });

  it("should get writing readiness", async () => {
    const res = await fetch(`http://localhost:3099/api/pathways/${pathwayId}/writing-readiness`, {
      headers: authHeaders(),
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.readiness_score).toBeDefined();
    expect(data.checks).toBeDefined();
  });

  it("should get source quality (empty pathway)", async () => {
    const res = await fetch(`http://localhost:3099/api/pathways/${pathwayId}/source-quality`, {
      headers: authHeaders(),
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.total_sources).toBe(0);
  });
});

describe("Cards API", () => {
  it("should create a card", async () => {
    const res = await fetch("http://localhost:3099/api/cards", {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ title: "Test Card", content: "Test content", card_type: "concept" }),
    });
    expect(res.status).toBe(200);
  });

  it("should list cards", async () => {
    const res = await fetch("http://localhost:3099/api/cards", { headers: authHeaders() });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.cards.length).toBeGreaterThan(0);
  });
});

describe("AI API (demo mode)", () => {
  it("should explain text in demo mode", async () => {
    const res = await fetch("http://localhost:3099/api/ai/explain", {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ text: "test concept" }),
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.mode).toBe("demo");
    expect(data.result).toBeTruthy();
  });

  it("should extract nodes in demo mode", async () => {
    const res = await fetch("http://localhost:3099/api/ai/extract-nodes", {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ markdown_content: "# Test\nSome content here for extraction." }),
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.mode).toBe("demo");
    expect(Array.isArray(data.nodes)).toBe(true);
  });
});

describe("Relations API", () => {
  let card1Id: string, card2Id: string, pathwayId: string;

  beforeAll(async () => {
    const pw = await fetch("http://localhost:3099/api/pathways", {
      method: "POST", headers: authHeaders(),
      body: JSON.stringify({ title: "Relation Test" }),
    }).then(r => r.json());
    pathwayId = pw.pathway.id;
    const c1 = await fetch("http://localhost:3099/api/cards", {
      method: "POST", headers: authHeaders(),
      body: JSON.stringify({ title: "Node A", content: "A", card_type: "concept" }),
    }).then(r => r.json());
    card1Id = c1.card.id;
    const c2 = await fetch("http://localhost:3099/api/cards", {
      method: "POST", headers: authHeaders(),
      body: JSON.stringify({ title: "Node B", content: "B", card_type: "claim" }),
    }).then(r => r.json());
    card2Id = c2.card.id;
  });

  it("should create a relation", async () => {
    const res = await fetch("http://localhost:3099/api/relations", {
      method: "POST", headers: authHeaders(),
      body: JSON.stringify({
        pathway_id: pathwayId, source_card_id: card1Id,
        target_card_id: card2Id, relation_type: "support",
      }),
    });
    expect(res.status).toBe(201);
  });
});

describe("Exports API", () => {
  let pathwayId: string;

  beforeAll(async () => {
    const pw = await fetch("http://localhost:3099/api/pathways", {
      method: "POST", headers: authHeaders(),
      body: JSON.stringify({ title: "Export Test", goal: "Test" }),
    }).then(r => r.json());
    pathwayId = pw.pathway.id;
  });

  it("should generate markdown report", async () => {
    const res = await fetch("http://localhost:3099/api/exports", {
      method: "POST", headers: authHeaders(),
      body: JSON.stringify({ pathway_id: pathwayId, export_type: "markdown_report" }),
    });
    expect(res.status).toBe(201);
    const data = await res.json();
    expect(data.export.download_url).toBeTruthy();
  });
});
