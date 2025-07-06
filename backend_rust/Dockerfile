# Build stage
FROM rust:latest as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./
COPY shared/Cargo.toml shared/
COPY api-server/Cargo.toml api-server/
COPY websocket-server/Cargo.toml websocket-server/

# Create dummy source files to cache dependencies
RUN mkdir -p shared/src api-server/src websocket-server/src && \
    echo "fn main() {}" > api-server/src/main.rs && \
    echo "fn main() {}" > websocket-server/src/main.rs && \
    echo "pub fn init() {}" > shared/src/lib.rs

# Build dependencies only
RUN cargo build --release

# Copy actual source code
COPY shared/src shared/src
COPY api-server/src api-server/src
COPY websocket-server/src websocket-server/src
COPY migrations migrations

# Clean and rebuild with actual source
RUN touch shared/src/lib.rs api-server/src/main.rs websocket-server/src/main.rs && \
    cargo build --release

# Runtime stage for API server
FROM debian:bookworm-slim as api-runtime

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/api-server /app/
COPY migrations /app/migrations

ENV RUST_LOG=info
ENV APP__APP__ENVIRONMENT=production

EXPOSE 8000

CMD ["./api-server"]

# Runtime stage for WebSocket server
FROM debian:bookworm-slim as ws-runtime

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/websocket-server /app/

ENV RUST_LOG=info
ENV APP__APP__ENVIRONMENT=production

EXPOSE 8001

CMD ["./websocket-server"]