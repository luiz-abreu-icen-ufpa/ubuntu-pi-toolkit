#!/bin/bash
echo "================ SISTEMA E AMBIENTE ================"
lsb_release -a 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME
echo "Usuário atual: $(whoami) | Grupos: $(groups)"
echo "Sessões disponíveis (/usr/share/xsessions):"
ls -la /usr/share/xsessions/ 2>/dev/null
echo "Arquivo ~/.xsession:"
cat ~/.xsession 2>/dev/null || echo "Não existe"

echo -e "\n================ STATUS DOS SERVIÇOS ================"
systemctl is-active xrdp xrdp-sesman lightdm

echo -e "\n================ CONFIGURAÇÃO SESMAN.INI ================"
grep -E "^(AllowRootLogin|MaxLoginRetry|TerminalServerUsers|TerminalServerAdmins|AlwaysGroupCheck|RestrictOutboundClipboard)" /etc/xrdp/sesman.ini 2>/dev/null

echo -e "\n================ CONFIGURAÇÃO PAM (xrdp-sesman) ================"
cat /etc/pam.d/xrdp-sesman 2>/dev/null || echo "Arquivo /etc/pam.d/xrdp-sesman não encontrado"

echo -e "\n================ LOGS RECENTES (xrdp-sesman.log) ================"
sudo tail -n 25 /var/log/xrdp-sesman.log 2>/dev/null

echo -e "\n================ LOGS DE AUTENTICAÇÃO (auth.log) ================"
sudo grep -iE "xrdp|sesman" /var/log/auth.log 2>/dev/null | tail -n 20
