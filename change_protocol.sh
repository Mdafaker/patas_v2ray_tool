#!/bin/bash
clear
echo "===== Cambiar protocolo de V2Ray ====="
echo "Protocolos disponibles:"
echo "[1] VMess"
echo "[2] VLESS"
read -p "Seleccione el protocolo: " protocolo
case $protocolo in
  1)
    protocolo_v2ray="vmess"
    ;;
  2)
    protocolo_v2ray="vless"
    ;;
  *)
    echo "Opción inválida."
    exit 1
    ;;
esac
#Debido a la instalacion por medio de apt el archivo json se debera de encontrar en /data/data/com.termux/files/usr/etc/v2ray/config.json
sed -i "s/\"protocol\": \".*\"/\"protocol\": \"$protocolo_v2ray\"/g" /data/data/com.termux/files/usr/etc/v2ray/config.json
v2ray restart
echo "Protocolo cambiado a $protocolo_v2ray."

