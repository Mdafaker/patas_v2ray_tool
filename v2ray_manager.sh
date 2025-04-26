#!/bin/bash

# >>>>> DEFINICIÓN DE LA FUNCIÓN eliminar_usuario_uuid() <<<<<
eliminar_usuario_uuid() {
  echo -e "\n\e[32m===== Eliminar usuario UUID =====\e[0m\n"
  read -p "Ingrese el UUID del usuario que desea eliminar: " uuid_a_eliminar

  if [ -z "$uuid_a_eliminar" ]; then
    echo -e "\e[31mError: El UUID no puede estar vacío.\e[0m\n"
    read -p "Presione Enter para continuar..."
    return
  fi

  # Define la ruta al archivo de configuración de V2Ray (ajústala si es diferente)
  config_file="/data/data/com.termux/files/home/v2ray/config.json"

  # Crear una copia de seguridad del archivo de configuración (opcional pero recomendado)
  cp "$config_file" "${config_file}.bak"

  # Usar jq para filtrar y eliminar el usuario del array 'clients'
  nuevo_config=$(jq --arg uuid "$uuid_a_eliminar" '
    .inbounds[].settings.clients |= map(select(.id != $uuid))
  ' "$config_file")

  if [ -n "$nuevo_config" ]; then
    # Escribir la nueva configuración al archivo
    echo "$nuevo_config" > "$config_file"
    echo -e "\n\e[32mUsuario con UUID '$uuid_a_eliminar' eliminado (si existía).\e[0m\n"

    # Preguntar si se debe reiniciar V2Ray
    read -p "Desea reiniciar el servidor V2Ray para aplicar los cambios? (s/n): " reiniciar

    if [[ "$reiniciar" == "s" || "$reiniciar" == "S" ]]; then
      v2ray restart
      echo -e "\e[32mServidor V2Ray reiniciado.\e[0m\n"
    else
      echo -e "\e[33mRecuerde reiniciar el servidor V2Ray para aplicar los cambios.\e[0m\n"
    fi
  else
    echo -e "\e[31mError al procesar el archivo de configuración.\e[0m\n"
  fi

  read -p "Presione Enter para continuar..."
}

# >>>>> DEFINICIÓN DE LA FUNCIÓN mostrar_usuarios_registrados() <<<<<
mostrar_usuarios_registrados() {
  echo -e "\n\e[32m===== Usuarios Registrados =====\e[0m\n"

  # Define la ruta al archivo de configuración de V2Ray (ajústala si es diferente)
  config_file="/data/data/com.termux/files/home/v2ray/config.json"

  # Usar jq para extraer la lista de UUIDs
  uuids=$(jq -c '.inbounds[].settings.clients[].id' "$config_file" | sed 's/"//g')

  if [ -n "$uuids" ]; then
    echo "$uuids" | while IFS= read -r uuid; do
      echo -e "\e[33m- $uuid\e[0m"
    done
  else
    echo -e "\e[31mNo se encontraron usuarios registrados.\e[0m\n"
  fi

  echo -e "\n\e[32mTotal de usuarios registrados: $(echo "$uuids" | wc -l)\e[0m\n"

  read -p "Presione Enter para continuar..."
}

# >>>>> BUCLE PRINCIPAL DEL SCRIPT <<<<<
while true; do
  clear
  echo -e "\e[32m===== Administrador de V2Ray =====\e[0m"
  echo -e "\e[33m[1] Instalar V2Ray\e[0m"
  echo -e "\e[33m[2] Cambiar protocolo\e[0m"
  echo -e "\e[33m[3] Activar TLS\e[0m"
  echo -e "\e[33m[4] Cambiar puerto V2Ray\e[0m"
  echo -e "\e[33m[5] Agregar usuario UUID\e[0m"
  echo -e "\e[33m[6] Eliminar usuario UUID\e[0m"
  echo -e "\e[33m[7] Mostrar usuarios registrados\e[0m"
  echo -e "\e[33m[8] Información de cuentas\e[0m"
  echo -e "\e[33m[9] Estadísticas de consumo\e[0m"
  echo -e "\e[33m[10] Limitador por consumo (BETA)\e[0m"
  echo -e "\e[33m[11] Limpiador de expirados\e[0m"
  echo -e "\e[33m[12] Desinstalar V2Ray\e[0m"
  echo -e "\e[33m[13] Iniciar servidor V2Ray\e[0m"
  echo -e "\e[33m[14] Reiniciar servidor V2Ray\e[0m"
  echo -e "\e[33m[15] Apagar servidor V2Ray\e[0m"
  echo -e "\e[31m[0] Salir\e[0m"
  read -p "Seleccione una opción: " opcion
  case $opcion in
    1)
      apt install v2ray
      read -p "Presione Enter para continuar..."
      ;;
    2)
      ./change_protocol.sh
      read -p "Presione Enter para continuar..."
      ;;
    3)
  ./activate_tls.sh
  read -p "Presione Enter para continuar..."
  ;;

    4)
      echo "Función no implementada."
      read -p "Presione Enter para continuar..."
      ;;
    5)
  ./add_user.sh
  read -p "Presione Enter para continuar..."
  ;;

    6)
      eliminar_usuario_uuid
      ;;
    7)
      mostrar_usuarios_registrados
      ;;
    8)
      echo "Función no implementada."
      read -p "Presione Enter para continuar..."
      ;;
    9)
      echo "Función no implementada."
      read -p "Presione Enter para continuar..."
      ;;
    10)
      echo "Función no implementada."
      read -p "Presione Enter para continuar..."
      ;;
    11)
      echo "Función no implementada."
      read -p "Presione Enter para continuar..."
      ;;
    12)
      echo "Función no implementada."
      read -p "Presione Enter para continuar..."
      ;;
    13)
      v2ray start
      read -p "Presione Enter para continuar..."
      ;;
    14)
      v2ray restart
      read -p "Presione Enter para continuar..."
      ;;
    15)
      v2ray stop
      read -p "Presione Enter para continuar..."
      ;;
    0)
      echo "Saliendo..."
      break
      ;;
    *)
      echo "Opción inválida."
      read -p "Presione Enter para continuar..."
      ;;
  esac
done

