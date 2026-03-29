#!/bin/bash

# Updates stats every X amount of time
# Executed by cron inside the Caddy container

set -e

# Paths
DATA="/var/www/cursos"
STATS_JSON="/var/www/frontend/stats.json"
LOG_FILE="/var/log/cursoteca/stats-update.log"
CADDY_LOG="/var/log/caddy/access.log"

mkdir -p /var/log/cursoteca

# Count courses
TOTAL_COURSES=$(
    find "$DATA" -maxdepth 1 -type d ! -name ".*" 2>/dev/null | tail -n +2 | wc -l
)

# Calculate storage
STORAGE_BYTES=$(
  du -sb "$DATA" 2>/dev/null | awk '{print $1}' || echo 0
)

STORAGE_GB=$(
  echo "scale=2; $STORAGE_BYTES / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0.00"
)

STORAGE_TB=$(
  echo "scale=2; $STORAGE_BYTES / 1024 / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0.00"
)

# Files count
TOTAL_FILES=$(
  find "$DATA" -type f 2>/dev/null | wc -l || echo 0
)

# Count downloads
DOWNLOAD_COUNT=0
UNIQUE_IPS=0

if [ -f "$CADDY_LOG" ]; then
  # Counts the number of GET requests in the Caddy log
  DOWNLOAD_COUNT=$(
    grep -c '"method":"GET"' "$CADDY_LOG" 2>/dev/null || echo 0
  )
  
  # Counts unique IPs that made GET requests in the Caddy log
  UNIQUE_IPS=$(
    grep '"method":"GET"' "$CADDY_LOG" 2>/dev/null | \
    grep -o '"remote_addr":"[^"]*' | \
    cut -d'"' -f4 | \
    sort -u | \
    wc -l || echo 0
  )
fi

# Timestamps for last update
LAST_UPDATE=$(date '+%Y-%m-%d %H:%M:%S')
TIMESTAMP_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Create stats JSON
cat > "$STATS_JSON" << EOF
{
  "total_courses": $TOTAL_COURSES,
  "storage_gb": $STORAGE_GB,
  "storage_tb": $STORAGE_TB,
  "storage_bytes": $STORAGE_BYTES,
  "total_files": $TOTAL_FILES,
  "download_count": $DOWNLOAD_COUNT,
  "unique_ips": $UNIQUE_IPS,
  "last_update": "$LAST_UPDATE",
  "timestamp_iso": "$TIMESTAMP_ISO"
}
EOF

# Logging
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Stats actualizado: Cursos=$TOTAL_COURSES, Storage=$STORAGE_GB GB, Archivos=$TOTAL_FILES" >> "$LOG_FILE"