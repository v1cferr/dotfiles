#!/usr/bin/env bash
# ============================================================================
#  Build do Caddy CUSTOM (com o plugin dns.providers.cloudflare)
# ----------------------------------------------------------------------------
#  O pacote `caddy` do Arch (/usr/bin/caddy) NÃO traz o plugin de DNS da
#  Cloudflare, exigido pelo DNS-01 challenge do certificado curinga
#  *.v1cferr.dev (ver caddy/etc/caddy/Caddyfile). Um `pacman -Syu` já
#  sobrescreveu o binário custom uma vez e derrubou o proxy inteiro.
#
#  Solução (boa prática em rolling release): manter o binário com plugin FORA
#  do controle do pacman, em /usr/local/bin/caddy. A unit do systemd aponta
#  para lá via drop-in (caddy/etc/systemd/system/caddy.service.d/exec.conf).
#  Assim o pacman pode atualizar /usr/bin/caddy à vontade — não é usado.
#
#  Atualizar a versão do Caddy = rodar ESTE script (não o pacman).
#
#  Uso:  ~/dotfiles/scripts/caddy/build.sh [versao]      # ex.: v2.11.4
#        (NÃO rode com sudo; o build roda como você, só o install pede root)
# ============================================================================
set -euo pipefail

CADDY_VERSION="${1:-v2.11.4}"
PLUGIN="github.com/caddy-dns/cloudflare"
DEST="/usr/local/bin/caddy"

command -v go >/dev/null || { echo "go não encontrado. Instale: pacman -S go" >&2; exit 1; }

GOBIN="$(go env GOPATH)/bin"
if [[ ! -x "${GOBIN}/xcaddy" ]]; then
    echo "[build] xcaddy ausente — instalando..."
    GOFLAGS=-buildvcs=false go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
echo "[build] compilando caddy ${CADDY_VERSION} + ${PLUGIN} (em ${WORK})..."
( cd "${WORK}" && GOFLAGS=-buildvcs=false PATH="${PATH}:${GOBIN}" \
    xcaddy build "${CADDY_VERSION}" --with "${PLUGIN}" --output ./caddy )

# Sanidade: o plugin TEM que estar presente, senão o restart vai falhar igual.
if ! "${WORK}/caddy" list-modules | grep -q '^dns.providers.cloudflare$'; then
    echo "[build] ERRO: o binário ficou sem dns.providers.cloudflare" >&2
    exit 1
fi
echo "[build] plugin dns.providers.cloudflare confirmado."

echo "[build] instalando em ${DEST} (precisa de root)..."
sudo install -Dm0755 "${WORK}/caddy" "${DEST}"
"${DEST}" version
echo "[build] ok. Aplique a config/unit com: sudo ~/dotfiles/scripts/caddy/deploy.sh"
