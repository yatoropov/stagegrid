#!/usr/bin/env bash
set -euo pipefail

# 📣 Отримуємо назву хоста
HOSTNAME=$(hostname)
CONFIG_URL="https://stage.pp.ua/${HOSTNAME}.txt"

# 📁 Шляхи
SCRIPT_DIR="/home/toropov/stagegrid/shs"
LOG_DIR="/tmp/restream-logs"

# 🧹 Очистка старих
rm -rf "$SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR" "$LOG_DIR"

# ⬇️ Завантаження цілей
echo "🔽 Завантажуємо конфіг з $CONFIG_URL..."
curl -sSf "$CONFIG_URL" -o /tmp/targets.txt

# ⏩ Обробка рядків виду: ім’я | url
while IFS='|' read -r NAME URL; do
  NAME=$(echo "$NAME" | xargs)  # обрізаємо пробіли
  URL=$(echo "$URL" | xargs)
  [[ -z "$NAME" || -z "$URL" ]] && continue

  SCRIPT_PATH="$SCRIPT_DIR/$NAME.sh"
  LOG_PATH="$LOG_DIR/$NAME.log"

  cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash

INPUT="rtmp://127.0.0.1:1935/onlinestage/test"
OUTPUT="$URL"

while true; do
    echo "[\$(date)] starting ffmpeg for $NAME" >> "$LOG_PATH"
    ffmpeg -re -i "\$INPUT" -c copy -f flv "\$OUTPUT" -ignore_unknown -shortest >> "$LOG_PATH" 2>&1
    echo "[\$(date)] ffmpeg exited for $NAME, retrying in 5s..." >> "$LOG_PATH"
    sleep 5
done
EOF

  chmod +x "$SCRIPT_PATH"
  echo "✅ Створено: $SCRIPT_PATH"
done < /tmp/targets.txt
