#!/usr/bin/env bash
# Run on the JUMPBOX. Generates the etcd Secrets-encryption key and config.
set -euo pipefail

CERTS_DIR="${CERTS_DIR:-$HOME/k8s-certs}"
cd "$CERTS_DIR"

ENCRYPTION_KEY="$(head -c 32 /dev/urandom | base64)"

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo "Generated encryption-config.yaml in $CERTS_DIR"
echo ""
echo "IMPORTANT: save this key somewhere safe. It cannot be recovered from the file alone"
echo "if you lose this terminal session before copying it elsewhere."
echo "ENCRYPTION_KEY=${ENCRYPTION_KEY}"
