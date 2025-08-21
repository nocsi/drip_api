# Multi-stage Docker build for Kyozo API
ARG ELIXIR_VERSION=1.16
ARG OTP_VERSION=26
ARG DEBIAN_VERSION=bookworm-20240513-slim
ARG NODE_VERSION=20

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ===== BUILDER STAGE =====
FROM ${BUILDER_IMAGE} as builder

# Install system dependencies with security updates
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    pkg-config \
    && apt-get upgrade -y \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Rust for NIF compilation with specific version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Node.js and pnpm with specific versions
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm@^9.0.0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV="prod"
ENV NODE_ENV="production"
ENV LANG="en_US.UTF-8"
ENV LC_ALL="en_US.UTF-8"

# Copy dependency files for better layer caching
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Create config directory and copy compile-time configs
RUN mkdir -p config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy and install Node.js dependencies
COPY assets/package.json assets/pnpm-lock.yaml ./assets/
WORKDIR /app/assets
RUN pnpm install --frozen-lockfile --production=false

# Copy native dependencies and build them
WORKDIR /app
COPY native ./native
WORKDIR /app/native/markdown_ld_nif
RUN cargo build --release

# Copy asset files and build frontend
WORKDIR /app
COPY assets ./assets
WORKDIR /app/assets
RUN pnpm run build

# Copy application source files
WORKDIR /app
COPY priv priv
COPY lib lib

# Build assets and compile application
RUN mix assets.deploy
RUN mix compile

# Copy runtime configuration and build release
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ===== RUNNER STAGE =====
FROM ${RUNNER_IMAGE} as runner

# Install runtime dependencies only
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    libstdc++6 \
    openssl \
    libncurses6 \
    locales \
    ca-certificates \
    curl \
    tini \
    && apt-get upgrade -y \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

# Create app user and directory with specific UIDs for security
RUN groupadd --gid 1001 app && \
    useradd --uid 1001 --gid app --shell /bin/bash --create-home app

# Create app directories with proper permissions
WORKDIR /app
RUN mkdir -p /app/tmp /app/uploads /app/logs \
    && chown -R app:app /app

# Set runtime environment
ENV MIX_ENV="prod"
ENV PHX_SERVER="true"
ENV PORT="4000"

# Copy release from builder stage with proper ownership
COPY --from=builder --chown=app:app /app/_build/${MIX_ENV}/rel/kyozo ./

# Switch to non-root user for security
USER app

# Expose port
EXPOSE 4000

# Health check with improved configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
    CMD curl -f http://localhost:4000/api/health || exit 1

# Use tini as init system for proper signal handling
ENTRYPOINT ["tini", "--"]

# Default command
CMD ["/app/bin/server"]
