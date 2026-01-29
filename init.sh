#!/bin/bash
set -e
shopt -s inherit_errexit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed"
        exit 1
    fi
}

generate_seed() {
    openssl rand -hex 24
}

echo ""
echo "=== La Suite Platform - Setup ==="
echo ""
echo "1) Local development (suite.local)"
echo "2) Remote deployment"
echo ""
read -rp "Choice [1/2]: " CHOICE

case ${CHOICE} in
    1)
        ENV_NAME="local"
        CONF_DIR="${SCRIPT_DIR}/conf/${ENV_NAME}"
        SECRETS_FILE="${CONF_DIR}/secrets.conf"

        check_command helm
        check_command kubectl
        check_command helmfile

        if ! kubectl cluster-info &> /dev/null; then
            echo "Error: Cannot connect to Kubernetes cluster"
            exit 1
        fi

        if [[ -f "${SECRETS_FILE}" ]]; then
            echo "secrets.conf already exists. Delete it to regenerate."
            exit 1
        fi

        mkdir -p "${CONF_DIR}"
        SEED="$(generate_seed)"
        cat > "${SECRETS_FILE}" << EOF
secretSeed: "${SEED}"
EOF
        echo "Created ${SECRETS_FILE}"
        echo ""
        echo "Add to /etc/hosts:"
        echo "127.0.0.1  docs.suite.local meet.suite.local drive.suite.local desk.suite.local auth.suite.local minio.suite.local livekit.suite.local"
        echo ""
        read -rp "Press Enter to deploy..."

        cd "${SCRIPT_DIR}"
        helmfile -e local sync

        # Extract CA certificate
        CA_FILE="${SCRIPT_DIR}/lasuite-ca.pem"
        echo ""
        kubectl get secret lasuite-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > "${CA_FILE}" || true
        echo "CA certificate saved to: ${CA_FILE} (see README for trust instructions)"
        echo ""
        echo "Done. Access: https://docs.suite.local (user/password)"
        ;;

    2)
        read -rp "Environment name: " ENV_NAME
        read -rp "Domain: " DOMAIN
        read -rp "Admin email: " ADMIN_EMAIL

        CONF_DIR="${SCRIPT_DIR}/conf/${ENV_NAME}"
        ENV_FILE="${SCRIPT_DIR}/environments/${ENV_NAME}.yaml"
        SECRETS_FILE="${CONF_DIR}/secrets.conf"
        TEMPLATE_FILE="${SCRIPT_DIR}/environments/remote-example.yaml"

        mkdir -p "${CONF_DIR}"

        # Copy template and replace placeholders
        sed -e "s/__DOMAIN__/${DOMAIN}/g" \
            -e "s/__ADMIN_EMAIL__/${ADMIN_EMAIL}/g" \
            "${TEMPLATE_FILE}" > "${ENV_FILE}"

        SEED="$(generate_seed)"
        cat > "${SECRETS_FILE}" << EOF
secretSeed: "${SEED}"
EOF

        echo ""
        echo "Created:"
        echo "  - ${ENV_FILE}"
        echo "  - ${SECRETS_FILE}"
        echo ""
        echo "Review these files before deploying."
        echo "See docs/advanced-deployment.md for external infrastructure."
        echo ""
        echo "Add to helmfile.yaml.gotmpl:"
        echo ""
        echo "  ${ENV_NAME}:"
        echo "    values:"
        echo "      - versions/backend-helm-versions.yaml"
        echo "      - versions/lasuite-helm-versions.yaml"
        echo "      - environments/${ENV_NAME}.yaml"
        echo "      - conf/${ENV_NAME}/secrets.conf"
        echo "      - environments/_computed.yaml.gotmpl"
        echo ""
        echo "Before deploying, configure DNS records pointing to your cluster:"
        echo "  docs.${DOMAIN}"
        echo "  meet.${DOMAIN}"
        echo "  drive.${DOMAIN}"
        echo "  auth.${DOMAIN}"
        echo "  livekit.${DOMAIN}"
        echo ""
        echo "Let's Encrypt requires valid DNS for certificate issuance."
        echo ""
        echo "Then: helmfile -e ${ENV_NAME} sync"
        ;;

    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
