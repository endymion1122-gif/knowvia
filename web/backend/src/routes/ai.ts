import { Router, Response } from "express";
import { AuthRequest } from "../middleware/auth.js";
import { callAI } from "../utils/ai-provider.js";

const router = Router();

// POST /api/ai/explain — explain a selected concept
router.post("/explain", async (req: AuthRequest, res: Response) => {
  const { text, context, apiKey, endpoint, model } = req.body;
  if (!text?.trim()) {
    res.status(400).json({ error: "请选择要解释的文本" });
    return;
  }

  // Use provided AI config or fall back to built-in demo mode
  if (!apiKey || !endpoint || !model) {
    // Demo mode — returns a structured placeholder
    const demo = buildDemoExplanation(text, context);
    res.json({ result: demo, mode: "demo" });
    return;
  }

  try {
    const prompt = `你是一个学术知识助手。请用中文简要解释下面这段话的核心概念，并说明它在上下文中的作用。

上下文：${context || "未知资料"}

选中的文本：
${text.trim()}

请给出：
1. 核心概念：一句话解释
2. 在上下文中的作用
3. 是否需要用户进一步核验（标注"AI 初稿，请结合原文确认"）`;

    const aiRes = await callAI(apiKey, endpoint, {
      model,
      messages: [{ role: "user", content: prompt }],
      maxTokens: 500,
      temperature: 0.3,
    });
    res.json({ result: aiRes.content || "AI 未返回有效结果", mode: "api" });
  } catch (e: any) {
    res.status(502).json({ error: `AI 请求异常: ${e.message}` });
  }
});

// POST /api/ai/extract-concepts — extract concepts from document content
router.post("/extract-concepts", async (req: AuthRequest, res: Response) => {
  const { content, title, apiKey, endpoint, model } = req.body;
  if (!content?.trim()) {
    res.status(400).json({ error: "请提供文档内容" });
    return;
  }

  if (!apiKey || !endpoint || !model) {
    res.json({ concepts: buildDemoConcepts(content, title), mode: "demo" });
    return;
  }

  try {
    const excerpt = content.slice(0, 8000);
    const prompt = `请从以下文档中抽取核心概念、观点、证据和问题，用 JSON 数组返回。

文档标题：${title || "未知"}
文档内容（节选）：
${excerpt}

返回格式：
[
  {"type": "concept", "title": "概念名", "content": "一句话解释", "importance": "high|medium|low"},
  {"type": "claim", "title": "观点概述", "content": "详细观点", "importance": "high|medium"},
  {"type": "evidence", "title": "证据简述", "content": "证据详情", "importance": "medium|low"},
  {"type": "question", "title": "问题", "content": "该资料引发或未解决的问题"}
]

只返回 JSON 数组，不要其他文字。`;

    const aiRes = await callAI(apiKey, endpoint, {
      model,
      messages: [{ role: "user", content: prompt }],
      maxTokens: 2000,
      temperature: 0.3,
      responseFormat: model.includes("gpt") ? "json_object" : "text",
    });
    const raw = aiRes.content || "[]";
    try {
      const concepts = JSON.parse(raw);
      res.json({ concepts: Array.isArray(concepts) ? concepts : concepts.concepts || [], mode: "api" });
    } catch {
      res.json({ concepts: [{ type: "concept", title, content: raw }], mode: "api" });
    }
  } catch (e: any) {
    res.status(502).json({ error: `AI 请求异常: ${e.message}` });
  }
});

// POST /api/ai/extract-nodes — full node extraction with relations (spec-compliant prompt)
router.post("/extract-nodes", async (req: AuthRequest, res: Response) => {
  const { markdown_content, goal, existing_knowledge, output_target, apiKey, endpoint, model } = req.body;
  if (!markdown_content?.trim()) {
    res.status(400).json({ error: "请提供文档内容" });
    return;
  }

  if (!apiKey || !endpoint || !model) {
    const demo = buildDemoExtraction(markdown_content);
    res.json({ ...demo, mode: "demo" });
    return;
  }

  try {
    const excerpt = markdown_content.slice(0, 12000);
    const systemPrompt = `你是一个教育研究助手，专门帮助学习者从学术资料中提取关键知识。

你的任务是：
1. 从给定的Markdown文本中提取最多8个关键概念、观点或证据
2. 每个提取物应该清晰、准确、自包含
3. 要标注每个提取物的来源位置（页码、段落等）
4. 要评估你的提取置信度（0.0-1.0）
5. 识别节点之间可能的关系（支撑、反对、因果、例证等）

提取的知识节点应该是：
- 清晰的（易于理解）
- 完整的（独立成立，不依赖其他文本）
- 有意义的（对学习目标有帮助）
- 可溯源的（能找到原始来源）`;

    const userPrompt = `学习目标：${goal || "理解该资料的核心内容"}
现有知识：${existing_knowledge || "无特别说明"}
输出目标：${output_target || "形成系统的知识理解"}

请从以下资料中提取关键知识节点：

---
${excerpt}
---

请以 JSON 格式返回，包含节点和建议的关系：
{
  "nodes": [
    {
      "node_type": "concept|viewpoint|evidence|model|case",
      "title": "简短标题",
      "text": "节点文本内容",
      "source_page": 5,
      "confidence": 0.95,
      "reasoning": "为什么提取这个节点"
    }
  ],
  "suggested_relations": [
    {
      "source_index": 0,
      "target_index": 1,
      "relation_type": "support|oppose|cause|example|include",
      "reasoning": "为什么有这个关系"
    }
  ]
}
只返回 JSON，不要其他文字。`;

    const aiRes = await callAI(apiKey, endpoint, {
      model,
      system: systemPrompt,
      messages: [{ role: "user", content: userPrompt }],
      maxTokens: 3000,
      temperature: 0.3,
      responseFormat: model.includes("gpt") ? "json_object" : "text",
    });

    if (!aiRes.content) {
      res.status(502).json({ error: "AI 返回空响应" });
      return;
    }

    const raw = aiRes.content;
    try {
      const parsed = JSON.parse(raw);
      res.json({
        nodes: parsed.nodes || [],
        suggested_relations: parsed.suggested_relations || [],
        mode: "api",
      });
    } catch {
      res.json({ nodes: [], suggested_relations: [], mode: "api", raw });
    }
  } catch (e: any) {
    res.status(502).json({ error: `AI 请求异常: ${e.message}` });
  }
});

// POST /api/ai/summarize-document — AI summary + structure diagnosis
router.post("/summarize-document", async (req: AuthRequest, res: Response) => {
  const { content, title, apiKey, endpoint, model } = req.body;
  if (!content?.trim()) {
    res.status(400).json({ error: "请提供文档内容" });
    return;
  }

  if (!apiKey || !endpoint || !model) {
    res.json({ ...buildDemoSummary(content, title), mode: "demo" });
    return;
  }

  try {
    const excerpt = content.slice(0, 10000);
    const prompt = `你是一个学术阅读策略助手。请分析以下文档，用 JSON 格式返回：

{
  "summary": "200字以内的核心摘要",
  "structure_type": "描述型|分类型|顺序型|对比型|问题解决型|因果机制型|证据论证型",
  "key_items": [
    {"type": "concept|claim|evidence|question", "title": "简短标题", "content": "一句话解释", "importance": "high|medium|low"}
  ],
  "recommended_view": "比较矩阵|流程路径图|观点证据链|框架树|问题方案路径",
  "reading_goal": "该资料适合回答什么问题"
}

文档标题：${title || "未知"}
文档内容（节选）：
${excerpt}

只返回 JSON，不要其他文字。`;

    const aiRes = await callAI(apiKey, endpoint, {
      model,
      messages: [{ role: "user", content: prompt }],
      maxTokens: 2000,
      temperature: 0.3,
      responseFormat: model.includes("gpt") ? "json_object" : "text",
    });

    const raw = aiRes.content || "{}";
    try {
      const parsed = JSON.parse(raw);
      res.json({ ...parsed, mode: "api" });
    } catch {
      res.json({ summary: raw, structure_type: "描述型", key_items: [], recommended_view: "框架树", mode: "api" });
    }
  } catch (e: any) {
    res.status(502).json({ error: `AI 请求异常: ${e.message}` });
  }
});

// --- Demo helpers ---

function buildDemoExplanation(text: string, _context: string): string {
  const snippet = text.slice(0, 80);
  return `[Demo AI] 核心概念：\n"${snippet}..."\n\n这看起来是一个需要结合上下文进一步理解的概念。在正式版中，配置 API Key 后可获得真实 AI 分析。\n\n📌 AI 初稿，请结合原文确认。`;
}

function buildDemoConcepts(content: string, title: string): any[] {
  const words = content.slice(0, 200).split(/[\s，。；！？\n]+/).filter((w) => w.length >= 2 && w.length <= 10);
  const sample = words.slice(0, 6).map((w, i) => ({
    type: ["concept", "concept", "claim", "evidence", "question"][i % 5] as string,
    title: w,
    content: `[Demo] ${title || "资料"}中的${w}`,
    importance: ["high", "medium", "low"][i % 3] as string,
  }));
  return sample.length > 0 ? sample : [{ type: "concept", title: "示例概念", content: "[Demo] 配置 API Key 后自动抽取", importance: "high" }];
}

function buildDemoExtraction(markdown: string): { nodes: any[]; suggested_relations: any[] } {
  const lines = markdown.split("\n").filter((l) => l.trim().length > 10).slice(0, 8);
  const nodes = lines.map((line, i) => ({
    node_type: ["concept", "viewpoint", "concept", "evidence", "model", "viewpoint", "concept", "case"][i % 8],
    title: line.replace(/^#+\s*/, "").slice(0, 40),
    text: line.slice(0, 120),
    source_page: i + 1,
    confidence: 0.6 + Math.random() * 0.3,
    reasoning: `[Demo] 从文档第 ${i + 1} 段提取`,
  }));
  const relations = nodes.length >= 2 ? [{
    source_index: 0, target_index: 1,
    relation_type: "support",
    reasoning: "[Demo] AI 建议的关系",
  }] : [];
  return { nodes, suggested_relations: relations };
}

function buildDemoSummary(content: string, title: string) {
  const firstLine = content.slice(0, 120).replace(/\n/g, " ");
  const words = content.slice(0, 200).split(/[\s，。；！？\n]+/).filter((w: string) => w.length >= 2 && w.length <= 10);
  const sample = words.slice(0, 6).map((w, i) => ({
    type: ["concept", "concept", "claim", "evidence", "question"][i % 5] as string,
    title: w,
    content: `[Demo] ${title || "资料"}中的${w}`,
    importance: ["high", "medium", "low"][i % 3] as string,
  }));

  return {
    summary: `[Demo] 本文档"${title || "未知资料"}"的开头部分：${firstLine}...\n\n配置 API Key 后可获得真实 AI 结构诊断和摘要。`,
    structure_type: "描述型",
    key_items: sample.length > 0 ? sample : [
      { type: "concept", title: "示例概念", content: "[Demo] 配置 API Key 后自动抽取", importance: "high" },
    ],
    recommended_view: "框架树",
    reading_goal: "了解该主题的基本概念和结构",
  };
}

export default router;
