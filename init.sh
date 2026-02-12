#!/bin/bash
set -e

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

read_seed() {
    local env_file="$1"
    grep secretSeed "${env_file}" | cut -d'"' -f2
}

post_deploy() {
    local seed="$1"

    check_command kubectl

    if ! kubectl cluster-info &> /dev/null; then
        echo "Error: Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Get LoadBalancer IP
    echo ""
    echo "Waiting for LoadBalancer IP..."
    LB_IP=""
    for _ in {1..30}; do
        LB_IP=$(kubectl get svc haproxy-ingress-kubernetes-ingress -n haproxy-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [[ -n "${LB_IP}" ]]; then
            break
        fi
        sleep 2
    done

    if [[ -z "${LB_IP}" ]]; then
        LB_IP="127.0.0.1"
        echo "Could not detect LoadBalancer IP, defaulting to ${LB_IP}"
    fi

    echo ""
    echo "Add to /etc/hosts:"
    echo "${LB_IP}  docs.suite.local meet.suite.local drive.suite.local people.suite.local conversations.suite.local find.suite.local auth.suite.local minio.suite.local livekit.suite.local"

    # Extract CA certificate
    CA_FILE="${SCRIPT_DIR}/lasuite-ca.pem"
    echo ""
    kubectl get secret lasuite-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > "${CA_FILE}" || true
    echo "CA certificate saved to: ${CA_FILE} (see README for trust instructions)"

    # Compute derived passwords (same as deriveSecret: sha256(seed:id)[:50])
    KC_PASS=$(echo -n "${seed}:keycloak-admin" | shasum -a 256 | cut -c1-50)
    PEOPLE_PASS=$(echo -n "${seed}:people-superuser" | shasum -a 256 | cut -c1-50)

    # Create People superuser (chart 0.0.7 bug: createsuperuser job is broken)
    if kubectl get deploy people-desk-backend -n lasuite-people &> /dev/null; then
        echo ""
        echo "Waiting for People backend to be ready..."
        if kubectl rollout status deploy/people-desk-backend -n lasuite-people --timeout=120s &> /dev/null; then
            echo "Creating People superuser..."
            kubectl -n lasuite-people exec deploy/people-desk-backend -- \
                python manage.py createsuperuser --username admin@suite.local --password "${PEOPLE_PASS}" 2>/dev/null || true
        else
            echo "People backend not ready, skipping superuser creation."
            echo "Run manually: kubectl -n lasuite-people exec deploy/people-desk-backend -- python manage.py createsuperuser --username admin@suite.local --password <see credentials below>"
        fi
    fi

    echo ""
    echo "=== Credentials ==="
    echo ""
    echo "Apps (Keycloak user):  user / password"
    echo "Keycloak admin:        admin / ${KC_PASS}"
    echo "                       https://auth.suite.local"
    if kubectl get deploy people-desk-backend -n lasuite-people &> /dev/null 2>&1; then
    echo "People Django admin:   admin@suite.local / ${PEOPLE_PASS}"
    echo "                       https://people.suite.local/admin/"
    fi
    echo ""
    echo "Done. Access: https://docs.suite.local"
}

# When sourced by another script, only export functions — don't run main logic
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

# --post-deploy: skip config generation and helmfile sync, run post-deploy only
if [[ "${1:-}" == "--post-deploy" ]]; then
    ENV_FILE="${SCRIPT_DIR}/environments/local.yaml"
    if [[ ! -f "${ENV_FILE}" ]]; then
        echo "Error: ${ENV_FILE} not found. Run ./init.sh first."
        exit 1
    fi
    SEED="$(read_seed "${ENV_FILE}")"
    if [[ -z "${SEED}" || "${SEED}" == "REPLACE_ME" ]]; then
        echo "Error: secretSeed not set in ${ENV_FILE}"
        exit 1
    fi
    post_deploy "${SEED}"
    exit 0
fi

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
        ENV_FILE="${SCRIPT_DIR}/environments/${ENV_NAME}.yaml"
        TEMPLATE_FILE="${SCRIPT_DIR}/environments/${ENV_NAME}.yaml.example"

        check_command helm
        check_command kubectl
        check_command helmfile

        if ! kubectl cluster-info &> /dev/null; then
            echo "Error: Cannot connect to Kubernetes cluster"
            exit 1
        fi

        if [[ -f "${ENV_FILE}" ]]; then
            echo "Using existing ${ENV_FILE}"
            SEED="$(read_seed "${ENV_FILE}")"
        else
            SEED="$(generate_seed)"
            sed "s/secretSeed: \"REPLACE_ME\"/secretSeed: \"${SEED}\"/" \
                "${TEMPLATE_FILE}" > "${ENV_FILE}"
            echo "Created ${ENV_FILE}"
        fi
        echo ""
        echo "Review ${ENV_FILE} to choose which apps to deploy (apps.*.enabled)."
        echo "Default: docs, drive, people. Optional: meet (+livekit), conversations, find (+opensearch)."
        echo ""

        read -rp "Press Enter to run helmfile sync..."

        cd "${SCRIPT_DIR}"
        helmfile -e local sync

        post_deploy "${SEED}"
        ;;

    2)
        read -rp "Environment name: " ENV_NAME
        read -rp "Domain: " DOMAIN
        read -rp "Admin email: " ADMIN_EMAIL

        ENV_FILE="${SCRIPT_DIR}/environments/${ENV_NAME}.yaml"
        TEMPLATE_FILE="${SCRIPT_DIR}/environments/remote.yaml.example"

        if [[ -f "${ENV_FILE}" ]]; then
            echo "${ENV_FILE} already exists. Delete it to regenerate."
            exit 1
        fi

        SEED="$(generate_seed)"
        sed -e "s/__DOMAIN__/${DOMAIN}/g" \
            -e "s/__ADMIN_EMAIL__/${ADMIN_EMAIL}/g" \
            -e "s/secretSeed: \"REPLACE_ME\"/secretSeed: \"${SEED}\"/" \
            "${TEMPLATE_FILE}" > "${ENV_FILE}"

        echo ""
        echo "Created: ${ENV_FILE}"
        echo ""
        echo "Review this file before deploying."
        echo "See docs/advanced-deployment.md for external infrastructure."
        echo ""
        echo "Add to helmfile.yaml.gotmpl:"
        echo ""
        echo "  ${ENV_NAME}:"
        echo "    values:"
        echo "      - versions/backend-helm-versions.yaml"
        echo "      - versions/lasuite-helm-versions.yaml"
        echo "      - environments/${ENV_NAME}.yaml"
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
