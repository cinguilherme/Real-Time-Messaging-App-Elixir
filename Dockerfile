# Dockerfile for Production Deployment
# Multi-stage build for efficient image size

# ============================================
# Stage 1: Build Stage
# ============================================
FROM hexpm/elixir:1.19.0-erlang-27.2-alpine-3.21.3 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Set build environment
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config
COPY apps/messaging_api/mix.exs apps/messaging_api/
COPY apps/messaging_core/mix.exs apps/messaging_core/
COPY apps/job_processor/mix.exs apps/job_processor/

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application source
COPY apps apps

# Compile the application
RUN mix compile

# Build the release
RUN mix release messaging_api

# ============================================
# Stage 2: Runtime Stage
# ============================================
FROM alpine:3.21.3 AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc \
    bash

# Create app user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

# Set working directory
WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/messaging_api ./

# Copy default features configuration
RUN mkdir -p /etc/app
COPY --chown=app:app config/features.yaml /etc/app/features.yaml

# Create storage directory for local blob storage
RUN mkdir -p /app/priv/storage && \
    chown -R app:app /app/priv/storage

# Switch to non-root user
USER app

# Expose port
EXPOSE 4000

# Set default environment variables
ENV PORT=4000 \
    MIX_ENV=prod \
    FEATURES_CONFIG=/etc/app/features.yaml

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/api/health || exit 1

# Start the application
CMD ["bin/messaging_api", "start"]
