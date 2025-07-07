#!/bin/bash
set -euo pipefail

SCRIPT_DIR="/home/toropov/stagegrid/shs"
LOG_DIR="/tmp/restream-logs"
PID_FILE="/tmp/restream-pids/all.pids"
LOCK_FILE="${PID_FILE}.lock"
TARGETS_FILE="/tmp/targets.txt"
MAX_RETRIES=3
RETRY_DELAY=5

mkdir -p "$SCRIPT_DIR" "$LOG_DIR" "$(dirname "$PID_FILE")"

# 🛑 Зупинка старих процесів
echo "[start.sh] Killing old processes..."
if [[ -f "$PID_FILE" ]]; then
  while read -r pid; do
    if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] && ps -p "$pid" > /dev/null 2>&1; then
      echo "[start.sh] Killing PID $pid"
      kill "$pid" || true
    fi
  done < "$PID_FILE"
  rm -f "$PID_FILE"
fi

# 🧹 Очистка скриптів і логів
rm -rf "$SCRIPT_DIR"/*
rm -rf "$LOG_DIR"/*

# ⬇️ Завантаження конфігу
HOSTNAME=$(hostname)
CONFIG_URL="https://stage.pp.ua/${HOSTNAME}.txt"
echo "[start.sh] Fetching config from $CONFIG_URL"
curl -sSf --ssl-reqd "$CONFIG_URL" -o "$TARGETS_FILE"

# 🧽 Нормалізація: DOS → UNIX
if ! command -v dos2unix &> /dev/null; then
  sed -i 's/\r$//' "$TARGETS_FILE"
else
  dos2unix "$TARGETS_FILE" 2>/dev/null || true
fi

# 🔁 Обробка конфігу
echo "[start.sh] Parsing targets from $TARGETS_FILE..."
while IFS='|' read -r NAME URL || [[ -n "$NAME" ]]; do
  NAME=$(echo "$NAME" | xargs)
  URL=$(echo "$URL" | xargs)

  # 💡 Перевірка безпеки
  if [[ -z "$NAME" || -z "$URL" ]]; then
    echo "[skip] Empty name or URL → NAME='$NAME' URL='$URL'"
    continue
  fi

  if [[ ! "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "[skip] Invalid characters in NAME: $NAME"
    continue
  fi

  SCRIPT_PATH="$SCRIPT_DIR/$NAME.sh"
  LOG_PATH="$LOG_DIR/${NAME}_$(date +%Y%m%d).log"
  INPUT="rtmp://127.0.0.1:1935/onlinestage/test"

  echo "[create] $SCRIPT_PATH → $URL"

  cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
set -euo pipefail

trap 'kill \$(jobs -p); wait; exit 0' SIGTERM SIGINT

retry_count=0
while [[ \$retry_count -lt $MAX_RETRIES ]]; do
  echo "[\$(date)] Starting ffmpeg for $NAME" >> "$LOG_PATH"
  ffmpeg -re -i "$INPUT" -c copy -f flv "$URL" -ignore_unknown -shortest >> "$LOG_PATH" 2>&1 &
  FFMPEG_PID=\$!
  
  # Захищений запис PID
  ( flock -x 200; echo "\$FFMPEG_PID" >> "$PID_FILE"; ) 200>"$LOCK_FILE"

  wait \$FFMPEG_PID
  retry_count=\$((retry_count + 1))
  echo "[\$(date)] FFmpeg exited for $NAME (retry \$retry_count/$MAX_RETRIES)" >> "$LOG_PATH"
  sleep $RETRY_DELAY
done
EOF

  chmod +x "$SCRIPT_PATH"
  bash "$SCRIPT_PATH" &
done < "$TARGETS_FILE"
