#!/bin/bash
# ============================================
#  MTProto Proxy — установка одной командой
# ============================================
set -e

echo ""
echo "🛡  Установка MTProto Proxy для Telegram"
echo "========================================="
echo ""

# 1. Docker
if ! command -v docker &>/dev/null; then
    echo "📦 Устанавливаю Docker..."
    apt-get update -qq
    apt-get install -y -qq docker.io >/dev/null 2>&1
    systemctl enable --now docker >/dev/null 2>&1
    echo "   ✅ Docker установлен"
else
    echo "   ✅ Docker уже установлен"
fi

echo ""

# 2. Выбор порта
read -p "Введите порт для прокси (по умолчанию 8443): " PORT
PORT=${PORT:-8443}

# Проверка порта
if ss -tuln | grep -q ":$PORT "; then
    echo "❌ Порт $PORT уже занят!"
    echo "Попробуйте другой."
    exit 1
fi

echo "🌐 Используется порт: $PORT"

# 3. Генерируем fake-TLS секрет
RAND_PART=$(head -c 16 /dev/urandom | xxd -ps -c 256)
SECRET="ee${RAND_PART}7777772e676f6f676c652e636f6d"
echo "🔑 Сгенерирован fake-TLS секрет"

# 4. Определяем IP
IP=$(curl -4 -s ifconfig.me || curl -4 -s icanhazip.com || hostname -I | awk '{print $1}')
echo "🌐 IP сервера: $IP"

# 5. Создаём конфиг
mkdir -p /opt/mtg
cat > /opt/mtg/config.toml <<EOF
secret = "${SECRET}"
bind-to = "0.0.0.0:3128"
prefer-ip = "prefer-ipv4"
allow-fallback-on-unknown-dc = true
concurrency = 8192
tolerate-time-skewness = "5s"

[network]
doh-ip = "1.1.1.1"

[network.timeout]
tcp = "10s"
http = "10s"
idle = "60s"
EOF

# 6. Удаляем старый контейнер
docker rm -f mtg 2>/dev/null || true

# 7. Запускаем
echo "🚀 Запускаю прокси..."
docker run -d \
    --name mtg \
    --restart always \
    -p ${PORT}:3128 \
    -v /opt/mtg/config.toml:/config.toml:ro \
    nineseconds/mtg:2 run /config.toml >/dev/null

sleep 2

# 8. Проверка
if docker ps | grep -q mtg; then
    echo "   ✅ Прокси запущен"
else
    echo "   ❌ Ошибка запуска! Логи:"
    docker logs mtg
    exit 1
fi

# 9. Ссылка
LINK="https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"

echo ""
echo "========================================="
echo "✅ Готово! Ваш прокси работает."
echo ""
echo "📎 Ссылка для подключения:"
echo ""
echo "   $LINK"
echo ""
echo "Отправьте эту ссылку в Telegram и нажмите"
echo "«Подключить прокси»."
echo "========================================="
