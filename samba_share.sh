#!/bin/bash


if [[ $EUID -ne 0 ]]; then
  echo "Необходим root"
  exit 1
fi

read -p "Выбор режима (create/delete): " action
if [[ "$action" != "create" && "$action" != "delete" ]]; then
  echo "Введи create или delete"
  exit 1
fi

read -p "Имя шары: " share_name
read -p "Путь к папке: " share_path

if [[ "$action" == "create" ]]; then
  read -p "Пользователь или группа (user_name или @users): " access_user
  read -p "Тип доступа (ro - чтение, rw - чтение+запись): " access_type
  
  mkdir -p "$share_path"
  chown -R "$access_user":"users" "$share_path"

  if [[ "$access_type" == "rw" ]]; then
    chmod 2770 "$share_path"
    writable="yes"
  else
    chmod 2750 "$share_path"
    writable="no"
  fi

  # проверка на такую шару
  if grep -q "^\[$share_name\]" /etc/samba/smb.conf; then
    echo "Шара [$share_name] уже существует в конфиге!"
    exit 1
  fi

  # добавляем в конец smb.conf
  cat <<EOF >> /etc/samba/smb.conf

[$share_name]
   path = $share_path
   browsable = yes
   writable = $writable
   guest ok = no
   valid users = $access_user
EOF

  echo "Шара [$share_name] добавлена."

elif [[ "$action" == "delete" ]]; then
  # уаляем блок из smb.conf
  if ! grep -q "^\[$share_name\]" /etc/samba/smb.conf; then
    echo "Шара [$share_name] не найдена в конфиге"
    exit 1
  fi

  # удаление блока из smb.conf (от имени шары до пустой строки)
  sed -i "/^\[$share_name\]/,/^$/d" /etc/samba/smb.conf
  echo "Шара [$share_name] удалена из конфигурации."

  # удаление папки
  read -p "Удалить папку $share_path с файлами? (y/N): " delete_folder
  if [[ "$delete_folder" == "y" || "$delete_folder" == "Y" ]]; then
    rm -rf "$share_path"
    echo "Папка удалена."
  fi
fi

# test and reboot
testparm -s
systemctl restart smb.service
echo "Samba перезапущена."

