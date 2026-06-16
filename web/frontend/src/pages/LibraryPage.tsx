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
  const [editingDoc, setEditingDoc] = useState<string | null>(null);
  const [editAuthor, setEditAuthor] = useState("");
  const [editYear, setEditYear] = useState("");
  const [editNote, setEditNote] = useState("");
  const [viewMode, setViewMode] = useState<"list" | "grid">("list");

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

  const handleSaveMetadata = async (id: string) => {
    try {
      await api.documents.update(id, {
        author: editAuthor,
        publication_year: editYear ? parseInt(editYear) : null,
        source_note: editNote,
      });
      setEditingDoc(null);
      await loadDocs();
    } catch (err: any) { setError(err.message); }
  };

  const startEdit = (doc: any) => {
    setEditingDoc(doc.id);
    setEditAuthor(doc.author || "");
    setEditYear(doc.publication_year?.toString() || "");
    setEditNote(doc.source_note || "");
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
          <h2 className="text-2xl font-semibold text-[var(--brand-indigo)]">资料库</h2>
          <p className="text-xs text-[var(--text-tertiary)] mt-1">支持 PDF、Word、PPT、TXT、Markdown、网页链接</p>
        </div>
        <div className="flex items-center gap-2">
          <input
            type="url"
            value={importUrl}
            onChange={(e) => setImportUrl(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleImportUrl()}
            placeholder="输入网页 URL..."
            className="w-48 px-3 py-2 border border-[var(--border-default)] rounded-lg text-xs focus:outline-none focus:ring-1 focus:ring-[var(--brand-violet)]"
          />
          <button
            onClick={handleImportUrl}
            disabled={importing || !importUrl.trim()}
            className="px-3 py-2 bg-[var(--brand-teal)] text-white rounded-lg text-xs font-semibold hover:opacity-90 disabled:opacity-40 whitespace-nowrap"
          >
            {importing ? "导入中..." : "导入网页"}
          </button>
          <label className={`px-4 py-2 bg-[var(--brand-indigo)] text-white rounded-lg text-sm font-semibold cursor-pointer hover:opacity-90 transition-colors ${uploading ? "opacity-50" : ""}`}>
            {uploading ? "上传中..." : "上传文件"}
            <input type="file" accept=".pdf,.txt,.md,.markdown,.docx,.pptx" onChange={handleUpload} className="hidden" disabled={uploading} />
          </label>
        </div>
      </div>

      {error && <p className="text-sm text-red-500 mb-4">{error}</p>}

      {loading ? (
        <p className="text-sm text-[var(--text-tertiary)]">加载中...</p>
      ) : docs.length === 0 ? (
        <div className="bg-white p-10 rounded-xl border border-dashed border-[var(--border-default)] text-center">
          <p className="text-sm text-[var(--text-secondary)]">还没有资料。上传 PDF、TXT 或 Markdown 文件开始。</p>
        </div>
      ) : (
        <>
          <div className="flex items-center gap-2 mb-3">
            <button onClick={() => setViewMode("list")} className={`text-xs px-2 py-1 rounded ${viewMode === "list" ? "bg-[var(--brand-indigo)] text-white" : "bg-white text-[var(--text-secondary)] border"}`}>列表</button>
            <button onClick={() => setViewMode("grid")} className={`text-xs px-2 py-1 rounded ${viewMode === "grid" ? "bg-[var(--brand-indigo)] text-white" : "bg-white text-[var(--text-secondary)] border"}`}>网格</button>
          </div>
          <div className={viewMode === "grid" ? "grid grid-cols-2 md:grid-cols-3 gap-3" : "space-y-2"}>
          {docs.map((doc: any) => (
            <div key={doc.id} className={`bg-white rounded-lg border border-[var(--border-default)] ${viewMode === "grid" ? "p-3" : "p-4 flex items-center gap-4"}`}>
              <span className="text-lg flex-shrink-0">{doc.file_type === "pdf" ? "📄" : doc.file_type === "md" ? "📝" : "📃"}</span>
              <div className={`${viewMode === "grid" ? "mt-2" : "flex-1 min-w-0"}`}>
                <p className="text-sm font-medium text-[var(--text-primary)] truncate">{doc.title}</p>
                <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5 mt-0.5">
                  <span className="text-[10px] text-[var(--text-tertiary)]">{doc.file_type.toUpperCase()}</span>
                  {doc.author && <span className="text-[10px] text-[var(--text-secondary)]">✍ {doc.author}</span>}
                  {doc.publication_year && <span className="text-[10px] text-[var(--text-secondary)]">📅 {doc.publication_year}</span>}
                  {doc.source_url && <span className="text-[10px] text-[var(--brand-teal)] truncate max-w-[120px]">🔗</span>}
                </div>
              </div>
              <div className={`flex items-center gap-1 flex-shrink-0 ${viewMode === "grid" ? "mt-2 justify-end" : ""}`}>
                <button onClick={() => navigate(`/reader/${doc.id}`)} className="text-xs text-[var(--brand-indigo)] hover:underline">打开</button>
                <button onClick={() => startEdit(doc)} className="text-xs text-[var(--text-secondary)] hover:underline">编辑</button>
                <button onClick={() => handleDelete(doc.id)} className="text-xs text-red-400 hover:text-red-600">删除</button>
              </div>

              {/* Inline edit form */}
              {editingDoc === doc.id && (
                <div className={`${viewMode === "grid" ? "col-span-full mt-2" : "mt-2"} w-full bg-[var(--bg-page)] p-3 rounded-lg border border-[var(--brand-violet)] grid grid-cols-3 gap-2`}>
                  <div>
                    <label className="text-[10px] text-[var(--text-secondary)]">作者</label>
                    <input value={editAuthor} onChange={(e) => setEditAuthor(e.target.value)}
                      className="w-full px-2 py-1 border rounded text-xs mt-0.5" placeholder="如: Sweller" />
                  </div>
                  <div>
                    <label className="text-[10px] text-[var(--text-secondary)]">年份</label>
                    <input value={editYear} onChange={(e) => setEditYear(e.target.value)}
                      className="w-full px-2 py-1 border rounded text-xs mt-0.5" placeholder="如: 1988" type="number" />
                  </div>
                  <div>
                    <label className="text-[10px] text-[var(--text-secondary)]">来源备注</label>
                    <input value={editNote} onChange={(e) => setEditNote(e.target.value)}
                      className="w-full px-2 py-1 border rounded text-xs mt-0.5" placeholder="可信度、主要贡献等" />
                  </div>
                  <div className="col-span-3 flex gap-2 justify-end mt-1">
                    <button onClick={() => handleSaveMetadata(doc.id)}
                      className="px-3 py-1 bg-[var(--brand-indigo)] text-white text-xs rounded">保存</button>
                    <button onClick={() => setEditingDoc(null)}
                      className="px-3 py-1 text-xs text-[var(--text-tertiary)]">取消</button>
                  </div>
                </div>
              )}
            </div>
          ))}
          </div>
        </>
      )}
    </div>
  );
}
