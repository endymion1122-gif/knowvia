# ── Stage 1: Build Frontend ──
FROM node:22-alpine AS frontend-build
WORKDIR /app/web/frontend
COPY web/frontend/package.json web/frontend/package-lock.json ./
RUN npm ci
COPY web/frontend/ ./
RUN npm run build

# ── Stage 2: Build Backend TypeScript ──
FROM node:22-alpine AS backend-build
WORKDIR /app/web/backend
COPY web/backend/package.json web/backend/package-lock.json ./
RUN npm ci
COPY web/backend/tsconfig.json ./
COPY web/backend/src/ ./src/
RUN npm run build

# ── Stage 3: Production ──
FROM node:22-slim
WORKDIR /app

# Build tools for native modules (better-sqlite3) + Python for doc conversion
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g node-gyp \
    && pip3 install --no-cache-dir 'markitdown[all]' PyMuPDF --break-system-packages

# Copy backend deps and compile native modules
COPY web/backend/package.json web/backend/package-lock.json ./
RUN npm ci --omit=dev

# Copy backend build output
COPY --from=backend-build /app/web/backend/dist ./dist

# Copy backend scripts
COPY web/backend/scripts/ ./scripts/

# Copy frontend build
COPY --from=frontend-build /app/web/frontend/dist ./frontend-dist

RUN mkdir -p uploads

EXPOSE 3001
ENV NODE_ENV=production
ENV PORT=3001

CMD ["node", "dist/index.js"]
