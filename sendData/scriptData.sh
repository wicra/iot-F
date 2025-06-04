#!/bin/bash

# CONFIGURATION DES COULEURS
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# CONFIGURATION MODIFIABLE
DB_HOST="localhost"
DB_USER="root"
DB_PASS="root"
DB_NAME="iot_db"
TABLE_NAME="mesure"

BROKER="localhost"
PORT=1883
DEVICE_EUI="0018B2100000D76D"
TOPIC="application/+/device/+/event/up"

# AFFICHAGE DU BANNER
show_banner() {
  clear
  echo -e "${BLUE}╔═════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║          ${GREEN}PontConnect - Insertion Temp & Humidité     ${BLUE}║${NC}"
  echo -e "${BLUE}╚═════════════════════════════════════════════════════════════╝${NC}"
  echo
}

log_message() {
  local level=$1
  local message=$2
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local color=$NC

  case "$level" in
    "INFO") color=$BLUE ;;
    "SUCCESS") color=$GREEN ;;
    "ERROR") color=$RED ;;
  esac

  echo -e "${color}[$timestamp] [$level] $message${NC}"
}

insert_into_db() {
  local temperature=$1
  local humidite=$2
  query="INSERT INTO $TABLE_NAME (temperature, humidite) VALUES ($temperature, $humidite);"
  
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$query" 2>/tmp/mysql_error.log
  if [ $? -eq 0 ]; then
    log_message "SUCCESS" "→ Données insérées : Temp=${temperature}°C, Hum=${humidite}%"
  else
    log_message "ERROR" "Erreur insertion DB (voir /tmp/mysql_error.log)"
  fi
}

# SCRIPT PRINCIPAL
show_banner
log_message "INFO" "Écoute des données du capteur $DEVICE_EUI - Topic: $TOPIC"
log_message "INFO" "Appuyez sur Ctrl+C pour quitter"

mosquitto_sub -h "$BROKER" -p "$PORT" -t "$TOPIC" -v | \
while read -r line; do
  json=$(echo "$line" | cut -d' ' -f2-)

  devEui=$(echo "$json" | jq -r '.deviceInfo.devEui')
  [[ "$devEui" != "$DEVICE_EUI" ]] && continue

  b64=$(echo "$json" | jq -r '.data')
  [[ -z "$b64" || "$b64" == "null" ]] && continue

  read -r t_lsb t_msb h_lsb h_msb < <(echo "$b64" | base64 -d | od -An -t u1)

  raw_temp=$(( (t_lsb) | (t_msb << 8) ))
  raw_hum=$(( (h_lsb) | (h_msb << 8) ))

  if (( raw_temp >= 32768 )); then
    signed_temp=$(( raw_temp - 65536 ))
  else
    signed_temp=$raw_temp
  fi

  temperature=$(awk "BEGIN{printf \"%.2f\", $signed_temp/100}")
  humidite=$(awk "BEGIN{printf \"%.2f\", $raw_hum/10}")

  log_message "INFO" "→ Température: $temperature °C"
  log_message "INFO" "→ Humidité: $humidite %"

  insert_into_db "$temperature" "$humidite"
  echo -e "${BLUE}-----------------------------------${NC}"
done
