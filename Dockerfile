# Ultimate Claude Code Sandbox - Maximum Power, Maximum Safety
FROM node:20

# Build-time arguments for embedding API credentials and user info (optional)
ARG ANTHROPIC_API_KEY=""
ARG ANTHROPIC_MODEL="claude-sonnet-4-20250514"
ARG GH_TOKEN=""
ARG USER_UID="1000"
ARG USER_GID="1000"

# Install system dependencies  
RUN apt-get update && \
    apt-get install -y \
    bash \
    git \
    curl \
    wget \
    ca-certificates \
    jq \
    nano \
    vim \
    tree \
    file \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    p7zip-full \
    make \
    build-essential \
    python3 \
    python3-pip \
    php \
    php-cli \
    php-json \
    php-curl \
    php-mbstring \
    php-xml \
    php-dom \
    composer \
    && npm install -g bun

# Install yq
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh -y

# Install Deno 2.4 (latest)
RUN curl -fsSL https://deno.land/install.sh | sh \
    && mv /root/.deno/bin/deno /usr/local/bin/deno \
    && chmod +x /usr/local/bin/deno

# Install Claude Code CLI (official installation)
# Note: The script automatically detects platform and downloads appropriate binary
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && chmod +x /usr/local/bin/claude 2>/dev/null || true

# Create entrypoint script for dynamic user creation
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create sandbox directory structure
RUN mkdir -p /sandbox/experiments/{nodejs,deno,php,python,docker} \
    && mkdir -p /sandbox/test-outputs \
    && mkdir -p /sandbox/temp-files \
    && mkdir -p /home/claude/.claude

# Set working directory
WORKDIR /sandbox


# Set resource limits (optional security measures)
RUN echo "* soft nproc 50" >> /etc/security/limits.conf \
    && echo "* hard nproc 100" >> /etc/security/limits.conf \
    && echo "* soft fsize 1048576" >> /etc/security/limits.conf \
    && echo "* hard fsize 2097152" >> /etc/security/limits.conf

# Create .gitignore for sandbox experiments
RUN echo "*.tmp\nexperiments/\ntest-outputs/\ntemp-files/\n.env.local\nnode_modules/\nvendor/" > /sandbox/.gitignore

# Environment variables for Claude Code
ENV CLAUDE_CONFIG_DIR=/sandbox/.claude
ENV NODE_ENV=development

# Set embedded credentials and user info as environment variables (if provided during build)
ENV ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
ENV ANTHROPIC_MODEL=${ANTHROPIC_MODEL}
ENV GH_TOKEN=${GH_TOKEN}
ENV USER_UID=${USER_UID}
ENV USER_GID=${USER_GID}

# Expose common development ports
EXPOSE 3000 8000 8080 5173

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]
