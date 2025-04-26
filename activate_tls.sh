#!/bin/bash
clear
echo "===== Activar TLS en V2Ray ====="
read -p "Ingrese el dominio para el certificado TLS: " dominio

echo "Verificando la instalación de acme.sh..."
if [ ! -d ~/.acme.sh ]; then
  echo "acme.sh no encontrado. Intenta instalarlo manualmente con los comandos:"
  echo "  cd ~"
  echo "  git clone https://github.com/acmesh-official/acme.sh.git"
  echo "  cd acme.sh"
  echo "  ./acme.sh --install -m jairsgc37@gmail.com"
  echo "  source ~/.bashrc"
  echo "Luego vuelva a ejecutar esta opción."
  read -p "Presione Enter para continuar..."
  exit 1
fi

echo "Obteniendo o renovando el certificado TLS..."
~/.acme.sh/acme.sh --issue -d "$dominio" --standalone --force --force

echo "Instalando el certificado..."
~/.acme.sh/acme.sh --installcert -d "$dominio" \
  --cert-file /data/data/com.termux/files/usr/etc/v2ray/cert.pem \
  --key-file /data/data/com.termux/files/usr/etc/v2ray/key.pem \
  --fullchain-file /data/data/com.termux/files/usr/etc/v2ray/fullchain.pem \
  --force

echo "Modificando la configuración de V2Ray para TLS..."
if [ -f /data/data/com.termux/files/usr/etc/v2ray/config.json ] && [ -f /data/data/com.termux/files/usr/etc/v2ray/config_tls.json ]; then
  # Insertar la configuración TLS dentro de la sección 'inbounds'
  sed -i '/"streamSettings": {/a \        "network": "tls",\n        "security": "tls",\n        "tlsSettings": {\n          "certificates": [\n            {\n              "certificateFile": "\/data\/data\/com.termux\/files\/usr\/etc\/v2ray\/fullchain.pem",\n              "keyFile": "\/data\/data\/com.termux\/files\/usr\/etc\/v2ray\/key.pem"\n            }\n          ]\n        }\n      ,' /data/data/com.termux/files/usr/etc/v2ray/config.json
else
  echo "Error: No se encontraron config.json o config_tls.json"
fi

echo "Reiniciando V2Ray..."
pkill -f v2ray
v2ray run -config /data/data/com.termux/files/usr/etc/v2ray/config.json &
echo "TLS activado correctamente."

