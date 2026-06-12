import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";
import type { Document as Doc } from "../types";

export function LibraryPage() {
  const navigate = useNavigate();
  const [docs, setDocs] = useState<Doc[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [importUrl, setImportUrl] = useState("");
  const [importing, setImporting] = useState(false);
  const [error, setError] = useState("");

  const loadDocs = useCallback(async () => {
    try {
      const { documents } = await api.documents.list();
      setDocs(documents);
    } catch (e: any) { setError(e.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { loadDocs(); }, [loadDocs]);

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setError("");
    try {
      await api.documents.upload(file);
      await loadDocs();
    } catch (err: any) { setError(err.message); }
    finally { setUploading(false); }
  };

  const handleImportUrl = async () => {
    if (!importUrl.trim()) return;
    setImporting(true);
    setError("");
    try {
      await api.documents.importUrl(importUrl.trim());
      setImportUrl("");
      await loadDocs();
    } catch (err: any) { setError(err.message); }
    finally { setImporting(false); }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("确定删除这份资料？")) return;
    try { await api.documents.delete(id); await loadDocs(); }
    catch (err: any) { setError(err.message); }
  };

  return (
    <div className="p-8 max-w-5xl">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-semibold text-[var(--deep-indigo)]">资料库</h2>
          <p className="text-xs text-[var(--tertiary-text)] mt-1">支持 PDF、Word、PPT、TXT、Markdown、网页链接</p>
        </div>
        <div className="flex items-center gap-2">
          <input
            type="url"
            value={importUrl}
            onChange={(e) => setImportUrl(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleImportUrl()}
            placeholder="输入网页 URL..."
            className="w-48 px-3 py-2 border border-[var(--cool-gray)] rounded-lg text-xs focus:outline-none focus:ring-1 focus:ring-[var(--soft-violet)]"
          />
          <button
            onClick={handleImportUrl}
            disabled={importing || !importUrl.trim()}
            className="px-3 py-2 bg-[var(--path-teal)] text-white rounded-lg text-xs font-semibold hover:opacity-90 disabled:opacity-40 whitespace-nowrap"
          >
            {importing ? "导入中..." : "导入网页"}
          </button>
          <label className={`px-4 py-2 bg-[var(--deep-indigo)] text-white rounded-lg text-sm font-semibold cursor-pointer hover:opacity-90 transition-colors ${uploading ? "opacity-50" : ""}`}>
            {uploading ? "上传中..." : "上传文件"}
            <input type="file" accept=".pdf,.txt,.md,.markdown,.docx,.pptx" onChange={handleUpload} className="hidden" disabled={uploading} />
          </label>
        </div>
      </div>

      {error && <p className="text-sm text-red-500 mb-4">{error}</p>}

      {loading ? (
        <p className="text-sm text-[var(--tertiary-text)]">加载中...</p>
      ) : docs.length === 0 ? (
        <div className="bg-white p-10 rounded-xl border border-dashed border-[var(--cool-gray)] text-center">
          <p className="text-sm text-[var(--secondary-text)]">还没有资料。上传 PDF、TXT 或 Markdown 文件开始。</p>
        </div>
      ) : (
        <div className="space-y-2">
          {docs.map((doc: any) => (
            <div key={doc.id} className="flex items-center gap-4 bg-white p-4 rounded-lg border border-[var(--cool-gray)]">
              <span className="text-lg">{doc.file_type === "pdf" ? "📄" : "📝"}</span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-[var(--primary-text)] truncate">{doc.title}</p>
                <p className="text-[10px] text-[var(--tertiary-text)]">{doc.file_type.toUpperCase()} · {doc.reading_status}</p>
              </div>
              <button onClick={() => navigate(`/reader/${doc.id}`)} className="text-xs text-[var(--deep-indigo)] hover:underline">打开</button>
              <button onClick={() => handleDelete(doc.id)} className="text-xs text-red-400 hover:text-red-600">删除</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
