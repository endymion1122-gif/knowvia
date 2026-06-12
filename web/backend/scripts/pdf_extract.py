#!/usr/bin/env python3
"""
Advanced PDF text extraction using PyMuPDF (fitz).
Falls back to MarkItDown if PyMuPDF is unavailable.

Usage: python3 pdf_extract.py <file_path> [--format markdown|text]
Output: structured markdown or plain text to stdout
"""
import sys
import os
import json

def extract_with_pymupdf(filepath: str, fmt: str = "markdown") -> dict:
    """Extract text from PDF using PyMuPDF with structure preservation."""
    try:
        import fitz  # PyMuPDF
    except ImportError:
        return {"error": "PyMuPDF not installed. Run: pip install PyMuPDF", "method": "none"}

    try:
        doc = fitz.open(filepath)
        pages = []
        for i, page in enumerate(doc):
            if fmt == "markdown":
                # Use PyMuPDF's built-in markdown extraction
                md = page.get_text("markdown")
                if md.strip():
                    pages.append(f"## Page {i+1}\n\n{md}")
                else:
                    text = page.get_text("text")
                    pages.append(f"## Page {i+1}\n\n{text}")
            else:
                text = page.get_text("text")
                pages.append(text)

        doc.close()
        full_text = "\n\n".join(pages)

        # Basic metadata
        metadata = {
            "pages": len(pages),
            "format": fmt,
            "method": "pymupdf",
            "has_toc": bool(doc.toc) if hasattr(doc, 'toc') else False,
        }

        return {
            "markdown": full_text,
            "metadata": metadata,
        }
    except Exception as e:
        return {"error": str(e), "method": "pymupdf_error"}


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: pdf_extract.py <file_path> [--format markdown|text]"}))
        sys.exit(1)

    filepath = sys.argv[1]
    fmt = "markdown"
    if "--format" in sys.argv:
        idx = sys.argv.index("--format")
        if idx + 1 < len(sys.argv):
            fmt = sys.argv[idx + 1]

    if not os.path.exists(filepath):
        print(json.dumps({"error": f"File not found: {filepath}"}))
        sys.exit(1)

    result = extract_with_pymupdf(filepath, fmt)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
