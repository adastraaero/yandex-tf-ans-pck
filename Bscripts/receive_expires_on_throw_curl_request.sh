#!/bin/bash
# Скрипт для получения даты истечения домена click.to через whois.com,
# вычисления оставшихся дней и формирования файла метрик для Prometheus (Node Exporter)

# Каталог для файла метрик (Node Exporter читает из /tmp)
MAINDIR="/tmp"
METRICS="click_to_expiry.prom"
DOMAIN="click.to"
URL="https://www.whois.com/whois/${DOMAIN}"

# Загружаем HTML-страницу с whois.com
HTML=$(curl -s "$URL")
if [ -z "$HTML" ]; then
  echo "Не удалось загрузить страницу $URL"
  exit 1
fi

# Извлекаем строку с датой истечения.
# Предположим, что в HTML присутствует блок <pre> с информацией, где есть строка вида:
# "Expires on:           Sat May 03 03:27:54 2025"
EXPIRE_LINE=$(echo "$HTML" | grep -i "Expires on:" | head -n1)
if [ -z "$EXPIRE_LINE" ]; then
  echo "Не удалось найти строку 'Expires on:' в HTML"
  exit 1
fi

# Убираем HTML-теги (если они есть) и извлекаем дату после "Expires on:"
EXPIRY_DATE=$(echo "$EXPIRE_LINE" | sed -E 's/<[^>]*>//g' | sed -E 's/.*Expires on:[[:space:]]*//I' | tr -d '\r')
if [ -z "$EXPIRY_DATE" ]; then
  echo "Не удалось извлечь дату из строки: $EXPIRE_LINE"
  exit 1
fi

echo "Найденная дата истечения: $EXPIRY_DATE"

# Преобразуем дату в Unix-время (секунды с 1 января 1970)
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
if [ -z "$EXPIRY_EPOCH" ]; then
  # Если формат не распознаётся, попробуем удалить символы T и Z
  CLEAN_DATE=$(echo "$EXPIRY_DATE" | sed 's/T/ /; s/Z//')
  EXPIRY_EPOCH=$(date -d "$CLEAN_DATE" +%s 2>/dev/null)
fi
if [ -z "$EXPIRY_EPOCH" ]; then
  echo "Не удалось преобразовать дату '$EXPIRY_DATE' в Unix-время"
  exit 1
fi

# Получаем текущее время и вычисляем разницу в секундах и днях
CURRENT_EPOCH=$(date +%s)
DIFF_SEC=$(( EXPIRY_EPOCH - CURRENT_EPOCH ))
if [ $DIFF_SEC -lt 0 ]; then
  DIFF_DAYS=0
else
  DIFF_DAYS=$(( DIFF_SEC / 86400 ))
fi

# Формируем файл метрик для Prometheus (формат textfile collector)
echo "domain_expiry_days{domain=\"${DOMAIN}\"} ${DIFF_DAYS}" > "${MAINDIR}/${METRICS}"
chmod 644 "${MAINDIR}/${METRICS}"

echo "Домен ${DOMAIN} истекает через ${DIFF_DAYS} дней."
echo "Файл метрик записан: ${MAINDIR}/${METRICS}"

