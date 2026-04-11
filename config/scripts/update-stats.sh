#!/bin/bash

# Updates stats every X amount of time
# Executed by cron inside the Caddy container

set -e

# Paths
DATA="/var/www/cursos"
STATS_JSON="/var/www/frontend/stats.json"
LOG_FILE="/var/log/cursoteca/stats-update.log"

mkdir -p /var/log/cursoteca

# Count courses
TOTAL_COURSES=$(
  find "$DATA" -mindepth 3 -maxdepth 3 -type d ! -name ".*" ! -name "X_*" 2>/dev/null | wc -l
)

# Calculate storage
STORAGE_BYTES=$(
  du -sb "$DATA" 2>/dev/null | awk '{print $1}' || echo 0
)

STORAGE_GB=$(
  echo "scale=2; $STORAGE_BYTES / 1024 / 1024 / 1024" | bc 2>/dev/null | awk '{printf "%.2f", $0}' || echo "0.00"
)

STORAGE_TB=$(
  echo "scale=2; $STORAGE_BYTES / 1024 / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0.00"
)

# Files count
TOTAL_FILES=$(
  find "$DATA" -type f -name ".*" 2>/dev/null | wc -l || echo 0
)

# Last update of data/ directory (via git pull from GitHub Actions)
if [ -f "/var/www/cursos/.git/FETCH_HEAD" ]; then
  DATA_EPOCH=$(stat -c '%Y' /var/www/cursos/.git/FETCH_HEAD 2>/dev/null || echo "")
else
  DATA_EPOCH=""
fi

if [ -n "$DATA_EPOCH" ] && [ "$DATA_EPOCH" -gt 0 ] 2>/dev/null; then
  # Container runs in UTC; date -d @epoch gives UTC time
  LAST_UPDATE=$(date -d "@$DATA_EPOCH" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
  TIMESTAMP_ISO=$(date -d "@$DATA_EPOCH" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')
else
  # Fallback: use current time if FETCH_HEAD not available
  LAST_UPDATE=$(date '+%Y-%m-%d %H:%M:%S')
  TIMESTAMP_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
fi

# Create stats JSON
cat > "$STATS_JSON" << EOF
{
  "total_courses": $TOTAL_COURSES,
  "storage_gb": $STORAGE_GB,
  "storage_tb": $STORAGE_TB,
  "storage_bytes": $STORAGE_BYTES,
  "total_files": $TOTAL_FILES,
  "last_update": "$LAST_UPDATE",
  "timestamp_iso": "$TIMESTAMP_ISO"
}
EOF

# Logging
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Stats actualizado: Cursos=$TOTAL_COURSES, Storage=$STORAGE_GB GB, Archivos=$TOTAL_FILES, Última actualización de datos=$LAST_UPDATE" >> "$LOG_FILE"