#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="$SCRIPT_DIR/conf/local"
SECRETS_FILE="$CONF_DIR/secrets.conf"

echo "=== La Suite Helmfile - Local Environment Setup ==="
echo ""

# Check if secrets.conf already exists
if [ -f "$SECRETS_FILE" ]; then
    echo "secrets.conf already exists at $SECRETS_FILE"
    echo "Delete it first if you want to regenerate."
    exit 1
fi

# Generate random seed (48 chars hex)
SEED=$(openssl rand -hex 24)

# Create secrets.conf
cat > "$SECRETS_FILE" << EOF
# Secret seed for generating all internal secrets
# Generated on $(date -Iseconds)
# NEVER commit this file!
secretSeed: "$SEED"
EOF

echo "Created $SECRETS_FILE with random seed"
echo ""
echo "=== Add to /etc/hosts ==="
echo ""
echo "127.0.0.1  docs.suite.local meet.suite.local drive.suite.local desk.suite.local auth.suite.local minio.suite.local"
echo ""
echo "=== Next steps ==="
echo ""
echo "1. Add the line above to /etc/hosts"
echo "2. Run: helmfile -e local sync"
echo ""
