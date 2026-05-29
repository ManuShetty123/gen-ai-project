# ──────────────────────────────────────────────
# Stage 1: BUILD
# Install ALL dependencies (including devDependencies)
# and compile/build the application
# ──────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files first (layer caching: only re-installs if these change)
COPY package*.json ./

# Install all dependencies including devDependencies needed for build
RUN npm ci

# Copy the rest of the source code
COPY . .

# Run build step (compiles TypeScript, bundles, etc.)
# Remove this line if your app doesn't have a build step
RUN npm run build --if-present


# ──────────────────────────────────────────────
# Stage 2: PRODUCTION IMAGE
# Only copies the built output and prod dependencies
# Result: a small, secure image with no dev tools
# ──────────────────────────────────────────────
FROM node:20-alpine AS production

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ONLY production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# Copy built application from the builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src  ./src

# Set correct ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Document the port (does NOT publish it — that's done in docker run)
EXPOSE 3000

# Health check: Docker will mark the container unhealthy if this fails
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start the application
CMD ["node", "src/index.js"]
