#!/bin/bash
# Скрипт для определения срока действия SSL-сертификата для домена bashdays.com
# и формирования файла метрик Prometheus для Node Exporter

MAINDIR="/tmp"
METRICS="ssl_cert_expiry.prom"
DOMAIN="bashdays.com"
PORT=443

# Проверяем, установлен ли openssl
if ! command -v openssl &>/dev/null; then
  echo "openssl не установлен. Пожалуйста, установите openssl."
  exit 1
fi

# Получаем дату истечения сертификата
EXPIRY_DATE=$(echo | openssl s_client -connect ${DOMAIN}:${PORT} -servername ${DOMAIN} 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
if [ -z "$EXPIRY_DATE" ]; then
  echo "Не удалось получить дату истечения сертификата для ${DOMAIN}"
  exit 1
fi

# Конвертируем дату в секунды с начала эпохи
EXPIRY_SEC=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
if [ -z "$EXPIRY_SEC" ]; then
  echo "Ошибка конвертации даты: $EXPIRY_DATE"
  exit 1
fi

# Получаем текущее время в секундах
CURRENT_SEC=$(date +%s)

# Вычисляем оставшиеся секунды и переводим в дни
DIFF_SEC=$(( EXPIRY_SEC - CURRENT_SEC ))
if [ $DIFF_SEC -lt 0 ]; then
  DIFF_DAYS=0
else
  DIFF_DAYS=$(( DIFF_SEC / 86400 ))
fi

# Формируем файл метрик для Prometheus
echo "ssl_certificate_expiry_days{domain=\"${DOMAIN}\"} ${DIFF_DAYS}" > $MAINDIR/$METRICS

# Устанавливаем права, чтобы Node Exporter мог прочитать файл
chmod 644 $MAINDIR/$METRICS

echo "Сертификат для ${DOMAIN} истекает через ${DIFF_DAYS} дней."
echo "Метрика записана в $MAINDIR/$METRICS"

