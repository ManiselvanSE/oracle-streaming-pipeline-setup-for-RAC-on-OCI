#!/bin/bash
# =============================================================================
# SSH connection script to xstrm-con VM
# Usage: ./ssh-connect.sh
# Ensure your private key has correct permissions: chmod 600 ssh-key-2026-03-12.key
# =============================================================================

VM_IP="161.153.48.163"
# Use PRIVATE key for SSH (not .pub)
KEY_FILE="${1:-$HOME/Desktop/Mani/ssh-key-2026-03-12.key}"
USER="${2:-opc}"

if [ ! -f "$KEY_FILE" ]; then
  echo "Private key not found at: $KEY_FILE"
  echo "Usage: $0 [path-to-private-key] [username]"
  echo "Default user: opc (Oracle Linux default)"
  exit 1
fi

chmod 600 "$KEY_FILE" 2>/dev/null || true
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new "$USER@$VM_IP"
