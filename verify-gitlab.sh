#!/bin/bash

set -e

HOST_ENTRY="127.0.0.1 gitlab.example.com"
HOSTS_FILE="/etc/hosts"
HOSTNAME="gitlab.example.com"
URL="https://$HOSTNAME"
TIMEOUT=3
ALLOW_SELF_SIGNED=true

echo "🔧 Starting GitLab connectivity diagnostics..."

# Check /etc/hosts
echo ""
echo "🔍 Step 1: Checking /etc/hosts entry..."
if grep -q "$HOST_ENTRY" "$HOSTS_FILE"; then
    echo "✅ Found /etc/hosts entry: $HOST_ENTRY"
else
    echo "❌ /etc/hosts is missing required entry: $HOST_ENTRY"
    echo "Add it manually with:"
    echo "  echo \"$HOST_ENTRY\" | sudo tee -a $HOSTS_FILE"
    exit 1
fi

# Resolve hostname using ping (respects /etc/hosts)
echo ""
echo "🔍 Step 2: Resolving $HOSTNAME to IP..."
RESOLVED_IP=$(ping -c 1 "$HOSTNAME" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
if [ -z "$RESOLVED_IP" ]; then
    echo "❌ Could not resolve $HOSTNAME. Check /etc/hosts."
    exit 1
fi
echo "✅ Resolved $HOSTNAME to $RESOLVED_IP"

# Ping test
echo ""
echo "🔍 Step 3: Pinging $RESOLVED_IP..."
if ping -c 1 -W 1 "$RESOLVED_IP" > /dev/null 2>&1; then
    echo "✅ Ping successful"
else
    echo "⚠️ Ping failed (may be expected if ICMP blocked)"
fi

# HTTPS connection test
echo ""
echo "🔍 Step 4: Testing HTTPS connection to $URL..."
CURL_OPTS="-v --max-time $TIMEOUT --silent --show-error --fail"
if $ALLOW_SELF_SIGNED; then
    CURL_OPTS="-k $CURL_OPTS"
    echo "⚠️ Allowing self-signed certs (insecure)"
fi

if curl $CURL_OPTS "$URL" -o /dev/null; then
    echo "✅ HTTPS connection successful"
else
    echo "❌ HTTPS connection failed"
fi

# Check port 443 listeners without sudo first
echo ""
echo "🔍 Step 5: Checking for processes listening on port 443..."
LISTENER=""
if command -v lsof >/dev/null 2>&1; then
    LISTENER=$(lsof -iTCP:443 -sTCP:LISTEN 2>/dev/null || true)
fi
if [ -z "$LISTENER" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "⚠️ No listener found on port 443, trying with sudo..."
        if command -v lsof >/dev/null 2>&1; then
            LISTENER=$(sudo lsof -iTCP:443 -sTCP:LISTEN 2>/dev/null || true)
        fi
    fi
fi

if [ -n "$LISTENER" ]; then
    echo "✅ Process(es) listening on port 443:"
    echo "$LISTENER"
else
    echo "❌ No process listening on port 443 found."
    echo "   Make sure your reverse proxy (Caddy) is running and listening on port 443."
fi

# Docker daemon check
echo ""
echo "🔍 Step 6: Checking Docker daemon and containers..."
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker daemon is running."
        echo "🐳 Running containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
    else
        echo "❌ Docker daemon is NOT running."
    fi
else
    echo "⚠️ Docker is not installed."
fi

# Check Caddy process
echo ""
echo "🔍 Step 7: Checking for Caddy process..."
if pgrep -x caddy >/dev/null 2>&1; then
    echo "✅ Caddy process is running."
else
    echo "❌ Caddy process not found."
    echo "   Try starting it with: sudo systemctl start caddy"
    echo "   Or, if you use Docker compose, run: docker-compose up -d caddy"
fi

echo ""
echo "🏁 Diagnostics complete."
echo "Try accessing $URL in your browser."
