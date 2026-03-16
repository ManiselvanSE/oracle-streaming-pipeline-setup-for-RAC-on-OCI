#!/bin/bash
# =============================================================================
# Install Grafana on Oracle Linux 9 / RHEL 9
# Run on xstrm-con VM (or any Oracle Linux 9 host)
# Requires: sudo access
#
# Usage:
#   chmod +x scripts/install-grafana.sh
#   sudo ./scripts/install-grafana.sh
#
# After install: Grafana runs on http://<VM-IP>:3000
# Default login: admin / admin (change on first access)
# =============================================================================

set -e

echo "=== Installing Grafana on Oracle Linux 9 ==="

# 1. Import Grafana GPG key
echo "Step 1: Importing Grafana GPG key..."
wget -q -O /tmp/grafana.gpg.key https://rpm.grafana.com/gpg.key
sudo rpm --import /tmp/grafana.gpg.key
rm -f /tmp/grafana.gpg.key

# 2. Add Grafana repository
echo "Step 2: Adding Grafana repository..."
sudo tee /etc/yum.repos.d/grafana.repo > /dev/null << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# 3. Install Grafana OSS
echo "Step 3: Installing Grafana..."
sudo dnf install -y grafana

# 4. Configure Grafana to listen on all interfaces (for remote access)
# Default is localhost only; 0.0.0.0 allows access from browser via VM public IP
echo "Step 4: Configuring Grafana for remote access..."
GRAFANA_INI="/etc/grafana/grafana.ini"
if [ -f "$GRAFANA_INI" ]; then
  # Uncomment and set http_addr, or add if missing
  if grep -q "http_addr" "$GRAFANA_INI" 2>/dev/null; then
    sudo sed -i 's/^;*[[:space:]]*http_addr[[:space:]]*=.*/http_addr = 0.0.0.0/' "$GRAFANA_INI"
  else
    # Ensure [server] section exists and add http_addr
    if ! grep -q "^\[server\]" "$GRAFANA_INI" 2>/dev/null; then
      echo -e "\n[server]\nhttp_addr = 0.0.0.0" | sudo tee -a "$GRAFANA_INI" > /dev/null
    else
      sudo sed -i '/^\[server\]/a http_addr = 0.0.0.0' "$GRAFANA_INI"
    fi
  fi
fi

# 5. Open firewall port 3000 (if firewalld is active)
if command -v firewall-cmd >/dev/null 2>&1; then
  if sudo firewall-cmd --state 2>/dev/null | grep -q running; then
    echo "Step 5: Opening firewall port 3000..."
    sudo firewall-cmd --permanent --add-port=3000/tcp 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
  else
    echo "Step 5: Firewalld not running, skipping firewall config."
  fi
else
  echo "Step 5: firewalld not installed, skipping."
fi

# 6. Enable and start Grafana
echo "Step 6: Enabling and starting Grafana service..."
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server --no-pager || true

echo ""
echo "=== Grafana installation complete ==="
echo ""
echo "Access Grafana at: http://<VM-IP>:3000"
echo "  - VM public IP: use your VM's public IP (e.g. 137.131.53.98)"
echo "  - Default login: admin / admin"
echo "  - You will be prompted to change the password on first login."
echo ""
echo "If accessing from your laptop, ensure OCI Security List allows inbound TCP 3000."
echo ""
echo "Useful commands:"
echo "  sudo systemctl status grafana-server   # Check status"
echo "  sudo systemctl restart grafana-server   # Restart"
echo "  sudo journalctl -u grafana-server -f   # View logs"
echo ""
