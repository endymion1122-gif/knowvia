# 知径 Knowvia Web MVP

AI 增强型多源知识路径生成系统 · Web 研究原型

## 技术栈

- **前端**: React + TypeScript + Vite + Tailwind CSS
- **后端**: Express.js + SQLite (better-sqlite3)
- **认证**: JWT + bcrypt

## 运行方式

### 后端
```bash
cd backend
npm install
npm run dev          # http://localhost:3001
```

### 前端
```bash
cd frontend
npm install
npm run dev          # http://localhost:5173
```

访问 `http://localhost:5173` 即可使用。Vite 代理自动将 `/api` 请求转发到后端。

### 生产部署
```bash
# 构建前端
cd frontend && npm run build

# 启动后端（自动 serve 前端静态文件）
cd backend && npm start    # http://localhost:3001
```

## 项目结构
```
web/
  frontend/
    src/
      components/layout/    # MainLayout, Sidebar
      pages/                # 路由页面
      services/api.ts       # API 客户端
      stores/authStore.ts   # 认证状态 (Zustand)
      types/index.ts        # TypeScript 类型定义
      styles/index.css      # 设计系统
  backend/
    src/
      db/schema.ts          # SQLite schema
      middleware/auth.ts    # JWT 认证中间件
      routes/               # API 路由
      index.ts              # Express 入口
```

## API 端点

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| POST | /api/auth/register | 无 | 注册 |
| POST | /api/auth/login | 无 | 登录 |
| GET | /api/auth/me | JWT | 当前用户 |
| GET | /api/documents | JWT | 资料列表 |
| POST | /api/documents/upload | JWT | 上传资料 |
| PATCH | /api/documents/:id | JWT | 更新资料 |
| DELETE | /api/documents/:id | JWT | 删除资料 |
