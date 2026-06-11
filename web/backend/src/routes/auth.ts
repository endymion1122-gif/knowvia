import { Router, Request, Response } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { v4 as uuid } from "uuid";
import { getDb } from "../db/schema.js";
import { generateToken } from "../middleware/auth.js";

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || "knowvia-dev-secret-change-in-production";

// POST /api/auth/register
router.post("/register", (req: Request, res: Response) => {
  const { username, password } = req.body;
  if (!username || !password) {
    res.status(400).json({ error: "用户名和密码不能为空" });
    return;
  }
  if (password.length < 6) {
    res.status(400).json({ error: "密码至少6位" });
    return;
  }

  const db = getDb();
  const existing = db.prepare("SELECT id FROM users WHERE username = ?").get(username);
  if (existing) {
    res.status(409).json({ error: "用户名已被使用" });
    return;
  }

  const id = uuid();
  const hash = bcrypt.hashSync(password, 10);
  db.prepare("INSERT INTO users (id, username, password_hash) VALUES (?, ?, ?)").run(id, username, hash);

  const token = generateToken(id);
  res.json({ token, user: { id, username } });
});

// POST /api/auth/login
router.post("/login", (req: Request, res: Response) => {
  const { username, password } = req.body;
  if (!username || !password) {
    res.status(400).json({ error: "用户名和密码不能为空" });
    return;
  }

  const db = getDb();
  const user = db.prepare("SELECT * FROM users WHERE username = ?").get(username) as any;
  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    res.status(401).json({ error: "用户名或密码错误" });
    return;
  }

  const token = generateToken(user.id);
  res.json({ token, user: { id: user.id, username: user.username } });
});

// GET /api/auth/me
router.get("/me", (req: Request, res: Response) => {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "未登录" });
    return;
  }

  try {
    const payload = jwt.verify(header.slice(7), JWT_SECRET) as { userId: string };
    const db = getDb();
    const user = db.prepare("SELECT id, username, created_at FROM users WHERE id = ?").get(payload.userId) as any;
    if (!user) {
      res.status(404).json({ error: "用户不存在" });
      return;
    }
    res.json({ user });
  } catch {
    res.status(401).json({ error: "登录已过期" });
  }
});

export default router;
