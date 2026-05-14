#!/bin/bash
# Conecta à VPN da FAI.UFSCAR (SonicWALL)
# Requisito: netextender (AUR)

if ! command -v netExtender &> /dev/null; then
    echo "Erro: netExtender não encontrado. Instale com 'yay -S netextender'"
    exit 1
fi

echo "Conectando à VPN da FAI.UFSCAR (200.133.233.101:4433)..."

if ! systemctl is-active --quiet NEService; then
    echo "Iniciando NEService (serviço do NetExtender)..."
    sudo systemctl start NEService
fi

echo "Conectando à VPN da FAI.UFSCAR utilizando o perfil salvo..."
echo "Atenção: Primeiro será solicitada a sua senha do Linux (sudo)."
echo "Em seguida, o netExtender pedirá a sua senha da VPN."

sudo netExtender connect FAI.UFSCAR
