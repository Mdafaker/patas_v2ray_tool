k#!/data/data/com.termux/files/usr/bin/bash

cd ~/patas_v2ray_tool

branch=$(git branch --show-current)
fecha=$(date +"%Y-%m-%d %H:%M:%S")

echo "[$fecha] --- INICIANDO PUSH AUTOMÁTICO ---" >> git_push.log
echo "Usando rama: $branch"
echo "[$fecha] Rama activa: $branch" >> git_push.log

# Verificar si hay cambios sin guardar
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "⚠️ Cambios locales detectados, haciendo stash..."
    echo "[$fecha] ⚠️ Se detectaron cambios locales, haciendo stash." >> git_push.log
    git stash push -m "stash auto antes de pull" >> git_push.log 2>&1
fi

# Pull remoto
echo "Actualizando desde remoto con 'git pull'..."
git pull origin "$branch" >> git_push.log 2>&1

if [[ $? -ne 0 ]]; then
    echo "❌ Error durante 'git pull'. Conflicto o problema de red."
    echo "[$fecha] ❌ Error durante 'git pull'." >> git_push.log
    exit 1
fi

# Recuperar cambios si hubo stash
if git stash list | grep -q "stash@{0}: On $branch: stash auto antes de pull"; then
    echo "🔄 Restaurando cambios locales con 'git stash pop'..."
    echo "[$fecha] 🔄 Restaurando stash." >> git_push.log
    git stash pop >> git_push.log 2>&1
fi

# Agregar y hacer commit
git add .
git commit -m "Backup automático: $fecha" >> git_push.log 2>&1

# Push
echo "📤 Subiendo cambios a GitHub..."
git push origin "$branch" >> git_push.log 2>&1

if [[ $? -eq 0 ]]; then
    echo "✅ Push exitoso."
    echo "[$fecha] ✅ Push completado con éxito." >> git_push.log
else
    echo "❌ Error al hacer push."
    echo "[$fecha] ❌ Falló el push." >> git_push.log
fi
