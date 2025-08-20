# Multi-stage Docker build for Kyozo API
ARG ELIXIR_VERSION=1.16
ARG OTP_VERSION=26
ARG DEBIAN_VERSION=bullseye-20230612-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ===== BUILDER STAGE =====
FROM ${BUILDER_IMAGE} as builder

# Install system dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    pkg-config \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Rust for NIF compilation
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Node.js 20 and pnpm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm@latest \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV="prod"
ENV NODE_ENV="production"

# Copy dependency files for better caching
COPY mix.exs mix.lock ./
COPY assets/package.json assets/pnpm-lock.yaml ./assets/

# Install Elixir dependencies
RUN mix deps.get --only $MIX_ENV

# Create config directory and copy compile-time configs
RUN mkdir -p config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Install Node.js dependencies
WORKDIR /app/assets
RUN pnpm install --frozen-lockfile --production=false

# Back to app root
WORKDIR /app

# Copy and build native dependencies
COPY native ./native
WORKDIR /app/native/markdown_ld_nif
RUN cargo build --release

# Back to app root
WORKDIR /app

# Copy asset files and build frontend
COPY assets ./assets
WORKDIR /app/assets
RUN pnpm run build

# Back to app root for Elixir compilation
WORKDIR /app

# Copy application source
COPY priv priv
COPY lib lib
COPY rel rel

# Build assets and compile application
RUN mix assets.deploy
RUN mix compile

# Copy runtime configuration
COPY config/runtime.exs config/

# Build release
RUN mix release

# ===== RUNNER STAGE =====
FROM ${RUNNER_IMAGE}

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y \
    libstdc++6 \
    openssl \
    libncurses6 \
    locales \
    ca-certificates \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create app user and directory
RUN groupadd --gid 1001 app && \
    useradd --uid 1001 --gid app --shell /bin/bash --create-home app

WORKDIR /app
RUN chown app:app /app

# Set runtime environment
ENV MIX_ENV="prod"
ENV PHX_SERVER="true"

# Copy release from builder stage
COPY --from=builder --chown=app:app /app/_build/${MIX_ENV}/rel/kyozo ./

# Switch to non-root user
USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:4000/api/health || exit 1

# Default command
CMD ["/app/bin/server"]