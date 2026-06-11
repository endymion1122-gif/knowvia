import Database from "better-sqlite3";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = path.join(__dirname, "..", "..", "knowvia.db");

let db: Database.Database;

export function getDb(): Database.Database {
  if (!db) {
    db = new Database(DB_PATH);
    db.pragma("journal_mode = WAL");
    db.pragma("foreign_keys = ON");
    initSchema(db);
  }
  return db;
}

function initSchema(db: Database.Database) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS documents (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      title TEXT NOT NULL,
      file_type TEXT NOT NULL,
      file_path TEXT NOT NULL,
      tags TEXT DEFAULT '[]',
      reading_status TEXT DEFAULT 'unread',
      last_read_page INTEGER,
      author TEXT DEFAULT '',
      publication_year INTEGER,
      source_url TEXT DEFAULT '',
      source_note TEXT DEFAULT '',
      summary TEXT,
      page_count INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS annotations (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id),
      selected_text TEXT NOT NULL,
      note TEXT DEFAULT '',
      page_number INTEGER,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS knowledge_cards (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      card_type TEXT DEFAULT 'note',
      tags TEXT DEFAULT '[]',
      source_document_id TEXT REFERENCES documents(id) ON DELETE SET NULL,
      source_document_title TEXT,
      page_number INTEGER,
      calibration_status TEXT DEFAULT 'pendingReview',
      is_highlighted INTEGER DEFAULT 0,
      is_understood INTEGER DEFAULT 0,
      calibration_note TEXT DEFAULT '',
      last_reviewed_at TEXT,
      next_review_at TEXT,
      review_count INTEGER DEFAULT 0,
      ease_factor REAL DEFAULT 2.5,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS knowledge_pathways (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      title TEXT NOT NULL,
      overview TEXT DEFAULT '',
      tags TEXT DEFAULT '[]',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS pathway_documents (
      pathway_id TEXT NOT NULL REFERENCES knowledge_pathways(id) ON DELETE CASCADE,
      document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
      PRIMARY KEY (pathway_id, document_id)
    );

    CREATE TABLE IF NOT EXISTS pathway_cards (
      pathway_id TEXT NOT NULL REFERENCES knowledge_pathways(id) ON DELETE CASCADE,
      card_id TEXT NOT NULL REFERENCES knowledge_cards(id) ON DELETE CASCADE,
      PRIMARY KEY (pathway_id, card_id)
    );

    CREATE TABLE IF NOT EXISTS knowledge_relations (
      id TEXT PRIMARY KEY,
      pathway_id TEXT NOT NULL REFERENCES knowledge_pathways(id) ON DELETE CASCADE,
      source_card_id TEXT NOT NULL REFERENCES knowledge_cards(id) ON DELETE CASCADE,
      target_card_id TEXT NOT NULL REFERENCES knowledge_cards(id) ON DELETE CASCADE,
      relation_type TEXT NOT NULL,
      note TEXT DEFAULT '',
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);
}
