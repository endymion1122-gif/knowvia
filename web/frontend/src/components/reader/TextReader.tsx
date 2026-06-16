import { useState, useEffect, useCallback } from "react";
import type { Document as DocType } from "../../types";

interface TextReaderProps {
  document: DocType;
  onTextSelect: (text: string, page: number) => void;
}

export function TextReader({ document: doc, onTextSelect }: TextReaderProps) {
  const [content, setContent] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const token = localStorage.getItem("token");

  useEffect(() => {
    const fileName = doc.file_path.split("/").pop();
    fetch(`/uploads/${fileName}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then(async (res) => {
        if (!res.ok) throw new Error("加载文件失败");
        return res.text();
      })
      .then((text) => {
        setContent(text);
        setLoading(false);
      })
      .catch((e) => {
        setError(e.message);
        setLoading(false);
      });
  }, [doc.file_path, token]);

  const handleTextSelection = useCallback(() => {
    const selection = window.getSelection();
    if (selection && selection.toString().trim()) {
      onTextSelect(selection.toString().trim(), 0);
    }
  }, [onTextSelect]);

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center bg-[var(--page-bg)]">
        <p className="text-sm text-[var(--text-tertiary)]">加载文件中...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex-1 flex items-center justify-center bg-[var(--page-bg)]">
        <p className="text-sm text-red-500">{error}</p>
      </div>
    );
  }

  const isMarkdown = doc.file_type === "md";

  return (
    <div className="flex-1 overflow-auto bg-[var(--page-bg)]">
      {isMarkdown ? (
        <MarkdownContent content={content} onMouseUp={handleTextSelection} />
      ) : (
        <div
          className="p-8 max-w-3xl mx-auto bg-white min-h-full"
          onMouseUp={handleTextSelection}
        >
          <h1 className="text-xl font-semibold text-[var(--brand-navy)] mb-6 pb-3 border-b border-[var(--border-default)]">
            {doc.title}
          </h1>
          <pre className="text-sm text-[var(--text-primary)] whitespace-pre-wrap font-sans leading-relaxed select-text">
            {content}
          </pre>
        </div>
      )}
    </div>
  );
}

/** Minimal markdown renderer — headings, bold, italic, lists, code, blockquote */
function MarkdownContent({
  content,
  onMouseUp,
}: {
  content: string;
  onMouseUp: () => void;
}) {
  const html = renderMarkdown(content);
  return (
    <div
      className="p-8 max-w-3xl mx-auto bg-white min-h-full select-text"
      onMouseUp={onMouseUp}
    >
      <div
        className="prose prose-sm prose-stone max-w-none [&_h1]:text-xl [&_h1]:font-semibold [&_h1]:text-[var(--brand-navy)] [&_h1]:mb-4 [&_h2]:text-lg [&_h2]:font-semibold [&_h2]:text-[var(--text-secondary)] [&_h2]:mt-6 [&_h2]:mb-3 [&_h3]:text-base [&_h3]:font-semibold [&_h3]:text-[var(--text-primary)] [&_h3]:mt-4 [&_h3]:mb-2 [&_p]:text-sm [&_p]:text-[var(--text-primary)] [&_p]:leading-relaxed [&_p]:my-2 [&_strong]:font-semibold [&_em]:italic [&_code]:bg-[var(--surface-lavender)] [&_code]:px-1 [&_code]:py-0.5 [&_code]:rounded [&_code]:text-xs [&_pre]:bg-[var(--border-default)] [&_pre]:p-4 [&_pre]:rounded-lg [&_pre]:overflow-auto [&_pre]:text-xs [&_blockquote]:border-l-2 [&_blockquote]:border-[var(--brand-violet)] [&_blockquote]:pl-4 [&_blockquote]:text-[var(--text-secondary)] [&_blockquote]:text-sm [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5 [&_li]:text-sm [&_li]:text-[var(--text-primary)] [&_li]:my-1 [&_hr]:border-[var(--border-default)] [&_hr]:my-6 [&_a]:text-[var(--brand-violet)] [&_a]:underline"
        dangerouslySetInnerHTML={{ __html: html }}
      />
    </div>
  );
}

function renderMarkdown(text: string): string {
  let html = text
    // Escape HTML
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  // Code blocks (fenced)
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_m, lang, code) => {
    return `<pre><code class="language-${lang}">${code.trim()}</code></pre>`;
  });

  // Inline code
  html = html.replace(/`([^`]+)`/g, "<code>$1</code>");

  // Headings
  html = html.replace(/^#### (.+)$/gm, "<h4>$1</h4>");
  html = html.replace(/^### (.+)$/gm, "<h3>$1</h3>");
  html = html.replace(/^## (.+)$/gm, "<h2>$1</h2>");
  html = html.replace(/^# (.+)$/gm, "<h1>$1</h1>");

  // Bold + italic
  html = html.replace(/\*\*\*(.+?)\*\*\*/g, "<strong><em>$1</em></strong>");
  html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/\*(.+?)\*/g, "<em>$1</em>");

  // Images
  html = html.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img alt="$1" src="$2" class="max-w-full rounded" />');

  // Links
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');

  // Blockquotes
  html = html.replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>");

  // Horizontal rules
  html = html.replace(/^---$/gm, "<hr />");

  // Unordered lists
  html = html.replace(/^[\-\*] (.+)$/gm, "<li>$1</li>");
  // Ordered lists
  html = html.replace(/^\d+\. (.+)$/gm, "<li>$1</li>");
  // Wrap consecutive <li> in <ul>/<ol>
  html = html.replace(/(<li>.*?<\/li>)\n(?=<li>)/g, "$1");
  html = html.replace(/((?:<li>[^<]*<\/li>\n?)+)/g, "<ul>$1</ul>");

  // Paragraphs: wrap remaining text lines
  html = html.replace(/\n\n+/g, "</p><p>");
  html = "<p>" + html + "</p>";
  // Clean empty paragraphs
  html = html.replace(/<p>\s*<\/p>/g, "");
  // Fix blockquote wrapping
  html = html.replace(/<p><blockquote>/g, "<blockquote><p>");
  html = html.replace(/<\/blockquote><\/p>/g, "</p></blockquote>");

  return html;
}
