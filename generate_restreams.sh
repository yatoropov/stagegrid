#!/bin/bash
set -euo pipefail

# 🔧 Вхідний RTMP-потік
INPUT_STREAM="rtmp://127.0.0.1:1935/onlinestage/test"

# 📁 Куди генеруються скрипти
SCRIPT_DIR="/home/toropov/stagegrid/shs"
LOG_DIR="/home/toropov/stagegrid/restream-logs"

# Очистити папку та створити нову
rm -rf "$SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR" "$LOG_DIR"

# 📺 Список цільових платформ: "назва|rtmp_url"
TARGETS=(
  "facebook|rtmps://live-api-s.facebook.com:443/rtmp/FB-10223675608357278-0-Ab0Gy6c0ru8UrXzEoTNiiXYr"
  "youtube|rtmp://a.rtmp.youtube.com/live2/abhk-7rfx-2v7y-hrh2-3jcw"
  "restream|rtmp://live.restream.io/live/re_6887598_eventcbecc7788c8b4d07a1aade0632e2b270"
)

for entry in "${TARGETS[@]}"; do
    NAME="${entry%%|*}"
    URL="${entry##*|}"
    SCRIPT_PATH="$SCRIPT_DIR/$NAME.sh"
    LOG_PATH="$LOG_DIR/$NAME.log"

    cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash

INPUT="$INPUT_STREAM"
OUTPUT="$URL"

while true; do
    echo "[\$(date)] starting ffmpeg for $NAME" >> "$LOG_PATH"
    ffmpeg -re -i "\$INPUT" -c copy -f flv "\$OUTPUT" -ignore_unknown -shortest >> "$LOG_PATH" 2>&1
    echo "[\$(date)] ffmpeg exited for $NAME, retrying in 5s..." >> "$LOG_PATH"
    sleep 5
done
EOF

    chmod +x "$SCRIPT_PATH"
    echo "✅ Created $SCRIPT_PATH"
done
