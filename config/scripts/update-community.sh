#!/bin/bash

# Fetches AECCI Discord community stats via Discord's public invite endpoint
# (no auth). Executed by cron inside the Caddy container, alongside
# update-stats.sh. Fail-soft: on any error it leaves the previous
# community.json untouched rather than writing empty/zero data.

set -e

# Paths + config. Paths are overridable so the script is testable outside the
# container (WSL/dev); production leaves them at the defaults.
COMMUNITY_JSON="${COMMUNITY_JSON:-/var/www/frontend/community.json}"
LOG_FILE="${LOG_FILE:-/var/log/cursoteca/community-update.log}"
INVITE_CODE="${DISCORD_INVITE_CODE:-gfm5HUt7wy}"   # override in tests
API_URL="https://discord.com/api/v9/invites/${INVITE_CODE}?with_counts=true"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Fetch. curl -f => non-zero on HTTP >=400; guard keeps the old file.
RESPONSE=$(curl -fsS --max-time 10 "$API_URL" 2>>"$LOG_FILE") || {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✗ Discord fetch falló; se conserva community.json anterior" >> "$LOG_FILE"
  exit 0
}

MEMBERS=$(echo "$RESPONSE" | jq -r '.approximate_member_count // empty' 2>/dev/null) || MEMBERS=""
ONLINE=$(echo "$RESPONSE"  | jq -r '.approximate_presence_count // empty' 2>/dev/null) || ONLINE=""

# Both must be non-negative integers, and members must be > 0, else keep old file.
if ! [[ "$MEMBERS" =~ ^[0-9]+$ ]] || ! [[ "$ONLINE" =~ ^[0-9]+$ ]] || [ "$MEMBERS" -eq 0 ]; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✗ Payload inesperado (members=$MEMBERS online=$ONLINE); se conserva community.json anterior" >> "$LOG_FILE"
  exit 0
fi

TIMESTAMP_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Atomic write: temp file in the SAME directory, then mv.
TMP=$(mktemp "$(dirname "$COMMUNITY_JSON")/.community.XXXXXX")
cat > "$TMP" << EOF
{
  "discord": { "members": $MEMBERS, "online": $ONLINE },
  "updated_at": "$TIMESTAMP_ISO"
}
EOF
mv "$TMP" "$COMMUNITY_JSON"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Community actualizado: members=$MEMBERS, online=$ONLINE" >> "$LOG_FILE"
