const BASE = "/api";

async function request<T>(url: string, options?: RequestInit): Promise<T> {
  const token = localStorage.getItem("token");
  const headers: Record<string, string> = {
    ...(options?.headers as Record<string, string> || {}),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${BASE}${url}`, { ...options, headers });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "请求失败");
  return data;
}

// Auth
export const api = {
  auth: {
    register: (username: string, password: string) =>
      request<{ token: string; user: any }>("/auth/register", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      }),
    login: (username: string, password: string) =>
      request<{ token: string; user: any }>("/auth/login", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      }),
    me: () => request<{ user: any }>("/auth/me"),
  },

  documents: {
    list: () => request<{ documents: any[] }>("/documents"),
    upload: (file: File) => {
      const form = new FormData();
      form.append("file", file);
      return request<{ document: any }>("/documents/upload", {
        method: "POST", body: form,
      });
    },
    update: (id: string, data: Record<string, unknown>) =>
      request<{ document: any }>(`/documents/${id}`, {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/documents/${id}`, { method: "DELETE" }),
    getMarkdown: (id: string) =>
      request<{ markdown: string }>(`/documents/${id}/markdown`),
    importUrl: (url: string) =>
      request<{ document: any }>("/documents/import-url", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url }),
      }),
  },

  annotations: {
    list: (document_id: string) =>
      request<{ annotations: any[] }>(`/annotations?document_id=${document_id}`),
    create: (data: { document_id: string; selected_text: string; note?: string; page_number?: number }) =>
      request<{ annotation: any }>("/annotations", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/annotations/${id}`, { method: "DELETE" }),
  },

  cards: {
    list: (params?: { document_id?: string; card_type?: string }) => {
      const qs = params ? "?" + new URLSearchParams(params as any).toString() : "";
      return request<{ cards: any[] }>(`/cards${qs}`);
    },
    create: (data: {
      title: string; content: string; card_type?: string;
      source_document_id?: string; source_document_title?: string;
      page_number?: number; calibration_note?: string; tags?: string[];
      ai_generated_text?: string; user_summary?: string;
      confidence_score?: number; source_citation?: string;
    }) =>
      request<{ card: any }>("/cards", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    update: (id: string, data: Record<string, unknown>) =>
      request<{ card: any }>(`/cards/${id}`, {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/cards/${id}`, { method: "DELETE" }),
  },

  pathways: {
    list: (params?: { status?: string }) => {
      const qs = params ? "?" + new URLSearchParams(params as any).toString() : "";
      return request<{ pathways: any[] }>(`/pathways${qs}`);
    },
    get: (id: string) => request<{ pathway: any }>(`/pathways/${id}`),
    create: (data: {
      title: string; description?: string; goal?: string;
      existing_knowledge?: string; output_target?: string; tags?: string[];
    }) =>
      request<{ pathway: any }>("/pathways", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    update: (id: string, data: Record<string, unknown>) =>
      request<{ pathway: any }>(`/pathways/${id}`, {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/pathways/${id}`, { method: "DELETE" }),
    linkDocument: (id: string, document_id: string) =>
      request<{ success: boolean }>(`/pathways/${id}/link-document`, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ document_id }),
      }),
    getDocuments: (id: string) =>
      request<{ documents: any[] }>(`/pathways/${id}/documents`),
    getWritingReadiness: (id: string) =>
      request<any>(`/pathways/${id}/writing-readiness`),
  },

  relations: {
    list: (pathway_id: string) =>
      request<{ relations: any[] }>(`/relations?pathway_id=${pathway_id}`),
    create: (data: {
      pathway_id: string; source_card_id: string; target_card_id: string;
      relation_type: string; note?: string;
    }) =>
      request<{ relation: any }>("/relations", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    update: (id: string, data: Record<string, unknown>) =>
      request<{ relation: any }>(`/relations/${id}`, {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/relations/${id}`, { method: "DELETE" }),
  },

  evidences: {
    list: (node_id: string) =>
      request<{ evidences: any[] }>(`/evidences?node_id=${node_id}`),
    create: (data: {
      node_id: string; evidence_text: string; source_location?: string;
      evidence_strength?: string; evidence_type?: string;
    }) =>
      request<{ evidence: any }>("/evidences", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/evidences/${id}`, { method: "DELETE" }),
  },

  annotations: {
    list: (document_id: string) =>
      request<{ annotations: any[] }>(`/annotations?document_id=${document_id}`),
    create: (data: { document_id: string; selected_text: string; note?: string; page_number?: number }) =>
      request<{ annotation: any }>("/annotations", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/annotations/${id}`, { method: "DELETE" }),
  },

  documents: {
    ...api.documents,
    getMarkdown: (id: string) =>
      request<{ markdown: string }>(`/documents/${id}/markdown`),
  },

  exports: {
    list: (pathway_id: string) =>
      request<{ exports: any[] }>(`/exports?pathway_id=${pathway_id}`),
    create: (pathway_id: string, export_type: string) =>
      request<{ export: any }>("/exports", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pathway_id, export_type }),
      }),
    delete: (id: string) =>
      request<{ success: boolean }>(`/exports/${id}`, { method: "DELETE" }),
  },

  ai: {
    explain: (data: { text: string; context?: string; apiKey?: string; endpoint?: string; model?: string }) =>
      request<{ result: string; mode: string }>("/ai/explain", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    summarize: (data: { content: string; title?: string; apiKey?: string; endpoint?: string; model?: string }) =>
      request<any>("/ai/summarize-document", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    extractNodes: (data: {
      markdown_content: string; goal?: string; existing_knowledge?: string;
      output_target?: string; apiKey?: string; endpoint?: string; model?: string;
    }) =>
      request<{ nodes: any[]; suggested_relations: any[]; mode: string }>("/ai/extract-nodes", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
  },
};
