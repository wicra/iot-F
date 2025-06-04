#!/bin/bash

# CONFIGURATION DES COULEURS
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# CONFIGURATION MODIFIABLE
DB_HOST="127.0.0.1"
DB_USER="root"
DB_PASS="root"
DB_NAME="iot_db"
TABLE_NAME="mesure"

BROKER="localhost"
PORT=1883
DEVICE_EUI="0018B2100000D76D"
# On écoute uniquement le topic du device voulu
TOPIC="application/+/device/${DEVICE_EUI,,}/event/up"

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
    "WARN") color=$RED ;;
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
    log_message "ERROR" "$(cat /tmp/mysql_error.log)"
  fi
}

# Vérifie si mysql est installé, sinon l'installe
if ! command -v mysql >/dev/null 2>&1; then
  echo -e "${BLUE}[INFO] Installation du client MySQL...${NC}"
  sudo apt-get update
  sudo apt-get install -y default-mysql-client
  if ! command -v mysql >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] L'installation du client MySQL a échoué. Arrêt du script.${NC}"
    exit 1
  fi
  echo -e "${GREEN}[INFO] Client MySQL installé avec succès.${NC}"
fi

# SCRIPT PRINCIPAL
show_banner
log_message "INFO" "Écoute des données du capteur $DEVICE_EUI - Topic: $TOPIC"
log_message "INFO" "Appuyez sur Ctrl+C pour quitter"

mosquitto_sub -h "$BROKER" -p "$PORT" -t "$TOPIC" -v | \
while read -r line; do
  log_message "INFO" "Message MQTT reçu : $line"

  # Extraction du JSON (après le topic)
  json=$(echo "$line" | cut -d' ' -f2-)
  if [[ -z "$json" ]]; then
    log_message "WARN" "Aucun JSON détecté dans le message, on ignore."
    continue
  fi

  # Vérification du devEui dans le JSON (sécurité supplémentaire)
  devEui=$(echo "$json" | jq -r '.deviceInfo.devEui')
  if [[ "${devEui,,}" != "${DEVICE_EUI,,}" ]]; then
    log_message "INFO" "devEui non concerné ($devEui), on ignore."
    continue
  fi
  log_message "INFO" "devEui validé : $devEui"

  # Extraction du champ data
  b64=$(echo "$json" | jq -r '.data')
  if [[ -z "$b64" || "$b64" == "null" ]]; then
    log_message "WARN" "Champ 'data' absent ou null, on ignore."
    continue
  fi

  # Vérifier la longueur de la chaîne base64 (8 caractères attendus)
  char_count=${#b64}
  if [[ "$char_count" -ne 8 ]]; then
    log_message "WARN" "Payload data n'a pas 8 caractères base64 ($char_count caractères), on ignore."
    continue
  fi
  log_message "INFO" "Payload data valide ($char_count caractères base64)"

  # Décodage base64 en hexadécimal
  hex=$(echo "$b64" | base64 -d | xxd -p | tr -d '\n')
  log_message "INFO" "Payload hexadécimal : $hex"

  # Vérifier que la trame fait au moins 5 octets (10 caractères hex)
  if [[ ${#hex} -lt 10 ]]; then
    log_message "WARN" "Trame trop courte (${#hex}/10 caractères hex), on ignore."
    continue
  fi

  # Extraction des champs selon la structure
  temp_hex="${hex:4:4}"   # octets 3-4
  hum_hex="${hex:8:2}"    # octet 5

  temp_dec=$((16#$temp_hex))
  hum_dec=$((16#$hum_hex))

  temperature=$(awk "BEGIN{printf \"%.1f\", $temp_dec/10}")
  humidite=$hum_dec

  log_message "INFO" "→ Température décodée: $temperature °C"
  log_message "INFO" "→ Humidité décodée: $humidite %"

  insert_into_db "$temperature" "$humidite"
  echo -e "${BLUE}-----------------------------------${NC}"
done