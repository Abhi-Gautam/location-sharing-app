# Build stage
FROM elixir:1.15-alpine as builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Set build environment
ENV MIX_ENV=prod

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy source code
COPY config config
COPY lib lib
COPY priv priv

# Compile the release
RUN mix compile

# Create release
RUN mix release

# Runtime stage
FROM alpine:3.18 as runtime

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++

# Create app user
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -S app -G app

WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/location_sharing ./

# Switch to app user
USER app

# Set environment
ENV PHX_HOST=0.0.0.0
ENV PHX_PORT=4000
ENV MIX_ENV=prod
ENV SECRET_KEY_BASE=change_me_in_production

EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD bin/location_sharing rpc ":observer_cli.help()" || exit 1

CMD ["bin/location_sharing", "start"]