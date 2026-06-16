import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../services/api";
import { Card } from "../components/common/Card";
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

  const loadDocs = useCallback(async () => {
    try { const { documents } = await api.documents.list(); setDocs(documents); }
    catch (e: any) { setError(e.message); } finally { setLoading(false); }
  }, []);
  useEffect(() => { loadDocs(); }, [loadDocs]);

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]; if (!file) return;
    setUploading(true); setError("");
    try { await api.documents.upload(file); await loadDocs(); } catch (err: any) { setError(err.message); }
    finally { setUploading(false); }
  };

  const handleImportUrl = async () => {
    if (!importUrl.trim()) return;
    setImporting(true); setError("");
    try { await api.documents.importUrl(importUrl.trim()); setImportUrl(""); await loadDocs(); }
    catch (err: any) { setError(err.message); } finally { setImporting(false); }
  };

  const handleSaveMetadata = async (id: string) => {
    try { await api.documents.update(id, { author: editAuthor, publication_year: editYear ? parseInt(editYear) : null, source_note: editNote }); setEditingDoc(null); await loadDocs(); }
    catch (err: any) { setError(err.message); }
  };

  const startEdit = (doc: any) => { setEditingDoc(doc.id); setEditAuthor(doc.author || ""); setEditYear(doc.publication_year?.toString() || ""); setEditNote(doc.source_note || ""); };

  return (
    <div className="p-6 md:p-10 max-w-6xl mx-auto">
      <div className="flex flex-wrap items-end justify-between gap-4 mb-8">
        <div>
          <h2 className="text-[28px] font-bold text-[var(--text-primary)] tracking-tight">资料库</h2>
          <p className="text-[13px] text-[var(--text-tertiary)] mt-1">PDF · Word · PPT · Markdown · 网页链接</p>
        </div>
        <div className="flex items-center gap-2">
          <input type="url" value={importUrl} onChange={e => setImportUrl(e.target.value)} onKeyDown={e => e.key === "Enter" && handleImportUrl()}
            placeholder="输入网页 URL 导入..." className="w-48 h-9 px-3 bg-white border border-[var(--border-default)] rounded-xl text-xs placeholder:text-[var(--text-placeholder)] focus:outline-none focus:border-[var(--brand-violet)] focus:shadow-[var(--shadow-glow-violet)] transition-all" />
          <button onClick={handleImportUrl} disabled={importing || !importUrl.trim()}
            className="h-9 px-3 bg-[var(--brand-teal)] text-white rounded-xl text-xs font-medium hover:opacity-90 disabled:opacity-40 transition-opacity">导入网页</button>
          <label className={`h-9 px-4 flex items-center bg-[var(--brand-indigo)] text-white rounded-xl text-xs font-semibold cursor-pointer hover:opacity-90 transition-opacity ${uploading ? "opacity-50" : ""}`}>
            {uploading ? "上传中..." : "上传文件"}
            <input type="file" accept=".pdf,.txt,.md,.markdown,.docx,.pptx" onChange={handleUpload} className="hidden" disabled={uploading} />
          </label>
        </div>
      </div>

      {error && <p className="text-sm text-red-500 mb-4">{error}</p>}

      {loading ? <p className="text-sm text-[var(--text-tertiary)]">加载中...</p>
      : docs.length === 0 ? (
        <div className="text-center py-20">
          <div className="text-5xl mb-4">📚</div>
          <p className="text-sm text-[var(--text-secondary)]">还没有资料</p>
          <p className="text-xs text-[var(--text-tertiary)] mt-2">上传 PDF、TXT 或 Markdown 文件开始</p>
        </div>
      ) : (
        <div className="space-y-2">
          {docs.map((doc: any) => (
            <Card key={doc.id} padding="md">
              <div className="flex items-start gap-3">
                <span className="text-xl flex-shrink-0 mt-0.5">{doc.file_type === "pdf" ? "📄" : doc.file_type === "md" ? "📝" : "📃"}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-[15px] font-semibold text-[var(--text-primary)] truncate">{doc.title}</p>
                  <div className="flex flex-wrap items-center gap-x-3 gap-y-0.5 mt-1">
                    <span className="text-[11px] text-[var(--text-tertiary)]">{doc.file_type.toUpperCase()}</span>
                    {doc.author && <span className="text-[11px] text-[var(--primary-600)]">✍ {doc.author}</span>}
                    {doc.publication_year && <span className="text-[11px] text-[var(--primary-600)]">📅 {doc.publication_year}</span>}
                    {doc.source_url && <span className="text-[11px] text-[var(--brand-teal)] truncate max-w-[160px]">🔗</span>}
                  </div>
                </div>
                <div className="flex items-center gap-1 flex-shrink-0">
                  <button onClick={() => navigate(`/reader/${doc.id}`)} className="text-xs text-[var(--brand-indigo)] hover:underline font-medium">打开</button>
                  <button onClick={() => startEdit(doc)} className="text-xs text-[var(--primary-600)] hover:underline">编辑</button>
                  <button onClick={async () => { if (confirm("确定删除？")) { await api.documents.delete(doc.id); await loadDocs(); } }} className="text-xs text-[var(--error)] hover:underline">删除</button>
                </div>
              </div>
              {editingDoc === doc.id && (
                <div className="mt-3 pt-3 border-t border-[var(--border-light)] grid grid-cols-3 gap-2">
                  <div><label className="text-[11px] text-[var(--text-secondary)]">作者</label><input value={editAuthor} onChange={e => setEditAuthor(e.target.value)} className="w-full mt-0.5 px-2 py-1.5 border border-[var(--border-default)] rounded-lg text-xs focus:outline-none focus:border-[var(--brand-violet)]" placeholder="如: Sweller" /></div>
                  <div><label className="text-[11px] text-[var(--text-secondary)]">年份</label><input value={editYear} onChange={e => setEditYear(e.target.value)} className="w-full mt-0.5 px-2 py-1.5 border border-[var(--border-default)] rounded-lg text-xs focus:outline-none focus:border-[var(--brand-violet)]" placeholder="如: 1988" type="number" /></div>
                  <div><label className="text-[11px] text-[var(--text-secondary)]">备注</label><input value={editNote} onChange={e => setEditNote(e.target.value)} className="w-full mt-0.5 px-2 py-1.5 border border-[var(--border-default)] rounded-lg text-xs focus:outline-none focus:border-[var(--brand-violet)]" placeholder="可信度、主要贡献等" /></div>
                  <div className="col-span-3 flex gap-2 justify-end mt-1">
                    <button onClick={() => handleSaveMetadata(doc.id)} className="px-3 py-1.5 bg-[var(--brand-violet)] text-white text-xs rounded-lg font-medium">保存</button>
                    <button onClick={() => setEditingDoc(null)} className="px-3 py-1.5 text-xs text-[var(--text-tertiary)]">取消</button>
                  </div>
                </div>
              )}
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
