# Stage 6 — Data Encryption Config

etcd stores Secrets as plaintext by default. This stage generates a key and config telling the API server to encrypt Secrets before they're written to etcd.

On the jumpbox:
```bash
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo $ENCRYPTION_KEY   # save this somewhere safe — needed if you ever need to decrypt existing Secrets

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

scp encryption-config.yaml ubuntu@${CP_IP}:~/
```

`identity: {}` is a fallback, not an active choice — it just means "if you encounter unencrypted data, read it as-is," so the API server doesn't crash on old data.

Next: [`07-etcd.md`](./07-etcd.md)
