#!/bin/bash

set -e

# === Config ===
HOST_ENTRY="127.0.0.1 gitlab.example.com"
HOSTS_FILE="/etc/hosts"
HOSTNAME="gitlab.example.com"
URL="https://$HOSTNAME"
TIMEOUT=3
ALLOW_SELF_SIGNED=true  # Set to false to disable -k (insecure SSL)

echo "🔧 Starting GitLab connectivity diagnostics..."

# === Step 1: Check /etc/hosts ===
echo ""
echo "🔍 Step 1: Checking /etc/hosts entry..."
if grep -q "$HOST_ENTRY" "$HOSTS_FILE"; then
    echo "✅ Found /etc/hosts entry: $HOST_ENTRY"
else
    echo "❌ /etc/hosts is missing required entry: $HOST_ENTRY"
    echo "➡️  Add it manually or run:"
    echo "    echo \"$HOST_ENTRY\" | sudo tee -a $HOSTS_FILE"
    exit 1
fi

# === Step 2: DNS resolution (cross-platform) ===
echo ""
echo "🔍 Step 2: Resolving $HOSTNAME to an IP address..."
RESOLVED_IP=""

if command -v dig >/dev/null 2>&1; then
    echo "ℹ️  Using dig..."
    RESOLVED_IP=$(dig +short "$HOSTNAME" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
elif command -v host >/dev/null 2>&1; then
    echo "ℹ️  Using host..."
    RESOLVED_IP=$(host "$HOSTNAME" | grep "has address" | awk '{ print $4 }' | head -n 1)
elif command -v nslookup >/dev/null 2>&1; then
    echo "ℹ️  Using nslookup..."
    RESOLVED_IP=$(nslookup "$HOSTNAME" | awk '/^Address: / { print $2 }' | tail -n 1)
else
    echo "⚠️ No DNS tools (dig, host, nslookup) found. Trying /etc/hosts..."
    RESOLVED_IP=$(grep "$HOSTNAME" "$HOSTS_FILE" | awk '{ print $1 }' | head -n 1)
fi

if [ -n "$RESOLVED_IP" ]; then
    echo "✅ Resolved $HOSTNAME to $RESOLVED_IP"
else
    echo "❌ DNS resolution failed for $HOSTNAME"
    exit 1
fi

# === Step 3: Ping resolved IP ===
echo ""
echo "🔍 Step 3: Pinging resolved IP to test basic connectivity..."
if ping -c 1 -W 1 "$RESOLVED_IP" > /dev/null 2>&1; then
    echo "✅ Ping to $RESOLVED_IP successful"
else
    echo "⚠️ Ping to $RESOLVED_IP failed (may be expected if ICMP is blocked)"
fi

# === Step 4: HTTPS connection ===
echo ""
echo "🔍 Step 4: Attempting HTTPS connection to $URL with ${TIMEOUT}s timeout..."
if [ "$ALLOW_SELF_SIGNED" = true ]; then
    echo "⚠️ Allowing self-signed certificates (insecure)"
    CURL_OPTS="-vk"
else
    CURL_OPTS="-v"
fi

if curl $CURL_OPTS --max-time "$TIMEOUT" --silent --show-error --fail "$URL" -o /dev/null; then
    echo "✅ Successfully connected to $URL"
else
    echo "❌ Failed to connect to $URL"
    echo "   🔧 Possible causes:"
    echo "   - GitLab is not running"
    echo "   - Reverse proxy (e.g., Caddy) is not forwarding correctly"
    echo "   - Self-signed certificate issue (try ALLOW_SELF_SIGNED=true)"
    echo "   - Local firewall, Docker, or network misconfiguration"
fi

# === Step 5: Port 443 listener check ===
echo ""
echo "🔍 Step 5: Checking if anything is listening on port 443..."
LISTENER=""
if command -v lsof >/dev/null 2>&1; then
    LISTENER=$(sudo lsof -iTCP:443 -sTCP:LISTEN)
elif command -v netstat >/dev/null 2>&1; then
    LISTENER=$(sudo netstat -tuln | grep ':443')
elif command -v ss >/dev/null 2>&1; then
    LISTENER=$(sudo ss -tuln | grep ':443')
else
    echo "⚠️ Could not find lsof, netstat, or ss to check open ports."
fi

if [ -n "$LISTENER" ]; then
    echo "✅ Found a process listening on port 443:"
    echo "$LISTENER"
else
    echo "❌ Nothing is listening on port 443"
    echo "   ➕ Your reverse proxy (e.g., Caddy or Nginx) may not be running or misconfigured"
fi

# === Step 6: Docker status check ===
echo ""
echo "🔍 Step 6: Checking Docker status..."
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker daemon is running"
        echo "🐳 Docker containers:"
        docker ps
    else
        echo "❌ Docker is installed but the daemon is not running"
    fi
else
    echo "⚠️ Docker not found on this system"
fi

# === Step 7: Caddy check ===
echo ""
echo "🔍 Step 7: Checking for Caddy process..."
if pgrep -x caddy >/dev/null 2>&1; then
    echo "✅ Caddy is running"
else
    echo "❌ Caddy is not running"
    echo "   🔧 Start it manually or via systemd/docker-compose if you’re using it"
fi

# === Final Message ===
echo ""
echo "🏁 Diagnostics complete."
echo "🔗 Expected URL: $URL"
echo "➡️ Default GitLab login: root / YourInsecureTestPasswordHere"
