# Claude Code Sandbox - Browser Login Edition

> **Status**: ✅ **Fully Operational** - Docker sandbox with browser-based authentication

## Quick Start

### 1. Build Image

Get your GitHub token (optional):
- **GitHub Token**: https://github.com/settings/tokens/new?scopes=repo,read:org,gist,workflow

```bash
docker build . \
  --tag claude-sandbox-personal \
  --build-arg GH_TOKEN="gho_************************************" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --no-cache
```

**Note**: No Anthropic API key needed - Claude will use browser login authentication.

### 2. Use in Any Project

**Standard command with browser login:**
```bash
docker run --rm -it \
  --memory=16g \
  --memory-swap=16g \
  --ulimit nofile=65536:65536 \
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \
  -v "$(pwd):/sandbox:rw" \
  -v "$HOME/.claude:/home/claude/.claude:ro" \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe
```

**With GitHub token (for git operations):**
```bash
docker run --rm -it \
  --memory=16g \
  --memory-swap=16g \
  --ulimit nofile=65536:65536 \
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \
  -e GH_TOKEN="gho_************************************" \
  -v "$(pwd):/sandbox:rw" \
  -v "$HOME/.claude:/home/claude/.claude:ro" \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe
```

**Note**: Claude config is mounted as `ro` for security. Authentication tokens are saved on the host system.

### 3. Create Alias (Recommended)

#### Bash/Zsh (~/.bashrc or ~/.zshrc):
```bash
alias claude-here='docker run --rm -it \
  --memory=16g \
  --memory-swap=16g \
  --ulimit nofile=65536:65536 \
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \
  -v "$(pwd):/sandbox:rw" \
  -v "$HOME/.claude:/home/claude/.claude:ro" \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe'

alias claude-here-gh='docker run --rm -it \
  --memory=16g \
  --memory-swap=16g \
  --ulimit nofile=65536:65536 \
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \
  -e GH_TOKEN="$GH_TOKEN" \
  -v "$(pwd):/sandbox:rw" \
  -v "$HOME/.claude:/home/claude/.claude:ro" \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe'
```

#### Fish (~/.config/fish/config.fish):
```fish
alias --save claude-here='docker run --rm -it \
  --memory=16g \
  --memory-swap=16g \
  --ulimit nofile=65536:65536 \
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \
  -v (pwd):/sandbox:rw \
  -v $HOME/.claude:/home/claude/.claude:ro \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe'

alias --save claude-here-gh='docker run --rm -it \
  --memory=16g \
  --memory-swap=16g \
  --ulimit nofile=65536:65536 \
  --tmpfs /tmp:rw,noexec,nosuid,size=1g \
  -e GH_TOKEN="$GH_TOKEN" \
  -v (pwd):/sandbox:rw \
  -v $HOME/.claude:/home/claude/.claude:ro \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe'
```

**Usage:**
```bash
# Standard usage
cd ~/any-project && claude-here

# With GitHub token (for git operations)
export GH_TOKEN="gho_************************************"
cd ~/any-project && claude-here-gh
```

## Features

### ✅ **ENOMEM Problem Solved**
- **16GB Memory Limit** - Prevents out of memory errors
- **Polling-based File Watching** - No more inotify kernel memory issues  
- **Node.js Heap Optimization** - 3GB heap size for large projects
- **System Limits** - Optimized file descriptors and tmpfs

### 🛠️ **Development Stack**
- **Claude Code CLI v1.0.96** - With dangerous permissions for sandbox operation
- **Node.js & Bun** - Modern JavaScript runtime and package manager
- **PHP 8.2** - With Composer for PHP development  
- **Python 3** - For Python-based projects
- **Git** - Version control with proper ownership handling
- **Development Tools** - vim, nano, tree, jq, rsync, and more

### 🔧 **Smart Resource Management**
- **Automatic UID/GID Handling** - Resolves user conflicts dynamically
- **Read-Only Mount Support** - Safely handles mounted .claude configuration
- **Container Isolation** - Runs as non-root user (claude, UID:2000+)

## Troubleshooting

### Memory Issues
If you still encounter ENOMEM errors:

1. **Increase memory**: Change `--memory=16g` to `--memory=20g`
2. **Check system memory**: `free -h` 
3. **Clear Docker cache**: `docker system prune`
4. **System-wide fix**: `echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p`

### Authentication Issues
If Claude has authentication problems:

1. **Browser login**: Claude will prompt for browser authentication on first use
2. **Check credentials**: Ensure `~/.claude/.credentials.json` exists and is readable
3. **Token expiration**: OAuth tokens may expire, requiring re-authentication
4. **Network issues**: Container may not be able to validate tokens online

**Browser login workflow:**
```bash
# Run Claude and follow browser login prompts
docker run --rm -it \
  --memory=16g \
  --memory-swap=16g \
  -v "$(pwd):/sandbox:rw" \
  -v "$HOME/.claude:/home/claude/.claude:ro" \
  claude-sandbox-personal claude-safe
```

### Permission Issues
- Verify `~/.claude` directory exists and is readable
- Check that current directory is writable for Docker
- Review container logs for UID/GID conflict messages

### Build Issues  
- Verify Docker has at least 16GB RAM available
- Check that GH_TOKEN has proper repository permissions (optional)
- Ensure sufficient disk space for Docker image build

## Environment Details

### Environment Variables
- `NODE_OPTIONS="--max-old-space-size=3072"` - Node.js memory optimization
- `CHOKIDAR_USEPOLLING=true` - Polling-based file watching (prevents ENOMEM)
- `CHOKIDAR_INTERVAL=1000` - File polling interval (1 second)
- `ANTHROPIC_MODEL` - Default model (claude-sonnet-4-20250514)

### Available Commands Inside Container
```bash
# Claude Code operations  
claude-safe --help                    # Claude with dangerous permissions
claude --help                        # Claude with normal permissions

# Development tools
bun install && bun run dev           # Node.js development
composer install && php -S :8000    # PHP development  
python3 -m http.server 8080         # Python development
git status                          # Git operations
```

## Requirements

- **Docker**: Latest version with at least 16GB RAM allocated
- **System Memory**: Minimum 20GB RAM recommended
- **Disk Space**: 3GB free space for Docker image
- **Authentication**: Internet access for Claude browser login
- **Network**: Internet access for Claude API calls

---

[LICENSE MIT](./LICENSE)
