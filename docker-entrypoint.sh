#!/bin/bash
set -e

# Default UID/GID if not provided
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}
USERNAME="claude"

echo "Setting up user $USERNAME with UID:$USER_UID GID:$USER_GID"

# Create group if it doesn't exist
if ! getent group "$USERNAME" > /dev/null 2>&1; then
    if ! getent group "$USER_GID" > /dev/null 2>&1; then
        groupadd -g "$USER_GID" "$USERNAME"
    else
        echo "Group with GID $USER_GID already exists, using existing group"
        # Get the existing group name and use it
        EXISTING_GROUP=$(getent group "$USER_GID" | cut -d: -f1)
        USERNAME_GROUP="$EXISTING_GROUP"
    fi
else
    USERNAME_GROUP="$USERNAME"
fi

# Create user if it doesn't exist
if ! getent passwd "$USERNAME" > /dev/null 2>&1; then
    if ! getent passwd "$USER_UID" > /dev/null 2>&1; then
        useradd -u "$USER_UID" -g "${USERNAME_GROUP:-$USERNAME}" -s /bin/bash -m "$USERNAME"
    else
        echo "User with UID $USER_UID already exists, using existing user"
        # Get the existing user name but create claude user with different UID
        AVAILABLE_UID=$((USER_UID + 1000))
        while getent passwd "$AVAILABLE_UID" > /dev/null 2>&1; do
            AVAILABLE_UID=$((AVAILABLE_UID + 1))
        done
        echo "Creating user $USERNAME with available UID: $AVAILABLE_UID"
        useradd -u "$AVAILABLE_UID" -g "${USERNAME_GROUP:-$USERNAME}" -s /bin/bash -m "$USERNAME"
        USER_UID="$AVAILABLE_UID"
    fi
fi

# Set up user's home directory
USER_HOME="/home/$USERNAME"
if [ ! -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME"
fi

# Get the actual group ID for the user
ACTUAL_GID=$(getent passwd "$USERNAME" | cut -d: -f4)

# Set up sandbox permissions
chown -R "$USER_UID:$ACTUAL_GID" /sandbox
# Only chown user home if it's not a read-only mount
# Skip chown on user home to avoid conflicts with mounted .claude directory
echo "Skipping chown on $USER_HOME to avoid conflicts with mounted directories"

# Create .claude directory in sandbox with proper permissions
mkdir -p /sandbox/.claude
chown -R "$USER_UID:$ACTUAL_GID" /sandbox/.claude
chmod -R 755 /sandbox/.claude

# Copy global .claude configuration to sandbox (if exists)
if [ -d "/home/claude/.claude" ] && [ "$(ls -A /home/claude/.claude 2>/dev/null)" ]; then
    echo "Found global .claude config, copying to sandbox..."
    # Make sure destination exists and is empty
    rm -rf /sandbox/.claude 2>/dev/null || true
    mkdir -p /sandbox/.claude
    # Copy using rsync to avoid permission issues
    rsync -a --no-perms --no-owner --no-group /home/claude/.claude/ /sandbox/.claude/ 2>/dev/null || {
        echo "rsync failed, trying cp method..."
        # Fallback to cp method
        cp -r /home/claude/.claude/* /sandbox/.claude/ 2>/dev/null || true
    }
    # Make all copied files writable and set correct ownership
    find /sandbox/.claude -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /sandbox/.claude -type d -exec chmod 755 {} \; 2>/dev/null || true
    chown -R "$USER_UID:$ACTUAL_GID" /sandbox/.claude 2>/dev/null || true
    echo "Config copied successfully to /sandbox/.claude"
else
    echo "No global .claude config found or empty, will be created fresh"
fi

# Set up limited user environment (NO SUDO ACCESS)
# User can only modify files in /sandbox and their home directory

# Set up git configuration if not exists
if [ ! -f "$USER_HOME/.gitconfig" ] && [ -w "$USER_HOME" ]; then
    cat > "$USER_HOME/.gitconfig" << EOF
[user]
    name = Claude Sandbox User
    email = claude-sandbox@localhost
[init]
    defaultBranch = main
[core]
    editor = nano
EOF
    if [ -w "$USER_HOME/.gitconfig" ]; then
        chown "$USER_UID:$ACTUAL_GID" "$USER_HOME/.gitconfig"
    else
        echo "Warning: Cannot chown $USER_HOME/.gitconfig (read-only)"
    fi
else
    echo "Skipping git config setup - $USER_HOME not writable or .gitconfig exists"
fi

# Initialize git repository in sandbox if not exists
if [ ! -d "/sandbox/.git" ]; then
    cd /sandbox
    # Set up git safe directory to avoid ownership issues
    git config --global --add safe.directory /sandbox
    git config --global init.defaultBranch main
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
echo "Authentication: Browser login required (no API key embedded)"
echo "---"

# Set memory optimization for Node.js and disable file watching
export NODE_OPTIONS="--max-old-space-size=3072"
export CHOKIDAR_USEPOLLING=true
export CHOKIDAR_INTERVAL=1000

# Run Claude with dangerous permissions in sandbox
exec claude --dangerously-skip-permissions --permission-mode=bypassPermissions --allowedTools=* "$@"
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
if [ -d "/sandbox/.claude" ] && [ "$(ls -A /sandbox/.claude 2>/dev/null)" ]; then
    echo "Global config: Available in sandbox"
else
    echo "Global config: Will be created fresh"
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
