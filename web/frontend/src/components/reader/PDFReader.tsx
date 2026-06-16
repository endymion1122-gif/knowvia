import { useState, useCallback } from "react";
import { Document, Page, pdfjs } from "react-pdf";
import type { Document as DocType } from "../../types";
pdfjs.GlobalWorkerOptions.workerSrc = `https://unpkg.com/pdfjs-dist@${pdfjs.version}/build/pdf.worker.min.mjs`;

interface PDFReaderProps {
  document: DocType;
  onTextSelect: (text: string, page: number) => void;
}

export function PDFReader({ document: doc, onTextSelect }: PDFReaderProps) {
  const [numPages, setNumPages] = useState(0);
  const [pageNumber, setPageNumber] = useState(doc.last_read_page || 1);
  const [scale, setScale] = useState(1.2);

  const onDocumentLoad = useCallback(({ numPages }: { numPages: number }) => {
    setNumPages(numPages);
  }, []);

  const handleTextSelection = () => {
    const selection = window.getSelection();
    if (selection && selection.toString().trim()) {
      onTextSelect(selection.toString().trim(), pageNumber);
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Toolbar */}
      <div className="flex items-center gap-4 px-4 py-2 bg-[var(--sidebar-bg)] border-b border-[var(--border-default)]">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setPageNumber((p) => Math.max(1, p - 1))}
            disabled={pageNumber <= 1}
            className="px-2 py-1 text-xs bg-white border border-[var(--border-default)] rounded hover:bg-[var(--page-bg)] disabled:opacity-30"
          >
            ‹
          </button>
          <span className="text-xs tabular-nums text-[var(--text-secondary)]">
            <input
              type="number" min={1} max={numPages} value={pageNumber}
              onChange={(e) => {
                const v = parseInt(e.target.value);
                if (v >= 1 && v <= numPages) setPageNumber(v);
              }}
              className="w-10 text-center border border-[var(--border-default)] rounded text-xs py-0.5"
            />
            <span className="mx-1">/</span>{numPages}
          </span>
          <button
            onClick={() => setPageNumber((p) => Math.min(numPages, p + 1))}
            disabled={pageNumber >= numPages}
            className="px-2 py-1 text-xs bg-white border border-[var(--border-default)] rounded hover:bg-[var(--page-bg)] disabled:opacity-30"
          >
            ›
          </button>
        </div>

        <div className="flex items-center gap-1 ml-auto">
          <button onClick={() => setScale((s) => Math.max(0.5, s - 0.1))} className="px-2 py-1 text-xs bg-white border rounded">−</button>
          <span className="text-[10px] text-[var(--text-tertiary)] w-10 text-center">{Math.round(scale * 100)}%</span>
          <button onClick={() => setScale((s) => Math.min(2.5, s + 0.1))} className="px-2 py-1 text-xs bg-white border rounded">+</button>
        </div>
      </div>

      {/* PDF Canvas */}
      <div className="flex-1 overflow-auto bg-[var(--border-default)] flex justify-center p-4" onMouseUp={handleTextSelection}>
        <Document file={`/uploads/${doc.file_path.split("/").pop()}`} onLoadSuccess={onDocumentLoad} className="shadow-lg">
          <Page pageNumber={pageNumber} scale={scale} />
        </Document>
      </div>
    </div>
  );
}
