# ── Build stage ───────────────────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS runtime
WORKDIR /app

# Create data directories for cache and prefs
RUN mkdir -p /data/cache /data/prefs

# Copy only what's needed
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/server.js    ./server.js
COPY --from=build /app/src          ./src

# Non-root user for security
RUN addgroup -S wt && adduser -S wt -G wt
RUN chown -R wt:wt /app /data
USER wt

ENV PORT=8080
ENV CACHE_DIR=/data/cache
ENV PREFS_DIR=/data/prefs

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/api/ping || exit 1

CMD ["node", "server.js"]
