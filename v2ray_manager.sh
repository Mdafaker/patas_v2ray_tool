#!/bin/bash

# --- Colores ---
YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
BLUE='\e[34m'
NC='\e[0m' # No Color

# >>>>> CONFIGURACIÓN GLOBAL - AJUSTA SI ES NECESARIO <<<<<
# Ruta al archivo de configuración de V2Ray en Termux
V2RAY_CONFIG_FILE="/data/data/com.termux/files/usr/etc/v2ray/config.json"
# Comando principal de V2Ray en Termux (usualmente 'v2ray' o 'sv v2ray' si usas runit)
V2RAY_COMMAND="v2ray" # Asumimos 'v2ray' es un binario ejecutable y accesible via PATH


# --- Función auxiliar para ejecutar scripts externos ---
# Hace un chequeo de existencia y permisos, y lo ejecuta con ./
execute_external_script() {
    local script_path="$1"
    local script_display_name="$2" # Nombre amigable para mensajes

    if [ ! -f "$script_path" ]; then
        echo -e "${RED}Error: El script '${script_display_name}' no se encontró en la ruta: ${script_path}${NC}"
        echo -e "${YELLOW}Asegúrate de que el archivo esté en el mismo directorio que 'v2ray_manager.sh'.${NC}"
        return 1 # Falló, script no encontrado
    fi

    if [ ! -x "$script_path" ]; then
        echo -e "${YELLOW}El script '${script_display_name}' no tiene permisos de ejecución.${NC}"
        read -p "¿Desea intentar darle permisos de ejecución ahora? (s/N): " grant_exec_perm
        if [[ "$grant_exec_perm" == "s" || "$grant_exec_perm" == "S" ]]; then
            chmod +x "$script_path"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Permisos concedidos a '${script_display_name}'. Intentando ejecutar de nuevo...${NC}"
                "$script_path" # Intenta ejecutarlo ahora
                return $? # Devuelve el código de salida del script
            else
                echo -e "${RED}Error: No se pudieron conceder permisos de ejecución a '${script_display_name}'.${NC}"
                echo -e "${YELLOW}Verifica tus permisos de usuario o intenta ejecutar 'chmod +x ${script_path}' manualmente.${NC}"
                return 1 # Falló al dar permisos
            fi
        else
            echo -e "${RED}No se puede ejecutar '${script_display_name}' sin permisos de ejecución.${NC}"
            return 1 # El usuario no quiso dar permisos
        fi
    else
        # El script existe y tiene permisos de ejecución, adelante.
        "$script_path"
        return $? # Devuelve el código de salida del script
    fi
}


# >>>>> DEFINICIÓN DE LA FUNCIÓN menu_check() <<<<<
menu_check() {
    echo -e "${BLUE}===== Realizando comprobaciones iniciales =====${NC}"
    local all_ok=true # Variable local para esta función
    local missing_deps=()

    # --- Dependencias Requeridas ---
    # Incluye 'git' para acme.sh y posible futuras instalaciones.
    local deps=("$V2RAY_COMMAND" "jq" "curl" "grep" "sed" "awk" "id" "pgrep" "wc" "cut" "cat" "git")
    echo -n "  [*] Comprobando dependencias: "
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
            all_ok=false
        fi
    done
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FALTAN (${missing_deps[*]})${NC}"
        echo -e "${YELLOW}Por favor, instálalas usando 'pkg install <paquete>' (ej. pkg install jq curl git).${NC}"
    fi

    # --- Privilegios (En Termux, usualmente no se es root) ---
    echo -n "  [*] Comprobando privilegios: "
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${GREEN}Root (OK)${NC}"
    else
         local user_id=$(id -u)
         local user_name=$(id -un)
         echo -e "${YELLOW}Usuario: $user_name (ID: $user_id) (Normal en Termux)${NC}"
    fi

    # --- Proceso V2Ray ---
    echo -n "  [*] Comprobando proceso $V2RAY_COMMAND: "
    if pgrep -f "$V2RAY_COMMAND" | grep -qvE "$$|v2ray_manager.sh"; then
         local num_proc=$(pgrep -fc "$V2RAY_COMMAND")
         echo -e "${GREEN}Corriendo ($num_proc proceso(s))${NC}"
    else
         echo -e "${YELLOW}No parece estar corriendo.${NC}"
         if ! command -v "$V2RAY_COMMAND" &> /dev/null; then
             echo -e "${RED}   -> Comando '$V2RAY_COMMAND' no encontrado. ¿Instalado con 'pkg install v2ray' o similar?${NC}"
             all_ok=false
         fi
    fi

    # --- Archivo de Configuración V2Ray ---
    echo -n "  [*] Comprobando archivo de configuración ($V2RAY_CONFIG_FILE): "
    if [ -f "$V2RAY_CONFIG_FILE" ]; then
        if [ -r "$V2RAY_CONFIG_FILE" ]; then
             echo -e "${GREEN}Encontrado y legible${NC}"
             if command -v jq &> /dev/null && jq -e . "$V2RAY_CONFIG_FILE" > /dev/null 2>&1; then
                 echo -e "${GREEN}   -> Formato JSON válido.${NC}"
             elif ! command -v jq &> /dev/null; then
                 echo -e "${YELLOW}   -> 'jq' no está instalado, no se puede validar el JSON.${NC}"
             else
                 echo -e "${RED}   -> ¡Formato JSON INVÁLIDO!${NC}"
                 echo -e "${YELLOW}     El archivo de configuración tiene errores de sintaxis JSON. ${NC}"
                 echo -e "${YELLOW}     Por favor, revísalo manualmente para que V2Ray pueda funcionar correctamente.${NC}"
                 all_ok=false
             fi
        else
             echo -e "${RED}Encontrado pero NO legible (Revisa permisos)${NC}"
             all_ok=false
        fi
    else
        echo -e "${RED}No encontrado (Ruta: $V2RAY_CONFIG_FILE)${NC}"
        all_ok=false
    fi

    # --- Resumen de Comprobaciones ---
    if ! $all_ok; then
        echo -e "${RED}--------------------------------------------------------------------${NC}"
        echo -e "${RED} ¡ADVERTENCIA! Se encontraron problemas en las comprobaciones iniciales.${NC}"
        echo -e "${RED} Es posible que el script o V2Ray no funcionen correctamente.${NC}"
        echo -e "${RED} Revisa los mensajes anteriores y soluciona los problemas antes de continuar.${NC}"
        echo -e "${RED}--------------------------------------------------------------------${NC}"
    else
         echo -e "${GREEN} Comprobaciones iniciales completadas con éxito.${NC}"
    fi
    # Establecer la variable global para el bucle principal
    _GLOBAL_ALL_OK_CHECK=$all_ok
    echo # Añade una línea en blanco para espaciar
}

# >>>>> DEFINICIÓN DE LA FUNCIÓN eliminar_usuario_uuid() <<<<<
eliminar_usuario_uuid() {
  echo -e "\n${BLUE}===== Eliminar Usuario UUID =====${NC}\n"

  # Verificar que jq esté disponible
  if ! command -v jq &> /dev/null; then
       echo -e "${RED}Error: El comando 'jq' es necesario y no está instalado. Instálalo con 'pkg install jq'.${NC}"
       read -p "Presione Enter para continuar..."
       return
  fi

  # Verificar si el archivo de configuración existe y es válido
  if [ ! -f "$V2RAY_CONFIG_FILE" ]; then
      echo -e "${RED}Error: Archivo de configuración no encontrado en '$V2RAY_CONFIG_FILE'.${NC}"
      read -p "Presione Enter para continuar..."
      return
  fi
  if ! jq -e . "$V2RAY_CONFIG_FILE" > /dev/null 2>&1; then
       echo -e "${RED}Error: El archivo de configuración '$V2RAY_CONFIG_FILE' no es un JSON válido.${NC}"
       echo -e "${YELLOW}No se realizarán cambios. Por favor, corrígelo manualmente.${NC}"
       read -p "Presione Enter para continuar..."
       return
  fi

  read -p "Ingrese el UUID del usuario que desea eliminar: " uuid_a_eliminar

  if [ -z "$uuid_a_eliminar" ]; then
    echo -e "${RED}Error: El UUID no puede estar vacío.${NC}\n"
    read -p "Presione Enter para continuar..."
    return
  fi

  # Comprobar si el UUID existe antes de intentar eliminarlo
  if ! jq --arg uuid "$uuid_a_eliminar" '.inbounds[]?.settings?.clients[]? | select(.id == $uuid)' "$V2RAY_CONFIG_FILE" > /dev/null 2>&1; then
      echo -e "${RED}Error: UUID '$uuid_a_eliminar' no encontrado en la configuración.${NC}"
      read -p "Presione Enter para continuar..."
      return
  fi

  # Crear una copia de seguridad ANTES de modificar
  local backup_file="${V2RAY_CONFIG_FILE}.bak_$(date +%Y%m%d_%H%M%S)"
  cp "$V2RAY_CONFIG_FILE" "$backup_file"
  echo -e "${YELLOW}Copia de seguridad creada en ${backup_file}${NC}"

  # Proceder a la eliminación usando jq
  local nuevo_config=$(jq --arg uuid "$uuid_a_eliminar" '
    .inbounds |= map(
      if has("settings") and .settings | has("clients") then
        .settings.clients |= map(select(.id != $uuid))
      else
        .
      end
    )
  ' "$V2RAY_CONFIG_FILE")

  # Verificar si jq produjo una salida válida y si hubo cambios
  if [ -n "$nuevo_config" ] && [ "$(jq -S . <<< "$nuevo_config")" != "$(jq -S . "$V2RAY_CONFIG_FILE")" ]; then
    echo "$nuevo_config" > "$V2RAY_CONFIG_FILE"
    echo -e "\n${GREEN}Usuario con UUID '$uuid_a_eliminar' eliminado correctamente del archivo '$V2RAY_CONFIG_FILE'.${NC}"

    read -p "¿Desea reiniciar el servidor V2Ray para aplicar los cambios? (s/N): " reiniciar_prompt

    if [[ "$reiniciar_prompt" == "s" || "$reiniciar_prompt" == "S" ]]; then
      echo -e "${YELLOW}Intentando reiniciar V2Ray...${NC}"
      "$V2RAY_COMMAND" restart
      sleep 2
      echo -e "${GREEN}Comando de reinicio de V2Ray ejecutado.${NC}\n"
    else
      echo -e "${YELLOW}Recuerde reiniciar el servidor V2Ray manualmente ('$V2RAY_COMMAND restart') para aplicar los cambios.${NC}\n"
    fi
  elif [ -n "$nuevo_config" ]; then
       echo -e "${YELLOW}El UUID '$uuid_a_eliminar' ya no estaba presente o no se realizaron cambios (posiblemente ya eliminado).${NC}"
  else
    echo -e "${RED}Error: 'jq' no pudo procesar o modificar el archivo de configuración.${NC}"
    echo -e "${YELLOW}Se recomienda revisar el archivo '$V2RAY_CONFIG_FILE' y la copia de seguridad '${backup_file}'.${NC}"
  fi

  read -p "Presione Enter para continuar..."
}

# >>>>> DEFINICIÓN DE LA FUNCIÓN mostrar_usuarios_registrados() <<<<<
mostrar_usuarios_registrados() {
  echo -e "\n${BLUE}===== Usuarios Registrados =====${NC}\n"

  # Verificar que jq esté disponible
  if ! command -v jq &> /dev/null; then
       echo -e "${RED}Error: El comando 'jq' es necesario y no está instalado. Instálalo con 'pkg install jq'.${NC}"
       read -p "Presione Enter para continuar..."
       return
  fi

  # Verificar si el archivo de configuración existe y es válido
  if [ ! -f "$V2RAY_CONFIG_FILE" ]; then
      echo -e "${RED}Error: Archivo de configuración no encontrado en '$V2RAY_CONFIG_FILE'.${NC}"
      read -p "Presione Enter para continuar..."
      return
  fi
  if ! jq -e . "$V2RAY_CONFIG_FILE" > /dev/null 2>&1; then
       echo -e "${RED}Error: El archivo de configuración '$V2RAY_CONFIG_FILE' no es un JSON válido.${NC}"
       read -p "Presione Enter para continuar..."
       return
  fi

  # Usar jq para extraer la lista de UUIDs de forma segura
  local uuids=$(jq -r '
    .inbounds[] |
    select(has("settings") and .settings | has("clients")) |
    .settings.clients[]?.id // empty
  ' "$V2RAY_CONFIG_FILE" 2>/dev/null)

  local count=0
  if [ -n "$uuids" ]; then
    while IFS= read -r uuid; do
      if [ -n "$uuid" ]; then
          echo -e "${YELLOW}- $uuid${NC}"
          count=$((count + 1))
      fi
    done <<< "$uuids"
  fi

  # Mostrar total
  if [ $count -eq 0 ]; then
      echo -e "${YELLOW}No hay usuarios registrados o la sección 'clients' está vacía o no existe.${NC}\n"
  fi
  echo -e "\n${GREEN}Total de usuarios registrados: $count${NC}\n"

  read -p "Presione Enter para continuar..."
}

# >>>>> DEFINICIÓN DE LA FUNCIÓN cambiar_puerto_v2ray() <<<<<
cambiar_puerto_v2ray() {
    echo -e "\n${BLUE}===== Cambiar Puerto de Escucha V2Ray =====${NC}"

    # --- Variables y Verificaciones ---
    if ! command -v jq &> /dev/null; then echo -e "${RED}Error: 'jq' no instalado. Instala con 'pkg install jq'.${NC}"; read -p "Presione Enter..."; return; fi
    if [ ! -f "$V2RAY_CONFIG_FILE" ]; then echo -e "${RED}Error: '$V2RAY_CONFIG_FILE' no encontrado.${NC}"; read -p "Presione Enter..."; return; fi
    if ! jq -e . "$V2RAY_CONFIG_FILE" > /dev/null 2>&1; then echo -e "${RED}Error: '$V2RAY_CONFIG_FILE' tiene formato JSON inválido.${NC}"; read -p "Presione Enter..."; return; fi

    # --- Obtener Puerto Actual ---
    local current_port=$(jq -r '.inbounds[0].port // "No encontrado"' "$V2RAY_CONFIG_FILE")
    if [[ "$current_port" == "No encontrado" ]]; then
        echo -e "${RED}Error: No se pudo leer el puerto actual desde '$V2RAY_CONFIG_FILE'. Verifica la estructura JSON.${NC}"
        read -p "Presione Enter para continuar..."
        return
    fi
    echo -e "${YELLOW}El puerto actual configurado es: ${current_port}${NC}"

    # --- Pedir Nuevo Puerto ---
    read -p "Ingrese el nuevo número de puerto (1-65535): " new_port

    # --- Validar Nuevo Puerto ---
    if [ -z "$new_port" ]; then
      echo -e "${RED}Error: No ingresaste ningún puerto.${NC}"
      read -p "Presione Enter para continuar..."
      return
    fi
    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}Error: '$new_port' no es un número válido.${NC}"
      read -p "Presione Enter para continuar..."
      return
    fi
    if [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
      echo -e "${RED}Error: El puerto debe estar entre 1 y 65535.${NC}"
      read -p "Presione Enter para continuar..."
      return
    fi
    if [ "$new_port" -lt 1024 ]; then
      echo -e "${YELLOW}Advertencia: Los puertos menores a 1024 usualmente requieren permisos de root para ser usados. En Termux, esto podría ser un problema si no tienes acceso root o el V2Ray no está configurado para ejecutarse como root.${NC}"
    fi
    if [ "$new_port" -eq "$current_port" ]; then
       echo -e "${YELLOW}El puerto ingresado ($new_port) es el mismo que el actual. No se realizarán cambios.${NC}"
       read -p "Presione Enter para continuar..."
       return
    fi

    # --- Actualizar config.json ---
    echo -e "${YELLOW}Actualizando puerto a $new_port en '$V2RAY_CONFIG_FILE'...${NC}"
    local backup_file="${V2RAY_CONFIG_FILE}.bak_port_$(date +%Y%m%d_%H%M%S)"
    cp "$V2RAY_CONFIG_FILE" "$backup_file"
    echo -e "${YELLOW}Copia de seguridad creada en ${backup_file}${NC}"

    local nuevo_config=$(jq --argjson port "$new_port" '
      .inbounds[0].port = $port
    ' "$V2RAY_CONFIG_FILE")

    if [ $? -eq 0 ] && [ -n "$nuevo_config" ] && jq -e . <<< "$nuevo_config" > /dev/null 2>&1; then
        echo "$nuevo_config" > "$V2RAY_CONFIG_FILE"
        echo -e "${GREEN}¡Puerto actualizado correctamente a $new_port en '$V2RAY_CONFIG_FILE'!${NC}"

        echo -e "${YELLOW}IMPORTANTE: Si tienes un firewall (como iptables o en tu proveedor de VPS),${NC}"
        echo -e "${YELLOW}recuerda permitir el tráfico entrante en el nuevo puerto TCP/UDP $new_port.${NC}"

        read -p "¿Desea reiniciar V2Ray ahora para aplicar el cambio de puerto? (s/N): " reiniciar_prompt
        if [[ "$reiniciar_prompt" == "s" || "$reiniciar_prompt" == "S" ]]; then
          echo -e "${YELLOW}Intentando reiniciar V2Ray...${NC}"
          "$V2RAY_COMMAND" restart
          sleep 2
          echo -e "${GREEN}Comando de reinicio de V2Ray ejecutado.${NC}"
          echo -e "${YELLOW}Verifica si V2Ray está corriendo en el nuevo puerto.${NC}"
        else
          echo -e "${YELLOW}Recuerde reiniciar V2Ray manualmente para aplicar el cambio de puerto.${NC}"
        fi
    else
        echo -e "${RED}Error: Falló la actualización de '$V2RAY_CONFIG_FILE' con jq o el resultado fue inválido.${NC}"
        echo -e "${YELLOW}Se mantiene el archivo original. Revisa el backup '${backup_file}'.${NC}"
    fi

    read -p "Presione Enter para continuar..."
}

# >>>>> DEFINICIÓN DE LA FUNCIÓN activar_tls() <<<<<
activar_tls() {
    echo -e "\n${BLUE}===== Activar/Renovar TLS (Automático con acme.sh) =====${NC}"

    if ! command -v jq &> /dev/null; then
         echo -e "${RED}Error: El comando 'jq' es necesario. Instálalo con 'pkg install jq'.${NC}"
         read -p "Presione Enter para continuar..."
         return
    fi
    local acme_sh_exec="$HOME/.acme.sh/acme.sh" # Ruta estándar de instalación de acme.sh
    if ! command -v "$acme_sh_exec" &> /dev/null; then
      echo -e "${RED}Error: acme.sh no encontrado en '$acme_sh_exec'.${NC}"
      echo -e "${YELLOW}Parece que acme.sh no está instalado o no se encuentra en la ruta esperada.${NC}"
      echo -e "Puedes instalarlo generalmente con: ${GREEN}curl https://get.acme.sh | sh${NC}"
      echo -e "Luego, cierra y vuelve a abrir Termux (o ejecuta 'source ~/.bashrc' o 'source ~/.zshrc' si usas zsh)."
      read -p "Presione Enter para continuar..."
      return
    fi

    if [ ! -f "$V2RAY_CONFIG_FILE" ]; then
        echo -e "${RED}Error: Archivo de configuración '$V2RAY_CONFIG_FILE' no encontrado.${NC}"
        read -p "Presione Enter para continuar..."
        return
    fi
    if ! jq -e . "$V2RAY_CONFIG_FILE" > /dev/null 2>&1; then
        echo -e "${RED}Error: Archivo de configuración '$V2RAY_CONFIG_FILE' tiene formato JSON inválido.${NC}"
        echo -e "${YELLOW}Por favor, corrígelo antes de continuar.${NC}"
        read -p "Presione Enter para continuar..."
        return
    fi

    read -p "Introduce el nombre de dominio para el certificado TLS (ej. example.com): " domain
    if [ -z "$domain" ]; then
      echo -e "${RED}Error: El nombre de dominio no puede estar vacío.${NC}"
      read -p "Presione Enter para continuar..."
      return
    fi
    echo -e "${YELLOW}Se intentará obtener/renovar certificado para: ${domain}${NC}"

    echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}IMPORTANTE: El modo 'standalone' de acme.sh necesita usar el puerto 80${NC}"
    echo -e "${YELLOW}para verificar tu dominio. Asegúrate de que nada más esté usando ese${NC}"
    echo -e "${YELLOW}puerto durante la verificación (ej: otro servidor web, o V2Ray mismo).${NC}"
    echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
    read -p "¿Desea detener V2Ray temporalmente durante la verificación? (s/N): " stop_v2ray_prompt

    local v2ray_stopped=false
    if [[ "$stop_v2ray_prompt" == "s" || "$stop_v2ray_prompt" == "S" ]]; then
      echo -e "${YELLOW}Deteniendo V2Ray...${NC}"
      "$V2RAY_COMMAND" stop
      v2ray_stopped=true
      sleep 2
    fi

    echo -e "${YELLOW}Ejecutando acme.sh para obtener/renovar certificado... (esto puede tardar varios segundos)${NC}"
    "$acme_sh_exec" --issue -d "$domain" --standalone --keylength ec-256

    local acme_exit_code=$?

    if $v2ray_stopped; then
      echo -e "${YELLOW}Volviendo a iniciar V2Ray...${NC}"
      "$V2RAY_COMMAND" start
      sleep 2
    fi

    if [ $acme_exit_code -ne 0 ]; then
      echo -e "${RED}Error: acme.sh falló al obtener/renovar el certificado (Código de salida: $acme_exit_code).${NC}"
      echo -e "${YELLOW}Revisa la salida de acme.sh arriba para ver detalles del error.${NC}"
      echo -e "${YELLOW}Posibles causas: Puerto 80 bloqueado, problemas de DNS, límites de Let's Encrypt, etc.${NC}"
      read -p "Presione Enter para continuar..."
      return
    fi

    echo -e "${GREEN}¡Certificado obtenido/renovado con éxito por acme.sh!${NC}"

    local cert_path_base="$HOME/.acme.sh/${domain}_ecc"
    local cert_file="${cert_path_base}/fullchain.cer"
    local key_file="${cert_path_base}/${domain}.key"

    if [ ! -f "$cert_file" ]; then
        cert_file="${cert_path_base}/fullchain.pem"
        echo -e "${YELLOW}Nota: 'fullchain.cer' no encontrado, intentando con 'fullchain.pem'.${NC}"
    fi

    echo -e "${YELLOW}Comprobando rutas de archivos generados por acme.sh...${NC}"
    echo -e "  Certificado (fullchain): $cert_file"
    echo -e "  Clave privada:          $key_file"

    if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
       echo -e "${RED}Error: No se encontraron los archivos de certificado o clave en la ruta esperada (${cert_path_base}).${NC}"
       echo -e "${YELLOW}Verifica la salida de acme.sh o el contenido de '$HOME/.acme.sh/'.${NC}"
       read -p "Presione Enter para continuar..."
       return
    fi
    echo -e "${GREEN}Archivos de certificado y clave encontrados.${NC}"

    echo -e "${YELLOW}Actualizando rutas TLS y 'serverName' en '$V2RAY_CONFIG_FILE'...${NC}"
    local backup_file="${V2RAY_CONFIG_FILE}.bak_tls_$(date +%Y%m%d_%H%M%S)"
    cp "$V2RAY_CONFIG_FILE" "$backup_file"
    echo -e "${YELLOW}Copia de seguridad creada en ${backup_file}${NC}"

    local nuevo_config=$(jq \
        --arg cert "$cert_file" \
        --arg key "$key_file" \
        --arg domain "$domain" \
        '
        .inbounds |= map(
            if .protocol == "vmess" or .protocol == "vless" then
                . + {
                    "streamSettings": (
                        if .streamSettings then .streamSettings else {} end
                    ) | . + {
                        "network": "ws",
                        "security": "tls",
                        "tlsSettings": (
                            if .tlsSettings then .tlsSettings else {} end
                        ) | . + {
                            "serverName": $domain,
                            "certificates": [
                                (
                                    if (.certificates | length) > 0 then
                                        .certificates[0]
                                    else
                                        {}
                                    end
                                ) | . + {
                                    "certificateFile": $cert,
                                    "keyFile": $key
                                }
                            ]
                        }
                    }
                }
            else
                .
            end
        )
        ' "$V2RAY_CONFIG_FILE")

    if [ $? -eq 0 ] && [ -n "$nuevo_config" ] && jq -e . <<< "$nuevo_config" > /dev/null 2>&1; then
        echo "$nuevo_config" > "$V2RAY_CONFIG_FILE"
        echo -e "${GREEN}Archivo '$V2RAY_CONFIG_FILE' actualizado con las nuevas rutas TLS y serverName.${NC}"

        echo -e "${YELLOW}Reiniciando V2Ray para aplicar la nueva configuración TLS...${NC}"
        "$V2RAY_COMMAND" restart
        sleep 2
        echo -e "${GREEN}Comando de reinicio de V2Ray ejecutado.${NC}"
        echo -e "${YELLOW}Verifica que V2Ray inicie correctamente y que TLS funcione.${NC}"
    else
        echo -e "${RED}Error: Falló la actualización de '$V2RAY_CONFIG_FILE' con jq o el resultado fue inválido.${NC}"
        echo -e "${YELLOW}Se mantiene el archivo original. Revisa el backup '${backup_file}' y el archivo temporal generado (si existe).${NC}"
    fi

    read -p "Presione Enter para continuar..."
}


# >>>>> BUCLE PRINCIPAL DEL SCRIPT <<<<<
checks_done="" # Bandera para ejecutar checks solo una vez
_GLOBAL_ALL_OK_CHECK=false # Inicializa la variable global

while true; do
  clear

  # --- Ejecutar comprobaciones iniciales ---
  if [[ -z "$checks_done" ]]; then
      menu_check
      checks_done=true
      if ! $_GLOBAL_ALL_OK_CHECK; then
         read -rp " Se detectaron problemas. Presiona Enter para mostrar el menú de todas formas..."
      fi
      clear
  fi

  # --- Mostrar Menú ---
  echo -e "${GREEN}===== Administrador de V2Ray (Termux) =====${NC}"
  echo -e "${BLUE}[1] Instalar V2Ray y JQ (pkg/apt)${NC}"
  echo -e "${BLUE}[2] Cambiar protocolo${NC}"
  echo -e "${BLUE}[3] Activar/Renovar TLS${NC}"
  echo -e "${BLUE}[4] Cambiar puerto V2Ray${NC}"
  echo -e "${BLUE}[5] Agregar usuario UUID${NC}"
  echo -e "${BLUE}[6] Eliminar usuario UUID${NC}"
  echo -e "${BLUE}[7] Mostrar usuarios registrados${NC}"
  echo -e "${YELLOW}[8] Información de cuentas ${RED}(No implementado)${NC}"
  echo -e "${YELLOW}[9] Estadísticas de consumo ${RED}(No implementado)${NC}"
  echo -e "${YELLOW}[10] Limitador por consumo (BETA) ${RED}(No implementado)${NC}"
  echo -e "${YELLOW}[11] Limpiador de expirados ${RED}(No implementado)${NC}"
  echo -e "${YELLOW}[12] Desinstalar V2Ray ${RED}(No implementado)${NC}"
  echo -e "${BLUE}[13] Iniciar servidor V2Ray${NC}"
  echo -e "${BLUE}[14] Reiniciar servidor V2Ray${NC}"
  echo -e "${BLUE}[15] Apagar servidor V2Ray${NC}"
  echo -e "${RED}[0] Salir${NC}"

  # --- Leer Opción ---
  read -p "Seleccione una opción: " opcion

  # --- Procesar Opción ---
  case $opcion in
    1)
      echo -e "\n${YELLOW}Intentando instalar V2Ray y jq usando pkg o apt...${NC}"
      if command -v pkg &> /dev/null; then
          pkg update && pkg install v2ray jq git -y
      elif command -v apt &> /dev/null; then
          apt update && apt install v2ray jq git -y
      else
          echo -e "${RED}Error: No se encontró 'pkg' ni 'apt'. No se puede instalar V2Ray/jq automáticamente.${NC}"
      fi
      echo -e "${GREEN}Instalación intentada. Verifica si hubo errores.${NC}"
      read -p "Presione Enter para continuar..."
      ;;
    2)
      execute_external_script "./change_protocol.sh" "change_protocol.sh"
      read -p "Presione Enter para continuar..."
      ;;
    3)
      activar_tls
      ;;
    4)
      cambiar_puerto_v2ray
      ;;
    5)
      execute_external_script "./add_user.sh" "add_user.sh"
      read -p "Presione Enter para continuar..."
      ;;
    6)
      eliminar_usuario_uuid
      ;;
    7)
      mostrar_usuarios_registrados
      ;;
    8)
      echo -e "\n${RED}Función [Información de cuentas] no implementada aún.${NC}"
      echo -e "Mantente atento a futuras actualizaciones."
      read -p "Presione Enter para continuar..."
      ;;
    9)
      echo -e "\n${RED}Función [Estadísticas de consumo] no implementada aún.${NC}"
      echo -e "Mantente atento a futuras actualizaciones."
      read -p "Presione Enter para continuar..."
      ;;
    10)
      echo -e "\n${RED}Función [Limitador por consumo (BETA)] no implementada aún.${NC}"
      echo -e "Mantente atento a futuras actualizaciones."
      read -p "Presione Enter para continuar..."
      ;;
    11)
      echo -e "\n${RED}Función [Limpiador de expirados] no implementada aún.${NC}"
      echo -e "Mantente atento a futuras actualizaciones."
      read -p "Presione Enter para continuar..."
      ;;
    12)
      echo -e "\n${RED}Función [Desinstalar V2Ray] no implementada aún.${NC}"
      echo -e "Mantente atento a futuras actualizaciones."
      read -p "Presione Enter para continuar..."
      ;;
    13)
      echo -e "\n${YELLOW}Intentando iniciar V2Ray...${NC}"
      "$V2RAY_COMMAND" start
      sleep 1
      echo -e "${GREEN}Comando '$V2RAY_COMMAND start' ejecutado.${NC}"
      read -p "Presione Enter para continuar..."
      ;;
    14)
      echo -e "\n${YELLOW}Intentando reiniciar V2Ray...${NC}"
      "$V2RAY_COMMAND" restart
      sleep 1
      echo -e "${GREEN}Comando '$V2RAY_COMMAND restart' ejecutado.${NC}"
      read -p "Presione Enter para continuar..."
      ;;
    15)
      echo -e "\n${YELLOW}Intentando detener V2Ray...${NC}"
      "$V2RAY_COMMAND" stop
      sleep 1
      echo -e "${GREEN}Comando '$V2RAY_COMMAND stop' ejecutado.${NC}"
      read -p "Presione Enter para continuar..."
      ;;
    0)
      echo -e "\nSaliendo del Administrador de V2Ray. ¡Hasta pronto!${NC}"
      break
      ;;
    *)
      echo -e "\n${RED}Opción inválida. Por favor, ingrese un número del 0 al 15.${NC}"
      read -p "Presione Enter para continuar..."
      ;;
  esac
done
