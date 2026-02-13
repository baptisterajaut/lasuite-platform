#!/usr/bin/env bash
# generate-compose.sh — Generate compose.yml + Caddyfile from helmfile templates
#
# First run:  interactive setup (domain, apps, data root, secrets)
# Next runs:  re-renders helmfile templates + regenerates compose
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Reuse helpers from init.sh (generate_seed, read_seed)
source "$SCRIPT_DIR/init.sh"

TEMPLATE_CHECK=true
for arg in "$@"; do
    [[ "$arg" == "--no-template-check" ]] && TEMPLATE_CHECK=false
done

# Warn if a generated file has drifted from its template (line count comparison)
check_template_drift() {
    local generated="$1" template="$2"
    [[ "$TEMPLATE_CHECK" == false ]] && return
    [[ ! -f "$generated" || ! -f "$template" ]] && return
    local gen_lines tpl_lines
    gen_lines=$(wc -l < "$generated" | tr -d ' ')
    tpl_lines=$(wc -l < "$template" | tr -d ' ')
    if [[ "$gen_lines" -ne "$tpl_lines" ]]; then
        echo ""
        echo "⚠ Template drift: $generated ($gen_lines lines) differs from $template ($tpl_lines lines)."
        echo "  The template may have new options since you generated your file."
        echo "  Compare them:  diff $generated $template"
        echo "  Use --no-template-check to suppress this warning."
        read -rp "  Press Enter to continue..."
        echo ""
    fi
}

H2C_VERSION="v1.2.1"
H2C_URL="https://raw.githubusercontent.com/baptisterajaut/helmfile2compose/${H2C_VERSION}/helmfile2compose.py"
H2C_SCRIPT="$(mktemp /tmp/helmfile2compose.XXXXXX.py)"
RENDERED_DIR="generated-platform"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

echo "Checking prerequisites..."
missing=()
for cmd in helmfile helm python3 openssl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
python3 -c "import yaml" 2>/dev/null || missing+=("pyyaml (pip install pyyaml)")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: missing prerequisites: ${missing[*]}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Download helmfile2compose.py
# ---------------------------------------------------------------------------

echo "Downloading helmfile2compose.py (${H2C_VERSION})..."
curl -fsSL "$H2C_URL" -o "$H2C_SCRIPT"
trap 'rm -f "$H2C_SCRIPT"' EXIT

# ---------------------------------------------------------------------------
# Setup: environments/compose.yaml
# ---------------------------------------------------------------------------

if [[ ! -f environments/compose.yaml ]]; then
    echo ""
    echo "=== La Suite — Compose Setup ==="
    echo ""

    # -- Domain --
    read -rp "Domain [suite.local]: " DOMAIN
    DOMAIN="${DOMAIN:-suite.local}"

    # -- Meet/LiveKit --
    read -rp "Enable video calls (Meet + LiveKit)? [y/N]: " MEET
    MEET="${MEET:-n}"
    MEET="${MEET,,}"
    MEET_ENABLED=$( [[ "$MEET" == "y" ]] && echo "true" || echo "false" )

    # -- Conversations --
    read -rp "Enable AI conversations? [y/N]: " CONV
    CONV="${CONV:-n}"
    CONV="${CONV,,}"
    CONV_ENABLED=$( [[ "$CONV" == "y" ]] && echo "true" || echo "false" )

    AI_BASE_URL=""
    AI_MODEL=""
    AI_API_KEY=""
    if [[ "$CONV" == "y" ]]; then
        echo ""
        echo "  Conversations requires an OpenAI-compatible LLM endpoint."
        echo "  Example (Ollama): http://192.168.1.100:11434/v1/"
        echo ""
        read -rp "  AI base URL: " AI_BASE_URL
        read -rp "  AI model name: " AI_MODEL
        read -rp "  AI API key [ollama]: " AI_API_KEY
        AI_API_KEY="${AI_API_KEY:-ollama}"
    fi

    # -- Keycloak test user --
    echo ""
    read -rp "Keycloak test user username [user]: " KC_USERNAME
    KC_USERNAME="${KC_USERNAME:-user}"
    read -rp "Keycloak test user password [password]: " KC_PASSWORD
    KC_PASSWORD="${KC_PASSWORD:-password}"

    # -- Generate --
    echo ""
    echo "Creating environments/compose.yaml..."
    SEED="$(generate_seed)"
    sed -e "s|__DOMAIN__|${DOMAIN}|g" \
        -e "s|__SECRET_SEED__|${SEED}|" \
        -e "s|__MEET_ENABLED__|${MEET_ENABLED}|g" \
        -e "s|__CONVERSATIONS_ENABLED__|${CONV_ENABLED}|g" \
        -e "s|__AI_BASE_URL__|${AI_BASE_URL}|g" \
        -e "s|__AI_MODEL__|${AI_MODEL}|g" \
        -e "s|__AI_API_KEY__|${AI_API_KEY}|g" \
        -e "s|__KC_USERNAME__|${KC_USERNAME}|g" \
        -e "s|__KC_PASSWORD__|${KC_PASSWORD}|g" \
        environments/compose.yaml.template > environments/compose.yaml

    echo "  domain:        ${DOMAIN}"
    echo "  secretSeed:    ${SEED:0:8}..."
    echo "  meet:          ${MEET_ENABLED}"
    echo "  conversations: ${CONV_ENABLED}"
    echo "  keycloak user: ${KC_USERNAME}"
    echo ""
else
    check_template_drift environments/compose.yaml environments/compose.yaml.template
fi

# ---------------------------------------------------------------------------
# Setup: helmfile2compose.yaml (data root, caddy email)
# ---------------------------------------------------------------------------

if [[ ! -f helmfile2compose.yaml ]]; then
    # -- Data root --
    read -rp "Data directory [./data]: " DATA_ROOT
    DATA_ROOT="${DATA_ROOT:-./data}"

    # -- Email for Let's Encrypt (real domains only) --
    DOMAIN=$(grep '^domain:' environments/compose.yaml | awk '{print $2}')
    CADDY_EMAIL=""
    if [[ "$DOMAIN" != *.local && "$DOMAIN" != localhost ]]; then
        read -rp "Email for Let's Encrypt certificates: " CADDY_EMAIL
    fi

    # -- Generate from template --
    sed "s|__VOLUME_ROOT__|${DATA_ROOT}|" helmfile2compose.yaml.template > helmfile2compose.yaml
    if [[ -n "$CADDY_EMAIL" ]]; then
        echo "caddy_email: \"${CADDY_EMAIL}\"" >> helmfile2compose.yaml
    fi

    # -- Data directories --
    mkdir -p "${DATA_ROOT}"/{postgresql,redis,minio}

    echo ""
else
    check_template_drift helmfile2compose.yaml helmfile2compose.yaml.template
fi

# ---------------------------------------------------------------------------
# Render helmfile templates
# ---------------------------------------------------------------------------

echo "Rendering helmfile templates..."
rm -rf "$RENDERED_DIR"
helmfile -e compose template --output-dir "$RENDERED_DIR"

# ---------------------------------------------------------------------------
# Generate compose.yml + Caddyfile
# ---------------------------------------------------------------------------

echo "Generating compose.yml..."
rm -rf configmaps/ secrets/
python3 "$H2C_SCRIPT" --from-dir "$RENDERED_DIR" --output-dir .

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

DOMAIN=$(grep '^domain:' environments/compose.yaml | awk '{print $2}')
SEED=$(read_seed environments/compose.yaml)
KC_PASS=$(echo -n "${SEED}:keycloak-admin" | shasum -a 256 | cut -c1-50)
KC_USER=$(grep '^\s*username:' environments/compose.yaml | head -1 | awk '{print $2}')
KC_USERPASS=$(grep '^\s*password:' environments/compose.yaml | head -1 | awk '{print $2}')

echo ""
echo "=== Done ==="
echo ""
echo "Add to /etc/hosts (or DNS):"
echo "  127.0.0.1  docs.${DOMAIN} drive.${DOMAIN} meet.${DOMAIN} auth.${DOMAIN}"
echo "  127.0.0.1  people.${DOMAIN} conversations.${DOMAIN} minio.${DOMAIN}"
echo "  127.0.0.1  minio-console.${DOMAIN} livekit.${DOMAIN}"
echo ""
echo "Credentials:"
echo "  Apps (Keycloak user):  ${KC_USER} / ${KC_USERPASS}"
echo "  Keycloak admin:        admin / ${KC_PASS}"
echo "                         https://auth.${DOMAIN}"
echo ""
echo "Start:  docker compose up -d"
echo "Regen:  ./generate-compose.sh"
