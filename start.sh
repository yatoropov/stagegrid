#!/bin/bash
set -euo pipefail

### Конфігурація ###
SCRIPT_DIR="/home/toropov/stagegrid/shs"
LOG_DIR="/tmp/restream-logs"
MAIN_LOG="$LOG_DIR/start.log"
PID_FILE="/tmp/restream-pids/all.pids"
LOCK_FILE="${PID_FILE}.lock"
TARGETS_FILE="/tmp/targets.txt"
MAX_RETRIES=5                     # Збільшено кількість спроб
RETRY_DELAY=5                  # Збільшено затримку між спробами
HEALTH_CHECK_INTERVAL=1          # Інтервал перевірки стану (секунди)
INPUT="rtmp://127.0.0.1:1935/onlinestage/test"

### Ініціалізація ###
mkdir -p "$SCRIPT_DIR" "$LOG_DIR" "$(dirname "$PID_FILE")"
exec 3>&1 4>&2                   # Збереження оригінальних stdout/stderr
exec > >(tee -a "$MAIN_LOG") 2>&1 # Перенаправлення всіх виводів у лог

### Функції ###
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

cleanup() {
    log "Очищення перед виходом..."
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    log "Роботу завершено"
    exit ${1:-0}
}

check_dependencies() {
    local deps=("curl" "ffmpeg" "flock")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "ПОМИЛКА: Відсутня залежність - $dep"
            return 1
        fi
    done
}

### Головний код ###
trap 'cleanup 1' SIGINT SIGTERM   # Обробка сигналів
log "=== ЗАПУСК СИСТЕМИ РЕСТРІМУ ==="

# Перевірка залежностей
check_dependencies || cleanup 1

# Зупинка попередніх процесів
log "Зупинка старих процесів..."
if [[ -f "$PID_FILE" ]]; then
    while read -r pid; do
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] && ps -p "$pid" > /dev/null 2>&1; then
            log "Завершення процесу PID $pid..."
            kill "$pid" 2>/dev/null || true
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

# Завантаження конфігурації
log "Отримання конфігурації для $HOSTNAME..."
curl -sSf --connect-timeout 30 --retry 3 --ssl-reqd \
    "https://stage.pp.ua/$(hostname).txt" -o "$TARGETS_FILE" || {
    log "КРИТИЧНА ПОМИЛКА: Не вдалося завантажити конфігурацію"
    cleanup 1
}

dos2unix "$TARGETS_FILE" 2>/dev/null || sed -i 's/\r$//' "$TARGETS_FILE"

# Обробка цілей рестріму
log "Аналіз цілей рестріму..."
sleep $RETRY_DELAY
while IFS='|' read -r name url _; do
    name=$(echo "$name" | xargs | tr ' ' '_')
    url=$(echo "$url" | xargs)

    # Валідація даних
    if [[ -z "$name" || -z "$url" ]]; then
        log "Попередження: Пропущено пусту ціль"
        continue
    fi

    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "Попередження: Невірні символи в назві '$name'"
        continue
    fi

    # Створення скрипта
    script_file="$SCRIPT_DIR/${name}.sh"
    stream_log="$LOG_DIR/${name}_$(date +'%Y%m%d').log"

    log "Створення потоку '$name' → $url"
    
    cat <<EOF > "$script_file"
#!/bin/bash
set -euo pipefail

# Налаштування логування
exec >> "$stream_log" 2>&1
echo "=== [\$(date +'%Y-%m-%d %H:%M:%S')] Запуск потоку $name ==="

# Головний цикл
attempt=0
while [[ \$attempt -lt $MAX_RETRIES ]]; do
    echo "Спроба \$((attempt+1))/$MAX_RETRIES"

    ffmpeg -hide_banner -loglevel warning -stats \\
        -re -i "$INPUT" \\
        -c copy -f flv \\
        -flvflags no_duration_filesize \\
        "$url" &
        
    ffmpeg_pid=\$!
    ( flock -x 200; echo "\$ffmpeg_pid" >> "$PID_FILE"; ) 200>"$LOCK_FILE"

    wait \$ffmpeg_pid
    attempt=\$((attempt+1))
    sleep $RETRY_DELAY
done

echo "Досягнуто максимальну кількість спроб для $name"
EOF

    chmod +x "$script_file"
    sleep $HEALTH_CHECK_INTERVAL
    nohup bash "$script_file" &>/dev/null &
    log "Потік $name запущено (PID $!)"

done < <(grep -v '^#' "$TARGETS_FILE") # Ігноруємо коментарі у конфігурації

log "Усі потоки успішно запущені"
cleanup 0
