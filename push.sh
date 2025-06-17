#!/data/data/com.termux/files/usr/bin/bash

cd ~/patas_v2ray_tool

fecha=$(date +"%Y-%m-%d %H:%M:%S")

git add .
git commit -m "Backup automático: $fecha"
git push origin main
