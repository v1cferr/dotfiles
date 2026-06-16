#!/usr/bin/env bash
#
# send-wol.sh — Envia um Wake-on-LAN magic packet para o superintendencia-server.
#
# Sem dependencias: usa o /dev/udp embutido no bash (nao precisa do pacote
# `wakeonlan`/`wol`). Pensado para ligar a maquina de casa pela VPN.
#
# Uso:
#   ./send-wol.sh                 # usa os padroes (MAC e broadcast ja configurados)
#   ./send-wol.sh -t 200.136.209.255 -m 8c:86:dd:61:22:12 -p 9
#   ./send-wol.sh -n 3            # envia 3 vezes (UDP nao garante entrega)
#
# Por que mirar o broadcast .255 e nao o IP .229: ver README.md (secao 3).
# Pela VPN, 200.136.209.255 e' so um IP roteavel para o kernel local, entao
# o /dev/udp envia normalmente (nao precisa de SO_BROADCAST).

set -euo pipefail

MAC="8c:86:dd:61:22:12"   # MAC da enp7s0 do servidor
TARGET="200.136.209.255"  # broadcast da sub-rede 200.136.209.128/25
PORT=9
COUNT=1

usage() {
  cat <<EOF
Uso: $(basename "$0") [-m MAC] [-t ALVO] [-p PORTA] [-n VEZES]
  -m MAC     MAC do alvo            (padrao: $MAC)
  -t ALVO    IP/broadcast de destino (padrao: $TARGET)
  -p PORTA   porta UDP              (padrao: $PORT)
  -n VEZES   quantos pacotes enviar (padrao: $COUNT)
  -h         mostra esta ajuda
EOF
}

while getopts "m:t:p:n:h" opt; do
  case "$opt" in
    m) MAC="$OPTARG" ;;
    t) TARGET="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    n) COUNT="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

# Normaliza o MAC: remove ':' e '-', deixa minusculo, valida 12 digitos hex.
clean="${MAC//[:-]/}"
clean="${clean,,}"
if [[ ! "$clean" =~ ^[0-9a-f]{12}$ ]]; then
  echo "Erro: MAC invalido: '$MAC'" >&2
  exit 1
fi

# Monta o magic packet em hex: 6x FF + 16x MAC = 102 bytes.
hex="ffffffffffff"
for _ in {1..16}; do hex+="$clean"; done

# Converte o hex para uma string de escapes \xHH para o printf.
esc=""
for ((i = 0; i < ${#hex}; i += 2)); do
  esc+="\\x${hex:i:2}"
done

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Erro: porta invalida: '$PORT'" >&2
  exit 1
fi
if [[ ! "$COUNT" =~ ^[0-9]+$ ]] || (( COUNT < 1 )); then
  echo "Erro: numero de envios invalido: '$COUNT'" >&2
  exit 1
fi

for ((n = 1; n <= COUNT; n++)); do
  # /dev/udp/HOST/PORTA: o bash abre o socket UDP e escreve o datagrama.
  if ! printf '%b' "$esc" > "/dev/udp/${TARGET}/${PORT}"; then
    echo "Erro: falha ao enviar para ${TARGET}:${PORT}" >&2
    exit 1
  fi
done

echo "Magic packet enviado (${COUNT}x) -> ${TARGET} (porta ${PORT}) para ${MAC}"
