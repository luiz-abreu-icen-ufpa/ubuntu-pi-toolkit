# Ubuntu Server / Raspberry Pi Toolkit

Conjunto de scripts em Bash para provisionamento de ambiente gráfico remoto (XFCE + xRDP), diagnóstico e auditoria interativa de hardening em servidores Ubuntu (testado no Ubuntu 26.10 ARM64 / Raspberry Pi).

## Estrutura do Projeto

```text
ubuntu-pi-toolkit/
├── scripts/
│   ├── instalar_xfce_rdp.sh      # Instalação não-interativa do XFCE e configuração de sessão RDP
│   ├── diag_xrdp.sh              # Diagnóstico completo de serviços, PAM, sesman.ini e logs do xRDP
│   └── hardening_interativo.sh   # Auditoria de segurança, plano de ação priorizado e relatório .txt
├── .gitignore
└── README.md
```

## Como Usar

### 1. Instalar XFCE para acesso RDP (Modo Silencioso)
Instala o XFCE enxuto (`xfce4`, `xfce4-goodies`, `dbus-x11`) sem prompts interativos, configura `~/.xsession` e reinicia o `xrdp`:
```bash
./scripts/instalar_xfce_rdp.sh
```

### 2. Diagnóstico do xRDP e Autenticação PAM
Coleta informações do sistema, status dos serviços (`xrdp`, `xrdp-sesman`, `lightdm`), regras do `sesman.ini`, configuração PAM e logs recentes:
```bash
./scripts/diag_xrdp.sh
```

### 3. Auditoria & Hardening Interativo
Verifica Firewall (`UFW`), `SSH`, `Fail2Ban`, atualizações automáticas (`unattended-upgrades`), criptografia/permissões do `xRDP` e serviços expostos. Ordena as correções por gravidade (`CRÍTICO` a `BAIXO`), permite execução seletiva e salva um relatório final em `.txt`:
```bash
./scripts/hardening_interativo.sh
```

## Requisitos
- Ubuntu Server 24.04 / 26.04 / 26.10+
- Acesso `sudo`
