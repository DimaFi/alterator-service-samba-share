#!/bin/bash

# Пути к исходным файлам
MAIN_SCRIPT="/usr/bin/samba-shares"
BACKEND_FILE="/usr/share/alterator/backends/samba-shares.backend"
SYSTEMD_SERVICE="/usr/share/alterator/service/samba-shares.service"
LOG_FILE="/var/log/samba-shares.log"
LOCK_FILE="/var/lock/samba-shares.lock"

# Папка для резервной копии
BACKUP_DIR="/home/admin/Документы/Project Samba/src"

# Создаем папку для бэкапа, если не существует
mkdir -p "$BACKUP_DIR"

copy_file() {
  local src="$1"
  local dest_dir="$2"
  local filename
  filename=$(basename "$src")

  if [[ -f "$src" && -r "$src" ]]; then
    cat "$src" > "$dest_dir/$filename"
    echo "Скопирован файл: $src -> $dest_dir/$filename"
  else
    echo "Файл $src не найден или нет прав на чтение."
  fi
}

copy_file "$MAIN_SCRIPT" "$BACKUP_DIR"
copy_file "$BACKEND_FILE" "$BACKUP_DIR"
copy_file "$SYSTEMD_SERVICE" "$BACKUP_DIR"
copy_file "$LOG_FILE" "$BACKUP_DIR"
copy_file "$LOCK_FILE" "$BACKUP_DIR"

echo "Все доступные файлы успешно скопированы в $BACKUP_DIR"
