#!/bin/bash
set -euo pipefail

SCRIPT_DIR="/home/toropov/stagegrid/shs"
LOG_DIR="/tmp/restream-logs"
PID_FILE="/tmp/restream-pids/all.pids"

mkdir -p "$SCRIPT_DIR" "$LOG_DIR" "$(dirname "$PID_FILE")"

# 🛑 Зупинка старих процесів
echo "[start.sh] Killing old processes..."
if [[ -f "$PID_FILE" ]]; then
  while read -r pid; do
    if [[ -n "$pid" ]] && ps -p "$pid" > /dev/null 2>&1; then
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
curl -sSf "$CONFIG_URL" -o /tmp/targets.txt

# 🔁 Генерація і запуск
while IFS='|' read -r NAME URL; do
  NAME=$(echo "$NAME" | xargs)
  URL=$(echo "$URL" | xargs)
  [[ -z "$NAME" || -z "$URL" ]] && continue

  SCRIPT_PATH="$SCRIPT_DIR/$NAME.sh"
  LOG_PATH="$LOG_DIR/$NAME.log"
  INPUT="rtmp://127.0.0.1:1935/onlinestage/test"

  cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
while true; do
  echo "[\$(date)] starting ffmpeg for $NAME" >> "$LOG_PATH"
  ffmpeg -re -i "$INPUT" -c copy -f flv "$URL" -ignore_unknown -shortest >> "$LOG_PATH" 2>&1 &
  FFMPEG_PID=\$!
  echo \$\$ >> "$PID_FILE"      # bash-процес
  echo \$FFMPEG_PID >> "$PID_FILE"  # ffmpeg
  wait \$FFMPEG_PID
  echo "[\$(date)] ffmpeg exited for $NAME, retrying in 5s..." >> "$LOG_PATH"
  sleep 5
done
EOF

  chmod +x "$SCRIPT_PATH"
  bash "$SCRIPT_PATH" &
done < /tmp/targets.txt
