#!/bin/bash
set -e

echo "=== 1. Configurando modo não-interativo e pré-definindo LightDM ==="
export DEBIAN_FRONTEND=noninteractive
echo "lightdm shared/default-x-display-manager select lightdm" | sudo debconf-set-selections

echo "=== 2. Atualizando repositórios e instalando XFCE ==="
sudo apt-get update -y
sudo apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    xfce4 xfce4-goodies dbus-x11

echo "=== 3. Configurando ~/.xsession para o usuário $USER ==="
echo "xfce4-session" > "$HOME/.xsession"
chmod +x "$HOME/.xsession"

echo "=== 4. Reiniciando serviços xRDP ==="
sudo systemctl restart xrdp xrdp-sesman

echo "=== Concluído! XFCE configurado e pronto para acesso RDP. ==="
