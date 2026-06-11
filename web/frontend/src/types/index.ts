export interface User {
  id: string;
  username: string;
  created_at?: string;
}

export interface Document {
  id: string;
  user_id: string;
  title: string;
  file_type: "pdf" | "txt" | "md";
  file_path: string;
  tags: string[];
  reading_status: "unread" | "reading" | "completed";
  last_read_page?: number;
  author: string;
  publication_year?: number;
  source_url: string;
  source_note: string;
  summary?: string;
  page_count?: number;
  created_at: string;
  updated_at: string;
}

export interface Annotation {
  id: string;
  document_id: string;
  user_id: string;
  selected_text: string;
  note: string;
  page_number?: number;
  created_at: string;
}

export interface KnowledgeCard {
  id: string;
  user_id: string;
  title: string;
  content: string;
  card_type: CardKind;
  tags: string[];
  source_document_id?: string;
  source_document_title?: string;
  page_number?: number;
  pathway_ids?: string[];
  calibration_status: CalibrationStatus;
  is_highlighted: boolean;
  is_understood: boolean;
  calibration_note: string;
  last_reviewed_at?: string;
  next_review_at?: string;
  review_count: number;
  ease_factor: number;
  created_at: string;
  updated_at: string;
}

export type CardKind = "concept" | "quote" | "summary" | "method" | "argument" | "evidence" | "question" | "reflection" | "note";
export type CalibrationStatus = "pendingReview" | "confirmed" | "needsFollowUp";

export const CARD_KIND_LABELS: Record<CardKind, string> = {
  concept: "概念", quote: "摘录", summary: "摘要", method: "方法",
  argument: "观点", evidence: "证据", question: "问题", reflection: "反思", note: "笔记",
};

export const CALIBRATION_LABELS: Record<CalibrationStatus, string> = {
  pendingReview: "待核验", confirmed: "已确认", needsFollowUp: "需跟进",
};

export interface KnowledgePathway {
  id: string;
  user_id: string;
  title: string;
  overview: string;
  tags: string[];
  document_ids?: string[];
  card_ids?: string[];
  created_at: string;
  updated_at: string;
}

export interface KnowledgeRelation {
  id: string;
  pathway_id: string;
  source_card_id: string;
  target_card_id: string;
  relation_type: RelationKind;
  note: string;
  created_at: string;
}

export type RelationKind = "defines" | "supports" | "challenges" | "extends" | "related_to";

export const RELATION_KIND_LABELS: Record<RelationKind, string> = {
  defines: "定义", supports: "支持", challenges: "挑战", extends: "扩展", related_to: "相关",
};
