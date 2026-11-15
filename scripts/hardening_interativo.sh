#!/bin/bash

# Garante credencial sudo antes de iniciar a coleta
sudo -v || exit 1

VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
AZUL='\033[0;34m'
CIANO='\033[0;36m'
CINZA='\033[0;90m'
NC='\033[0m'

ACOES_PRIO=()
ACOES_DESC=()
ACOES_CMD=()
ACOES_STATUS=()
DIAGNOSTICO_LOG=()

PONTOS_OK=0
PONTOS_ALERTA=0
PONTOS_CRITICO=0

add_acao() {
    ACOES_PRIO+=("$1")
    ACOES_DESC+=("$2")
    ACOES_CMD+=("$3")
    ACOES_STATUS+=("PENDENTE")
}

check_ok() {
    echo -e "${VERDE}[OK]${NC} $1"
    DIAGNOSTICO_LOG+=("[OK]      $1")
    ((PONTOS_OK++))
}

check_warn() {
    echo -e "${AMARELO}[ALERTA]${NC} $1"
    DIAGNOSTICO_LOG+=("[ALERTA]  $1")
    ((PONTOS_ALERTA++))
}

check_crit() {
    echo -e "${VERMELHO}[CRÍTICO]${NC} $1"
    DIAGNOSTICO_LOG+=("[CRÍTICO] $1")
    ((PONTOS_CRITICO++))
}

salvar_relatorio() {
    local ARQUIVO="$HOME/relatorio_hardening_$(hostname)_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "================================================================="
        echo " RELATÓRIO DE AUDITORIA E HARDENING - $(hostname)"
        echo " Data/Hora: $(date '+%d/%m/%Y %H:%M:%S')"
        echo " Sistema:   $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
        echo "================================================================="
        echo ""
        echo "1. RESUMO DO DIAGNÓSTICO INICIAL"
        echo "   - Itens Conformes (OK): $PONTOS_OK"
        echo "   - Alertas:              $PONTOS_ALERTA"
        echo "   - Críticos:             $PONTOS_CRITICO"
        echo ""
        echo "2. DETALHES DA VERIFICAÇÃO"
        for linha in "${DIAGNOSTICO_LOG[@]}"; do
            echo "   $linha"
        done
        echo ""
        echo "3. STATUS DO PLANO DE AÇÃO"
        if [ ${#ACOES_DESC[@]} -eq 0 ]; then
            echo "   Nenhuma ação corretiva necessária."
        else
            for ((i=0; i<${#ACOES_DESC[@]}; i++)); do
                case "${ACOES_PRIO[i]}" in
                    1) NIVEL="1-CRÍTICO" ;;
                    2) NIVEL="2-ALTO   " ;;
                    3) NIVEL="3-MÉDIO  " ;;
                    4) NIVEL="4-BAIXO  " ;;
                esac
                if [ "${ACOES_STATUS[i]}" == "EXECUTADO" ]; then
                    echo "   [✔] EXECUTADO | [$NIVEL] ${ACOES_DESC[i]}"
                else
                    echo "   [ ] PENDENTE  | [$NIVEL] ${ACOES_DESC[i]}"
                fi
            done
        fi
        echo ""
        echo "================================================================="
    } > "$ARQUIVO"

    echo -e "\n${VERDE}[✔] Relatório salvo com sucesso em:${NC} ${CIANO}$ARQUIVO${NC}"
}

clear
echo -e "${AZUL}=================================================================${NC}"
echo -e "${AZUL}   AUDITORIA & HARDENING INTERATIVO - $(hostname)${NC}"
echo -e "${AZUL}=================================================================${NC}"
echo "Coletando informações do sistema..."

# --- 1. FIREWALL (UFW) ---
echo -e "\n${AZUL}--- 1. Firewall (UFW) ---${NC}"
if ! command -v ufw >/dev/null 2>&1; then
    check_crit "Firewall UFW não está instalado."
    add_acao 1 "Instalar UFW, liberar SSH (22) e RDP apenas na LAN (192.168.1.0/24)" \
        "sudo apt-get update && sudo apt-get install -y ufw && sudo ufw allow 22/tcp && sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp && sudo ufw --force enable"
else
    UFW_STATUS=$(sudo ufw status | grep -i "Status:" | awk '{print $2}')
    if [ "$UFW_STATUS" != "active" ]; then
        check_crit "Firewall UFW instalado, mas INATIVO."
        add_acao 1 "Ativar UFW liberando SSH (22) e RDP apenas na LAN (192.168.1.0/24)" \
            "sudo ufw allow 22/tcp && sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp && sudo ufw --force enable"
    else
        if sudo ufw status | grep -E "^3389(/tcp)?(\s+\(v6\))?\s+ALLOW\s+Anywhere" >/dev/null; then
            check_warn "Porta RDP (3389) aberta para qualquer origem (Anywhere)."
            add_acao 2 "Remover regras globais da porta 3389 e restringir apenas para 192.168.1.0/24" \
                "sudo ufw delete allow 3389/tcp 2>/dev/null; sudo ufw delete allow 3389 2>/dev/null; sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp && sudo ufw reload"
        else
            check_ok "Firewall UFW ativo e porta RDP restrita."
        fi
    fi
fi

# --- 2. SERVIÇO SSH ---
echo -e "\n${AZUL}--- 2. Segurança do SSH ---${NC}"
SSHD_CONFIG=$(sudo sshd -T 2>/dev/null)
ROOT_LOGIN=$(echo "$SSHD_CONFIG" | grep -i "^permitrootlogin " | awk '{print tolower($2)}')
if [ "$ROOT_LOGIN" == "no" ] || [ "$ROOT_LOGIN" == "prohibit-password" ]; then
    check_ok "Login direto como root via SSH bloqueado ($ROOT_LOGIN)."
else
    check_crit "PermitRootLogin habilitado no SSH (${ROOT_LOGIN:-indefinido})."
    add_acao 1 "Bloquear login direto de root via SSH (PermitRootLogin no)" \
        "sudo mkdir -p /etc/ssh/sshd_config.d && echo 'PermitRootLogin no' | sudo tee -a /etc/ssh/sshd_config.d/00-hardening.conf >/dev/null && sudo systemctl reload ssh"
fi

PASS_AUTH=$(echo "$SSHD_CONFIG" | grep -i "^passwordauthentication " | awk '{print tolower($2)}')
if [ "$PASS_AUTH" == "no" ]; then
    check_ok "Autenticação por senha no SSH desativada (apenas chaves)."
else
    check_warn "Autenticação por senha no SSH está ATIVA (${PASS_AUTH:-yes})."
    add_acao 3 "Desativar senha no SSH (ATENÇÃO: só execute se já tiver chave SSH configurada!)" \
        "sudo mkdir -p /etc/ssh/sshd_config.d && echo 'PasswordAuthentication no' | sudo tee -a /etc/ssh/sshd_config.d/00-hardening.conf >/dev/null && sudo systemctl reload ssh"
fi

# --- 3. FAIL2BAN ---
echo -e "\n${AZUL}--- 3. Proteção contra Força Bruta (Fail2Ban) ---${NC}"
if systemctl is-active --quiet fail2ban; then
    check_ok "Fail2Ban está instalado e ativo."
else
    check_warn "Fail2Ban não está ativo."
    add_acao 2 "Instalar e ativar Fail2Ban para bloquear tentativas de invasão" \
        "sudo apt-get update && sudo apt-get install -y fail2ban && sudo systemctl enable --now fail2ban"
fi

# --- 4. ATUALIZAÇÕES ---
echo -e "\n${AZUL}--- 4. Atualizações do Sistema ---${NC}"
UPDATES=$(apt-get -s upgrade 2>/dev/null | awk '/^[0-9]+ upgraded/ {print $1}')
if [ "${UPDATES:-0}" -eq 0 ]; then
    check_ok "Todos os pacotes disponíveis estão atualizados."
else
    check_warn "$UPDATES pacotes pendentes de atualização."
    add_acao 2 "Atualizar pacotes do sistema (apt upgrade)" \
        "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
fi

if dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q "install ok installed" && [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    check_ok "Atualizações automáticas de segurança (unattended-upgrades) configuradas."
else
    check_warn "unattended-upgrades não instalado ou não configurado."
    add_acao 3 "Instalar e ativar atualizações automáticas de segurança" \
        "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades && echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections && sudo dpkg-reconfigure -f noninteractive unattended-upgrades"
fi

# --- 5. SEGURANÇA DO XRDP ---
echo -e "\n${AZUL}--- 5. Segurança do xRDP ---${NC}"
if systemctl is-active --quiet xrdp; then
    XRDP_ROOT=$(grep -E "^[[:space:]]*AllowRootLogin[[:space:]]*=" /etc/xrdp/sesman.ini | tail -n1 | cut -d'=' -f2 | tr -d ' ')
    if [ "$XRDP_ROOT" == "false" ]; then
        check_ok "AllowRootLogin no xRDP está bloqueado."
    else
        check_warn "AllowRootLogin não está bloqueado explicitamente no /etc/xrdp/sesman.ini (atual: ${XRDP_ROOT:-true})."
        add_acao 2 "Bloquear login direto de root no xRDP" \
            "sudo sed -i -E 's/^[#[:space:]]*AllowRootLogin[[:space:]]*=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini && grep -q '^AllowRootLogin=false' /etc/xrdp/sesman.ini || sudo sed -i '/^\[Security\]/a AllowRootLogin=false' /etc/xrdp/sesman.ini; sudo systemctl restart xrdp-sesman"
    fi

    XRDP_CRYPT=$(grep -E "^[[:space:]]*crypt_level[[:space:]]*=" /etc/xrdp/xrdp.ini | tail -n1 | cut -d'=' -f2 | tr -d ' ')
    if [ "$XRDP_CRYPT" == "high" ] || [ "$XRDP_CRYPT" == "fips" ]; then
        check_ok "Criptografia do xRDP configurada como '$XRDP_CRYPT'."
    else
        check_warn "Criptografia do xRDP não está configurada como 'high' (atual: ${XRDP_CRYPT:-indefinido})."
        add_acao 3 "Forçar criptografia alta (crypt_level=high) no xRDP" \
            "sudo sed -i -E 's/^[#[:space:]]*crypt_level[[:space:]]*=.*/crypt_level=high/' /etc/xrdp/xrdp.ini && grep -q '^crypt_level=high' /etc/xrdp/xrdp.ini || sudo sed -i '/^\[Globals\]/a crypt_level=high' /etc/xrdp/xrdp.ini; sudo systemctl restart xrdp"
    fi
fi

# --- 6. SERVIÇOS OPCIONAIS ---
echo -e "\n${AZUL}--- 6. Redução de Superfície de Ataque ---${NC}"
if systemctl is-active --quiet avahi-daemon; then
    check_warn "avahi-daemon (descoberta .local/mDNS) está ativo."
    add_acao 4 "Desativar avahi-daemon (reduz exposição na rede local)" \
        "sudo systemctl disable --now avahi-daemon avahi-daemon.socket"
else
    check_ok "avahi-daemon já está desativado."
fi

# --- ORDENAÇÃO POR PRIORIDADE (1 -> 4) ---
TOTAL=${#ACOES_DESC[@]}
if [ "$TOTAL" -eq 0 ]; then
    echo -e "\n${VERDE}=================================================================${NC}"
    echo -e "${VERDE}Parabéns! Nenhuma pendência de hardening encontrada.${NC}"
    echo -e "${VERDE}=================================================================${NC}"
    salvar_relatorio
    exit 0
fi

for ((i=0; i<TOTAL; i++)); do
    for ((j=0; j<TOTAL-i-1; j++)); do
        if [ "${ACOES_PRIO[j]}" -gt "${ACOES_PRIO[j+1]}" ]; then
            for arr in ACOES_PRIO ACOES_DESC ACOES_CMD ACOES_STATUS; do
                eval "tmp=\${$arr[j]}"
                eval "$arr[j]=\${$arr[j+1]}"
                eval "$arr[j+1]=\"\$tmp\""
Use o código com cuidado.
done
fi
done
done

--- MENU INTERATIVO ---

while true; do
echo -e "\n${AZUL}=================================================================${NC}"
echo -e "${AZUL}   PLANO DE AÇÃO (ORDENADO POR GRAU DE IMPORTÂNCIA)${NC}"
echo -e "${AZUL}=================================================================${NC}"
PENDENTES=0
for ((i=0; i<TOTAL; i++)); do
NUM=$((i+1))
case "${ACOES_PRIO[i]}" in
1) TAG="${VERMELHO}[1-CRÍTICO]${NC}" ;;
2) TAG="${AMARELO}[2-ALTO]   ${NC}" ;;
3) TAG="${CIANO}[3-MÉDIO]  ${NC}" ;;
4) TAG="${CINZA}[4-BAIXO]  ${NC}" ;;
esac
if [ "${ACOES_STATUS[i]}" == "EXECUTADO" ]; then
echo -e "  ${VERDE}[✔] $NUM)${NC} $TAG ${CINZA}${ACOES_DESC[i]} (Concluído)${NC}"
else
echo -e "  [ ] $NUM) $TAG ${ACOES_DESC[i]}"
((PENDENTES++))
fi
done
echo -e "${AZUL}-----------------------------------------------------------------${NC}"
echo -e "  ${AMARELO}0)${NC} Terminar script e salvar relatório (.txt)"
echo -e "${AZUL}-----------------------------------------------------------------${NC}"
if [ "$PENDENTES" -eq 0 ]; then
echo -e "${VERDE}Todas as ações recomendadas foram concluídas!${NC}"
salvar_relatorio
break
fi
echo -e "Escolha o ${CIANO}número${NC} da ação para executar ou ${AMARELO}0${NC} para encerrar e salvar:"
read -r -p "> " ESCOLHA
if [[ "$ESCOLHA" == "0" ]] || [[ "$ESCOLHA" == "q" ]] || [[ "$ESCOLHA" == "sair" ]]; then
salvar_relatorio
echo "Encerrando o assistente de hardening."
break
fi
if ! [[ "$ESCOLHA" =~ ^[0-9]+$ ]] || [ "$ESCOLHA" -lt 1 ] || [ "$ESCOLHA" -gt "$TOTAL" ]; then
echo -e "${VERMELHO}Opção inválida. Digite um número entre 1 e $TOTAL (ou 0 para encerrar e salvar).${NC}"
continue
fi
IDX=$((ESCOLHA-1))
if [ "${ACOES_STATUS[IDX]}" == "EXECUTADO" ]; then
echo -e "${AMARELO}A ação #$ESCOLHA já foi executada! Escolha uma opção pendente ou digite 0.${NC}"
continue
fi
echo -e "\n${CIANO}>>> Executando ação #$ESCOLHA: ${ACOES_DESC[IDX]}${NC}"
echo -e "${CINZA}Comando: ${ACOES_CMD[IDX]}${NC}\n"
if eval "${ACOES_CMD[IDX]}"; then
ACOES_STATUS[IDX]="EXECUTADO"
echo -e "\n${VERDE}[✔] Ação #$ESCOLHA aplicada com sucesso!${NC}"
else
echo -e "\n${VERMELHO}[X] Ocorreu um erro ao executar a ação #$ESCOLHA. Verifique a saída acima.${NC}"
fi
done
