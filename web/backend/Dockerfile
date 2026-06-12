# ---- Build stage ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# ---- Production stage ----
FROM node:22-alpine
WORKDIR /app
RUN apk add --no-cache python3 py3-pip && pip3 install 'markitdown[all]' PyMuPDF --break-system-packages
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
RUN mkdir -p uploads
EXPOSE 3001
ENV NODE_ENV=production
ENV PORT=3001
CMD ["node", "dist/index.js"]
