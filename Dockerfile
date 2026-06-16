# ── Stage 1: Build Frontend ──
FROM node:22-alpine AS frontend-build
WORKDIR /app/web/frontend
COPY web/frontend/package.json web/frontend/package-lock.json ./
RUN npm ci
COPY web/frontend/ ./
RUN npm run build

# ── Stage 2: Build Backend ──
FROM node:22-alpine AS backend-build
WORKDIR /app/web/backend
COPY web/backend/package.json web/backend/package-lock.json ./
RUN npm ci
COPY web/backend/tsconfig.json ./
COPY web/backend/src/ ./src/
RUN npm run build

# ── Stage 3: Production ──
FROM node:22-alpine
WORKDIR /app

# Install Python + MarkItDown + PyMuPDF for document conversion
RUN apk add --no-cache python3 py3-pip && \
    pip3 install 'markitdown[all]' PyMuPDF --break-system-packages

# Copy backend production deps
COPY web/backend/package.json web/backend/package-lock.json ./
RUN npm ci --omit=dev

# Copy backend build output
COPY --from=backend-build /app/web/backend/dist ./dist

# Copy backend scripts for PDF extraction
COPY web/backend/scripts/ ./scripts/

# Copy frontend build output to be served statically
COPY --from=frontend-build /app/web/frontend/dist ./frontend-dist

# Create uploads directory
RUN mkdir -p uploads

EXPOSE 3001
ENV NODE_ENV=production
ENV PORT=3001
ENV JWT_SECRET=${JWT_SECRET:-knowvia-prod-change-me}

CMD ["node", "dist/index.js"]
