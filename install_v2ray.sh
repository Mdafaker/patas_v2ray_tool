#!/bin/bash
# Actualizar los repositorios
apt update && apt upgrade -y
# Instalar curl
apt install curl -y
# Descargar e instalar V2Ray
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/release/install-release.sh)
echo "V2Ray instalado correctamente."

