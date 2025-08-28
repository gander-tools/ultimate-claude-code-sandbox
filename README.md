# Ultimate Claude Code Sandbox

> *"Built by Claude, to keep Claude in check"* 🤖⛓️

## Quick Start

### 1. Build Image

Get your tokens:
- **Anthropic API Key**: https://console.anthropic.com/account/keys
- **GitHub Token**: https://github.com/settings/tokens/new?scopes=repo,read:org,gist,workflow

```bash
docker build -t claude-sandbox-personal \
  --build-arg ANTHROPIC_API_KEY="your-api-key-here" \
  --build-arg ANTHROPIC_MODEL="claude-sonnet-4-20250514" \
  --build-arg GH_TOKEN="gho_************************************" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  .
```

### 2. Use in Any Project
```bash
docker run --rm -it \
  -v "$(pwd):/sandbox:rw" \
  -v "~/.claude:/home/claude/.claude:ro" \
  -v "~/.config/gh:/home/claude/.config/gh:ro" \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe
```

### 3. Create Alias (Optional)

#### Bash/Zsh (~/.bashrc or ~/.zshrc):
```bash
alias claude-here='docker run --rm -it \
  -v "$(pwd):/sandbox:rw" \
  -v "~/.claude:/home/claude/.claude:ro" \
  -v "~/.config/gh:/home/claude/.config/gh:ro" \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe'
```

#### Fish (~/.config/fish/config.fish):
```fish
alias --save claude-here='docker run --rm -it \
  -v (pwd):/sandbox:rw \
  -v ~/.claude:/home/claude/.claude:ro \
  -v ~/.config/gh:/home/claude/.config/gh:ro \
  -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 5173:5173 \
  claude-sandbox-personal claude-safe'
```

Then use: `cd ~/any-project && claude-here`

---

[LICENSE MIT](./LICENSE)


