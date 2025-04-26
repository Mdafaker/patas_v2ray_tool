#!/bin/bash
clear
echo "===== Agregar usuario UUID ====="
read -p "Ingrese el UUID del usuario: " uuid
# Agregar el UUID al archivo config.json
sed -i "/\"clients\": \[/a \        {\n          \"id\": \"$uuid\",\n          \"alterId\": 64\n        }\," /data/data/com.termux/files/usr/etc/v2ray/config.json
v2ray restart
echo "Usuario agregado correctamente."
