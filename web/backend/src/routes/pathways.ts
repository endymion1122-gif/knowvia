import { Router, Response } from "express";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { AuthRequest } from "../middleware/auth.js";

const router = Router();

// POST /api/pathways — create a new knowledge pathway with goal priming
router.post("/", (req: AuthRequest, res: Response) => {
  const { title, description, goal, existing_knowledge, output_target, tags } = req.body;
  if (!title?.trim()) {
    res.status(400).json({ error: "路径标题为必填项" });
    return;
  }

  const db = getDb();
  const id = uuid();
  db.prepare(`
    INSERT INTO knowledge_pathways (id, user_id, title, overview, goal, existing_knowledge, output_target, tags, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'draft')
  `).run(
    id, req.userId, title.trim(),
    description || "", goal || "", existing_knowledge || "",
    output_target || "", tags ? JSON.stringify(tags) : "[]",
  );

  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ?").get(id);
  res.status(201).json({ pathway: formatPathway(pathway) });
});

// GET /api/pathways — list user's pathways (with pagination)
router.get("/", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { status, page, limit } = req.query;
  const pageNum = Math.max(1, parseInt(page as string) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(limit as string) || 50));

  let where = "WHERE user_id = ?";
  const params: any[] = [req.userId];
  if (status) { where += " AND status = ?"; params.push(status); }

  const total = (db.prepare(`SELECT COUNT(*) as c FROM knowledge_pathways ${where}`).get(...params) as any).c;
  const rows = db.prepare(`SELECT * FROM knowledge_pathways ${where} ORDER BY updated_at DESC LIMIT ? OFFSET ?`)
    .all(...params, pageSize, (pageNum - 1) * pageSize);
  res.json({
    pathways: (rows as any[]).map(formatPathway),
    pagination: { page: pageNum, limit: pageSize, total, totalPages: Math.ceil(total / pageSize) },
  });
});

// GET /api/pathways/:id — get pathway detail
router.get("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }
  res.json({ pathway: formatPathway(pathway) });
});

// PATCH /api/pathways/:id — update pathway
router.patch("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const existing = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!existing) { res.status(404).json({ error: "路径不存在" }); return; }

  const { title, description, goal, existing_knowledge, output_target, status: st, tags, source_markdown } = req.body;
  db.prepare(`
    UPDATE knowledge_pathways SET
      title = COALESCE(?, title), overview = COALESCE(?, overview),
      goal = COALESCE(?, goal), existing_knowledge = COALESCE(?, existing_knowledge),
      output_target = COALESCE(?, output_target), status = COALESCE(?, status),
      tags = COALESCE(?, tags), source_markdown = COALESCE(?, source_markdown),
      updated_at = datetime('now')
    WHERE id = ?
  `).run(
    title ?? null, description ?? null, goal ?? null,
    existing_knowledge ?? null, output_target ?? null, st ?? null,
    tags ? JSON.stringify(tags) : null, source_markdown ?? null,
    req.params.id,
  );
  const updated = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ?").get(req.params.id);
  res.json({ pathway: formatPathway(updated) });
});

// POST /api/pathways/:id/share — toggle sharing
router.post("/:id/share", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }

  const token = pathway.share_token || require("uuid").v4().replace(/-/g, "").slice(0, 12);
  const isPublic = pathway.is_public ? 0 : 1;
  db.prepare("UPDATE knowledge_pathways SET share_token = ?, is_public = ? WHERE id = ?")
    .run(token, isPublic, req.params.id);
  res.json({
    shared: !!isPublic,
    share_url: isPublic ? `/share/${token}` : null,
    share_token: token,
  });
});

// DELETE /api/pathways/:id
router.delete("/:id", (req: AuthRequest, res: Response) => {
  const db = getDb();
  db.prepare("DELETE FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .run(req.params.id, req.userId);
  res.json({ success: true });
});

// POST /api/pathways/:id/link-document — link a document to a pathway
router.post("/:id/link-document", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const { document_id } = req.body;
  if (!document_id) { res.status(400).json({ error: "请提供 document_id" }); return; }
  const pathway = db.prepare("SELECT id FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId);
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }
  db.prepare("INSERT OR IGNORE INTO pathway_documents (pathway_id, document_id) VALUES (?, ?)")
    .run(req.params.id, document_id);
  // Copy markdown if available
  const doc = db.prepare("SELECT markdown_content FROM documents WHERE id = ?").get(document_id) as any;
  if (doc?.markdown_content) {
    db.prepare("UPDATE knowledge_pathways SET source_markdown = COALESCE(NULLIF(source_markdown,''), ?) || ? WHERE id = ?")
      .run(doc.markdown_content, doc.markdown_content, req.params.id);
  }
  res.json({ success: true });
});

// GET /api/pathways/:id/documents — list documents in a pathway
router.get("/:id/documents", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const docs = db.prepare(`
    SELECT d.* FROM documents d
    JOIN pathway_documents pd ON pd.document_id = d.id
    WHERE pd.pathway_id = ? AND d.user_id = ?
  `).all(req.params.id, req.userId);
  res.json({ documents: docs });
});

// POST /api/pathways/:id/extract-all — merge AI extraction from all documents
router.post("/:id/extract-all", async (req: AuthRequest, res: Response) => {
  const { apiKey, endpoint, model } = req.body;
  const db = getDb();

  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }

  const docIds = db.prepare("SELECT document_id FROM pathway_documents WHERE pathway_id = ?")
    .all(req.params.id).map((r: any) => r.document_id);
  if (docIds.length === 0) { res.status(400).json({ error: "路径中没有文档" }); return; }

  // Collect markdown from all documents
  const docs = db.prepare(`SELECT id, title, markdown_content FROM documents WHERE id IN (${docIds.map(() => "?").join(",")})`)
    .all(...docIds) as any[];
  const combinedMarkdown = docs
    .map((d: any) => `## ${d.title}\n\n${d.markdown_content || ""}`)
    .join("\n\n---\n\n")
    .slice(0, 50000);

  if (!apiKey || !endpoint || !model) {
    // Demo mode: return simple extraction
    const demoNodes = combinedMarkdown.split("\n").filter((l: string) => l.length > 10).slice(0, 6).map((line: string, i: number) => ({
      title: line.replace(/^#+\s*/, "").slice(0, 50),
      content: line.slice(0, 120),
      card_type: ["concept","claim","concept","evidence","question","concept"][i % 6],
      source_document_title: docs[0]?.title || "",
    }));
    res.json({ nodes: demoNodes, suggested_relations: [], mode: "demo", source_count: docs.length });
    return;
  }

  try {
    const prompt = `从以下${docs.length}份文档中提取核心知识节点：

学习目标：${pathway.goal || "理解核心内容"}
已有知识：${pathway.existing_knowledge || "无"}
输出目标：${pathway.output_target || "形成系统理解"}

${combinedMarkdown}

请用 JSON 返回，每个节点标注来源文档标题：
{
  "nodes": [
    {"title":"概念名","content":"解释","card_type":"concept|claim|evidence|question","importance":"high|medium|low","source_doc":"文档标题"}
  ],
  "suggested_relations": [
    {"source_index":0,"target_index":1,"relation_type":"support|oppose|cause|example"}
  ]
}
只返回 JSON。`;

    const aiRes = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({ model, messages: [{ role: "user", content: prompt }], max_tokens: 4000, temperature: 0.3 }),
    });

    if (!aiRes.ok) {
      const err = await aiRes.text();
      res.status(502).json({ error: `AI 请求失败: ${err}` });
      return;
    }

    const data = await aiRes.json();
    const raw = data.choices?.[0]?.message?.content || "{}";
    try {
      const parsed = JSON.parse(raw);
      // Auto-create cards from all extracted nodes
      for (const node of parsed.nodes || []) {
        const sourceDoc = docs.find((d: any) => d.title === node.source_doc);
        if (sourceDoc) {
          const id = require("uuid").v4();
          db.prepare(`INSERT INTO knowledge_cards (id, user_id, title, content, card_type, source_document_id, source_document_title, ai_generated_text, confidence_score)
            VALUES (?,?,?,?,?,?,?,?,?)`).run(
            id, req.userId, node.title, node.content, node.card_type,
            sourceDoc.id, sourceDoc.title, node.content, 0.8,
          );
          // Link to pathway
          db.prepare("INSERT OR IGNORE INTO pathway_cards (pathway_id, card_id) VALUES (?,?)")
            .run(req.params.id, id);
        }
      }
      // Auto-create relations
      const cards = db.prepare(`SELECT * FROM knowledge_cards WHERE id IN (SELECT card_id FROM pathway_cards WHERE pathway_id = ?)`)
        .all(req.params.id) as any[];
      for (const rel of parsed.suggested_relations || []) {
        if (rel.source_index < cards.length && rel.target_index < cards.length) {
          const rid = require("uuid").v4();
          db.prepare(`INSERT INTO knowledge_relations (id, pathway_id, source_card_id, target_card_id, relation_type, note, ai_suggested)
            VALUES (?,?,?,?,?,?,1)`).run(
            rid, req.params.id, cards[rel.source_index].id, cards[rel.target_index].id, rel.relation_type, "",
          );
        }
      }
      res.json({
        nodes: parsed.nodes || [],
        suggested_relations: parsed.suggested_relations || [],
        mode: "api",
        source_count: docs.length,
      });
    } catch {
      res.json({ nodes: [], suggested_relations: [], mode: "api", raw });
    }
  } catch (e: any) {
    res.status(502).json({ error: `AI 请求异常: ${e.message}` });
  }
});

// GET /api/pathways/:id/writing-readiness — analyze pathway for writing gaps
router.get("/:id/writing-readiness", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const pathway = db.prepare("SELECT * FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId) as any;
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }

  // Get linked documents and their cards
  const docIds = db.prepare("SELECT document_id FROM pathway_documents WHERE pathway_id = ?")
    .all(req.params.id).map((r: any) => r.document_id);
  const cards = docIds.length > 0
    ? db.prepare(`SELECT * FROM knowledge_cards WHERE source_document_id IN (${docIds.map(() => "?").join(",")})`)
        .all(...docIds) as any[]
    : [];
  const relations = db.prepare("SELECT * FROM knowledge_relations WHERE pathway_id = ?")
    .all(req.params.id) as any[];
  const documents = db.prepare("SELECT * FROM documents WHERE id IN (" + docIds.map(() => "?").join(",") + ")")
    .all(...docIds) as any[];

  // Count by type
  const claims = cards.filter((c: any) => ["claim","viewpoint","argument"].includes(c.card_type));
  const evidenceNodes = cards.filter((c: any) => c.card_type === "evidence");
  const concepts = cards.filter((c: any) => c.card_type === "concept");
  const questions = cards.filter((c: any) => c.card_type === "question");

  // Check 1: Claims without evidence
  const claimsNeedingEvidence = claims.filter((claim: any) => {
    const hasEvidence = relations.some((r: any) =>
      (r.source_card_id === claim.id || r.target_card_id === claim.id) &&
      evidenceNodes.some((e: any) => e.id === r.source_card_id || e.id === r.target_card_id)
    );
    return !hasEvidence;
  });

  // Check 2: Sources missing metadata (not properly citable)
  const uncitableSources = documents.filter((d: any) =>
    !d.author?.trim() || !d.publication_year
  );

  // Check 3: Unresolved questions
  const unresolvedQuestions = questions.filter((q: any) => !q.user_confirmed);

  // Check 4: Unconfirmed cards (not yet reviewed by user)
  const unconfirmedCards = cards.filter((c: any) => !c.user_confirmed);

  // Readiness score
  const totalChecks = 4;
  let passedChecks = 0;
  if (claimsNeedingEvidence.length === 0) passedChecks++;
  if (uncitableSources.length === 0) passedChecks++;
  if (unresolvedQuestions.length === 0) passedChecks++;
  if (unconfirmedCards.length === 0 || cards.length === 0) passedChecks++;
  const readinessScore = cards.length > 0 ? Math.round((passedChecks / totalChecks) * 100) : 0;

  res.json({
    pathway_id: req.params.id,
    readiness_score: readinessScore,
    total_cards: cards.length,
    total_claims: claims.length,
    total_evidence: evidenceNodes.length,
    total_sources: documents.length,
    checks: {
      evidence_coverage: {
        passed: claimsNeedingEvidence.length === 0,
        label: "观点有证据支撑",
        detail: claimsNeedingEvidence.length > 0
          ? `${claimsNeedingEvidence.length} 个观点缺少证据支撑`
          : "所有观点都有证据支撑",
        affected_ids: claimsNeedingEvidence.map((c: any) => c.id),
      },
      source_citability: {
        passed: uncitableSources.length === 0,
        label: "来源可引用",
        detail: uncitableSources.length > 0
          ? `${uncitableSources.length} 个来源缺少作者或年份`
          : "所有来源都完整可引用",
        affected_ids: uncitableSources.map((d: any) => d.id),
      },
      questions_resolved: {
        passed: unresolvedQuestions.length === 0,
        label: "问题已处理",
        detail: unresolvedQuestions.length > 0
          ? `${unresolvedQuestions.length} 个问题尚未确认`
          : "所有问题已确认或没有待处理问题",
        affected_ids: unresolvedQuestions.map((q: any) => q.id),
      },
      cards_confirmed: {
        passed: unconfirmedCards.length === 0 || cards.length === 0,
        label: "节点已校准",
        detail: unconfirmedCards.length > 0
          ? `${unconfirmedCards.length} 个节点尚未用户确认`
          : "所有节点已确认",
        affected_ids: unconfirmedCards.map((c: any) => c.id),
      },
    },
    summary: readinessScore >= 75
      ? "写作准备度良好，可以开始撰写综述"
      : readinessScore >= 50
        ? "还有一些缺口需要补充后再开始写作"
        : "建议先补充证据和元数据再考虑写作",
  });
});

// GET /api/pathways/:id/source-quality — source metadata overview
router.get("/:id/source-quality", (req: AuthRequest, res: Response) => {
  const db = getDb();
  const pathway = db.prepare("SELECT id FROM knowledge_pathways WHERE id = ? AND user_id = ?")
    .get(req.params.id, req.userId);
  if (!pathway) { res.status(404).json({ error: "路径不存在" }); return; }

  const docIds = db.prepare("SELECT document_id FROM pathway_documents WHERE pathway_id = ?")
    .all(req.params.id).map((r: any) => r.document_id);
  const docs = docIds.length > 0
    ? db.prepare(`SELECT * FROM documents WHERE id IN (${docIds.map(() => "?").join(",")})`).all(...docIds) as any[]
    : [];

  const total = docs.length;
  const complete = docs.filter((d: any) => d.author?.trim() && d.publication_year).length;
  const missingAuthor = docs.filter((d: any) => !d.author?.trim()).length;
  const missingYear = docs.filter((d: any) => !d.publication_year).length;
  const missingBoth = docs.filter((d: any) => !d.author?.trim() && !d.publication_year).length;
  const hasNote = docs.filter((d: any) => d.source_note?.trim()).length;
  const hasUrl = docs.filter((d: any) => d.source_url?.trim()).length;

  // Authority assessment: sources with author+year+url are "citable"
  const citable = docs.filter((d: any) => d.author?.trim() && d.publication_year && d.source_url?.trim()).length;

  const suggestions = docs
    .filter((d: any) => !d.author?.trim() || !d.publication_year)
    .map((d: any) => ({
      id: d.id,
      title: d.title,
      missing_fields: [
        !d.author?.trim() ? "作者" : null,
        !d.publication_year ? "年份" : null,
        !d.source_url?.trim() ? "链接" : null,
      ].filter(Boolean),
      suggestion: !d.author?.trim() && !d.publication_year
        ? "请补全作者和年份信息以便引用"
        : !d.author?.trim()
          ? "请补充作者信息"
          : "请补充出版年份",
    }));

  res.json({
    pathway_id: req.params.id,
    total_sources: total,
    metadata_completeness: total > 0 ? Math.round((complete / total) * 100) : 0,
    breakdown: {
      complete, missingAuthor, missingYear, missingBoth,
      hasNote, hasUrl, citable,
    },
    authority_ratio: total > 0 ? Math.round((citable / total) * 100) : 0,
    suggestions,
    summary: total === 0
      ? "暂无来源资料"
      : complete === total
        ? "所有来源元数据完整，可以放心引用"
        : `${missingBoth} 个来源缺少作者和年份，${missingAuthor} 个缺少作者，${missingYear} 个缺少年份`,
  });
});

function formatPathway(row: any) {
  if (!row) return null;
  return {
    ...row,
    tags: safeJsonParse(row.tags, []),
  };
}

function safeJsonParse(s: string, fallback: any) {
  try { return JSON.parse(s); } catch { return fallback; }
}

export default router;
