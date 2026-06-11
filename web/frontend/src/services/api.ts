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
  },
};
