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
  find "$DATA" -type f 2>/dev/null | wc -l || echo 0
)

# Count downloads and data transfer
DOWNLOAD_COUNT=0
UNIQUE_IPS=0
DOWNLOAD_BYTES=0
DOWNLOADED_GB="0.00"

if [ -f "$CADDY_LOG" ]; then
  # Filter valid file downloads: GET requests to /cursos/ that do not end in /, successful status
  # Note: grep -a is used to treat log as text
  FILE_REQS=$(grep -a '"method":"GET"' "$CADDY_LOG" 2>/dev/null | grep -a -E '"uri":"/cursos/[^"]*[^/]"' | grep -a -E '"status":(200|206)' || true)
  
  if [ -n "$FILE_REQS" ]; then
    DOWNLOAD_COUNT=$(echo "$FILE_REQS" | wc -l | awk '{print $1}')
    
    # Calculate downloaded bytes summing the "size" field
    DOWNLOAD_BYTES=$(echo "$FILE_REQS" | grep -a -o '"size":[0-9]*' | cut -d: -f2 | awk '{s+=$1} END {if(s=="") print 0; else print s}' || echo 0)
    DOWNLOADED_GB=$(echo "scale=2; $DOWNLOAD_BYTES / 1024 / 1024 / 1024" | bc 2>/dev/null | awk '{printf "%.2f", $0}' || echo "0.00")
    
    # Extract unique IPs (Caddy standard is remote_ip, fallback to remote_addr)
    UNIQUE_IPS=$(echo "$FILE_REQS" | grep -a -o '"remote_ip":"[^"]*' | cut -d'"' -f4 | cut -d: -f1 | sort -u | wc -l | awk '{print $1}')
    
    if [ "$UNIQUE_IPS" -eq 0 ]; then
      UNIQUE_IPS=$(echo "$FILE_REQS" | grep -a -o '"remote_addr":"[^"]*' | cut -d'"' -f4 | cut -d: -f1 | sort -u | wc -l | awk '{print $1}')
    fi
  fi
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
  "downloaded_gb": $DOWNLOADED_GB,
  "unique_ips": $UNIQUE_IPS,
  "last_update": "$LAST_UPDATE",
  "timestamp_iso": "$TIMESTAMP_ISO"
}
EOF

# Logging
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Stats actualizado: Cursos=$TOTAL_COURSES, Storage=$STORAGE_GB GB, Archivos=$TOTAL_FILES, Descargas=$DOWNLOAD_COUNT ($DOWNLOADED_GB GB)" >> "$LOG_FILE"