#!/bin/bash
set -e

# Default UID/GID if not provided
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}
USERNAME="claude"

echo "Setting up user $USERNAME with UID:$USER_UID GID:$USER_GID"

# Create group if it doesn't exist
if ! getent group "$USERNAME" > /dev/null 2>&1; then
    groupadd -g "$USER_GID" "$USERNAME"
fi

# Create user if it doesn't exist
if ! getent passwd "$USERNAME" > /dev/null 2>&1; then
    useradd -u "$USER_UID" -g "$USERNAME" -s /bin/bash -m "$USERNAME"
fi

# Set up user's home directory
USER_HOME="/home/$USERNAME"
if [ ! -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME"
fi

# Set up sandbox permissions
chown -R "$USER_UID:$USER_GID" /sandbox
chown -R "$USER_UID:$USER_GID" "$USER_HOME"

# Create .claude directory in sandbox with proper permissions
mkdir -p /sandbox/.claude
chown -R "$USER_UID:$USER_GID" /sandbox/.claude
chmod -R 755 /sandbox/.claude

# Copy global .claude configuration to sandbox (if exists)
if [ -d "/home/claude/.claude" ]; then
    cp -r /home/claude/.claude/* /sandbox/.claude/ 2>/dev/null || true
    chown -R "$USER_UID:$USER_GID" /sandbox/.claude
fi

# Set up limited user environment (NO SUDO ACCESS)
# User can only modify files in /sandbox and their home directory

# Set up git configuration if not exists
if [ ! -f "$USER_HOME/.gitconfig" ]; then
    cat > "$USER_HOME/.gitconfig" << EOF
[user]
    name = Claude Sandbox User
    email = claude-sandbox@localhost
[init]
    defaultBranch = main
[core]
    editor = nano
EOF
    chown "$USER_UID:$USER_GID" "$USER_HOME/.gitconfig"
fi

# Initialize git repository in sandbox if not exists
if [ ! -d "/sandbox/.git" ]; then
    cd /sandbox
    git init
    git add .
    git commit -m "Initial sandbox setup" 2>/dev/null || true
fi

# Create Claude Code wrapper script with dangerous permissions
cat > /usr/local/bin/claude-safe << 'EOF'
#!/bin/bash
echo "Starting Claude Code in sandbox mode with dangerous permissions..."
echo "WARNING: This is a sandbox environment. Files can be modified without confirmation!"
echo "Sandbox directory: $(pwd)"
echo "User: $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "PHP version: $(php -v | head -n1)"
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "API Key: Set (${#ANTHROPIC_API_KEY} characters)"
    echo "Model: ${ANTHROPIC_MODEL:-claude-sonnet-4-20250514}"
else
    echo "WARNING: ANTHROPIC_API_KEY not set - Claude will not work!"
fi
echo "---"

# Run Claude with dangerous permissions in sandbox
exec claude --dangerously-skip-permissions --permission-mode=bypassPermissions --allowedTools=* --continue "$@"
EOF

chmod +x /usr/local/bin/claude-safe

# Create PHP version info
cat > /usr/local/bin/php-switch << 'EOF'
#!/bin/bash
echo "Current PHP version: $(php -v | head -n1)"
echo "PHP is installed from Ubuntu repository"
EOF

chmod +x /usr/local/bin/php-switch

echo "================================="
echo "Claude Sandbox Environment Ready"
echo "================================="
echo "User: $USERNAME (UID:$USER_UID, GID:$USER_GID)"
echo "Working directory: /sandbox"
echo "Claude config: /sandbox/.claude (persistent)"
if [ -d "/home/claude/.claude" ] && [ "$(ls -A /home/claude/.claude 2>/dev/null)" ]; then
    echo "Global config: Copied to sandbox"
else
    echo "Global config: Not found (will be created)"
fi
echo "Available commands:"
echo "  claude-safe    - Run Claude with dangerous permissions"
echo "  claude         - Run Claude with normal permissions"
echo "  bun           - Bun package manager"
echo "  node          - Node.js"
echo "  php           - PHP CLI"
echo "  composer      - PHP Composer"
echo "  python3       - Python"
echo "================================="

# Switch to the created user and execute the command (NO SUDO - direct user switch)
if [ "$#" -gt 0 ]; then
    exec su -s /bin/bash claude -c "cd /sandbox && $*"
else
    exec su -s /bin/bash claude -c "cd /sandbox && bash"
fi