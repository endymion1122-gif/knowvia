/**
 * AI Provider abstraction — unified interface for Claude & OpenAI-compatible APIs.
 *
 * Claude: POST https://api.anthropic.com/v1/messages (x-api-key header)
 * OpenAI-compatible: POST {endpoint} (Bearer token)
 */
export interface AiRequest {
  model: string;
  system?: string;
  messages: { role: "user" | "assistant"; content: string }[];
  maxTokens: number;
  temperature?: number;
  responseFormat?: "json_object" | "text";
}

export interface AiResponse {
  content: string;
  model: string;
  usage?: { input: number; output: number };
}

/** Detect provider from model name or endpoint */
export function detectProvider(model: string, endpoint: string): "claude" | "openai" {
  if (
    endpoint.includes("anthropic.com") ||
    model.startsWith("claude-") ||
    model.includes("claude")
  ) {
    return "claude";
  }
  return "openai";
}

/** Call Claude Messages API */
async function callClaude(
  apiKey: string, endpoint: string, req: AiRequest
): Promise<AiResponse> {
  const body: any = {
    model: req.model,
    max_tokens: req.maxTokens,
    messages: req.messages.map((m) => ({ role: m.role, content: m.content })),
  };
  if (req.system) body.system = req.system;
  if (req.temperature != null) body.temperature = req.temperature;

  const res = await fetch(endpoint || "https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Claude API error ${res.status}: ${err}`);
  }

  const data = await res.json();
  return {
    content: data.content?.[0]?.text || "",
    model: data.model,
    usage: data.usage ? { input: data.usage.input_tokens, output: data.usage.output_tokens } : undefined,
  };
}

/** Call OpenAI-compatible Chat API */
async function callOpenAI(
  apiKey: string, endpoint: string, req: AiRequest
): Promise<AiResponse> {
  const messages: any[] = [];
  if (req.system) {
    messages.push({ role: "system", content: req.system });
  }
  messages.push(...req.messages.map((m) => ({ role: m.role, content: m.content })));

  const body: any = {
    model: req.model,
    messages,
    max_tokens: req.maxTokens,
  };
  if (req.temperature != null) body.temperature = req.temperature;
  if (req.responseFormat === "json_object") body.response_format = { type: "json_object" };

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI API error ${res.status}: ${err}`);
  }

  const data = await res.json();
  return {
    content: data.choices?.[0]?.message?.content || "",
    model: data.model,
    usage: data.usage ? { input: data.usage.prompt_tokens, output: data.usage.completion_tokens } : undefined,
  };
}

/** Unified AI call — auto-detects provider from model name */
export async function callAI(
  apiKey: string, endpoint: string, req: AiRequest
): Promise<AiResponse> {
  const provider = detectProvider(req.model, endpoint);
  if (provider === "claude") {
    return callClaude(apiKey, endpoint, req);
  }
  return callOpenAI(apiKey, endpoint, req);
}
