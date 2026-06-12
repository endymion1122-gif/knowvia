/**
 * Document Converter — wraps Microsoft MarkItDown for multi-format → Markdown conversion.
 *
 * Requires: pip install 'markitdown[all]'
 *
 * Pipeline: PDF/Word/PPT/Excel/HTML → Markdown → structure segmentation → AI extraction → knowledge pathway
 */
import { execFile } from "child_process";
import { promisify } from "util";
import fs from "fs";
import path from "path";

const execAsync = promisify(execFile);

/** Formats supported by MarkItDown */
export const CONVERTIBLE_FORMATS = [
  ".pdf", ".docx", ".pptx", ".xlsx", ".xls",
  ".html", ".htm", ".csv", ".json", ".xml",
  ".ipynb", ".epub", ".zip",
];

export interface ConvertResult {
  markdown: string;
  error?: string;
}

/**
 * Convert a file to Markdown using the MarkItDown CLI.
 * Returns markdown string or empty string on failure.
 */
export async function convertToMarkdown(filePath: string): Promise<ConvertResult> {
  const ext = path.extname(filePath).toLowerCase();

  // Skip conversion for plain text formats that are already markdown-like
  if ([".txt", ".md", ".markdown"].includes(ext)) {
    try {
      const content = fs.readFileSync(filePath, "utf-8");
      return { markdown: content };
    } catch (e: any) {
      return { markdown: "", error: e.message };
    }
  }

  // Check if markitdown is available
  try {
    await execAsync("markitdown", ["--version"], { timeout: 5000 });
  } catch {
    return {
      markdown: "",
      error: "MarkItDown 未安装。请运行: pip install 'markitdown[all]'",
    };
  }

  // Convert using markitdown CLI
  try {
    const { stdout } = await execAsync("markitdown", [filePath], {
      timeout: 60000,
      maxBuffer: 10 * 1024 * 1024, // 10MB
    });
    return { markdown: stdout };
  } catch (e: any) {
    return { markdown: "", error: `MarkItDown 转换失败: ${e.message}` };
  }
}

/**
 * Check if a format can be converted by MarkItDown.
 * Plain text formats are handled natively.
 */
export function isConvertible(fileName: string): boolean {
  const ext = path.extname(fileName).toLowerCase();
  return CONVERTIBLE_FORMATS.includes(ext) ||
    [".txt", ".md", ".markdown"].includes(ext);
}
