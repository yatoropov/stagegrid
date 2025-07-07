#!/bin/bash
set -euo pipefail

SCRIPT_DIR="/home/toropov/stagegrid/shs"
LOG_DIR="/tmp/restream-logs"
MAIN_LOG="/tmp/restream-logs/start.log"
PID_FILE="/tmp/restream-pids/all.pids"
LOCK_FILE="${PID_FILE}.lock"
TARGETS_FILE="/tmp/targets.txt"
MAX_RETRIES=3
RETRY_DELAY=5

# Створення необхідних директорій
mkdir -p "$SCRIPT_DIR" "$LOG_DIR" "$(dirname "$PID_FILE")"

# Функція логування
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$MAIN_LOG"
}

# 🛑 Зупинка старих процесів
log "=== Starting script ==="
log "Killing old processes..."
if [[ -f "$PID_FILE" ]]; then
    while read -r pid; do
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] && ps -p "$pid" > /dev/null 2>&1; then
            log "Killing PID $pid"
            kill "$pid" || true
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

# 🧹 Очистка
log "Cleaning old scripts and logs..."
rm -rf "$SCRIPT_DIR"/*
rm -rf "$LOG_DIR"/*
touch "$MAIN_LOG"

# ⬇️ Завантаження конфігу
HOSTNAME=$(hostname)
CONFIG_URL="https://stage.pp.ua/${HOSTNAME}.txt"
log "Fetching config from $CONFIG_URL"
curl -sSf --ssl-reqd "$CONFIG_URL" -o "$TARGETS_FILE" || {
    log "ERROR: Failed to download config from $CONFIG_URL"
    exit 1
}

# 🧽 Нормалізація
if ! command -v dos2unix &> /dev/null; then
    sed -i 's/\r$//' "$TARGETS_FILE"
else
    dos2unix "$TARGETS_FILE" 2>/dev/null || true
fi

# 🔁 Обробка конфігу
log "Parsing targets from $TARGETS_FILE..."
while IFS='|' read -r NAME URL || [[ -n "$NAME" ]]; do
    NAME=$(echo "$NAME" | xargs)
    URL=$(echo "$URL" | xargs)

    # Перевірка безпеки
    if [[ -z "$NAME" || -z "$URL" ]]; then
        log "[skip] Empty name or URL → NAME='$NAME' URL='$URL'"
        continue
    fi

    if [[ ! "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "[skip] Invalid characters in NAME: $NAME"
        continue
    fi

    SCRIPT_PATH="$SCRIPT_DIR/$NAME.sh"
    STREAM_LOG="$LOG_DIR/${NAME}.log"
    INPUT="rtmp://127.0.0.1:1935/onlinestage/test"

    log "Creating stream script: $SCRIPT_PATH → $URL"

    # Генерація скрипта для потоку
    cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
set -euo pipefail

trap 'kill \$(jobs -p); wait; exit 0' SIGTERM SIGINT

# Функція для коректного логування
stream_log() {
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] \$1" >> "$STREAM_LOG"
}

# Виправлення форматування виводу FFmpeg
clean_ffmpeg_output() {
    while IFS= read -r line; do
        # Видаляємо контрольні символи (^M)
        line=\$(echo "\$line" | tr -d '\r')
        # Додаємо в лог з часовою міткою
        echo "[\$(date +'%Y-%m-%d %H:%M:%S')] FFmpeg: \$line" >> "$STREAM_LOG"
    done
}

retry_count=0
while [[ \$retry_count -lt $MAX_RETRIES ]]; do
    stream_log "Starting ffmpeg for $NAME"
    
    # Запис PID процесу
    echo \$\$ > "$PID_FILE"
    
    # Запуск FFmpeg з коректним логуванням
    ffmpeg \\
        -hide_banner \\
        -loglevel warning \\
        -stats \\
        -re \\
        -i "$INPUT" \\
        -c copy \\
        -f flv \\
        -ignore_unknown \\
        -shortest \\
        "$URL" 2>&1 | clean_ffmpeg_output &
    
    FFMPEG_PID=\$!
    echo \$FFMPEG_PID >> "$PID_FILE"
    
    wait \$FFMPEG_PID
    EXIT_CODE=\$?
    retry_count=\$((retry_count + 1))
    
    if [[ \$EXIT_CODE -eq 0 ]]; then
        stream_log "FFmpeg completed successfully"
        break
    else
        stream_log "FFmpeg failed (attempt \$retry_count/$MAX_RETRIES). Exit code: \$EXIT_CODE"
        [[ \$retry_count -lt $MAX_RETRIES ]] && sleep $RETRY_DELAY
    fi
done

if [[ \$retry_count -eq $MAX_RETRIES ]]; then
    stream_log "ERROR: Max retries reached. Giving up."
fi
EOF

    chmod +x "$SCRIPT_PATH"
    bash "$SCRIPT_PATH" &
    log "Started stream '$NAME' with PID $!"
done < "$TARGETS_FILE"

log "All streams started successfully"
log "=== Script completed ==="
