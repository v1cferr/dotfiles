#!/usr/bin/env bash
# ============================================================================
#  Escurece a tela no AFK via GAMMA do hyprsunset — NUNCA via dpms.
# ----------------------------------------------------------------------------
#  dpms off/on reconfigura o output e trava o page-flip atomic da NVIDIA
#  (driver 610): a tela CONGELA ao religar sob lock e só sai com reboot
#  (ver hypridle.conf e a memória hyprlock-dpms-freeze). Gamma só altera a
#  LUT de cor — não reconfigura output, não dispara page-flip — e é o mesmo
#  mecanismo do brilho (teclas F / brightness-osd.sh), logo é seguro aqui.
#
#    dim     -> salva o gamma atual e zera (tela preta; monitor SEGUE ligado).
#    restore -> devolve o gamma salvo (ou 100 se não houver estado).
#
#  Obs.: isto ESCURECE, não desliga o monitor (sem backlight/DDC nesta máquina;
#  dpms é a única forma de power-off real e está descartada pelo freeze).
# ============================================================================
set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-idle-dim.gamma"

read_gamma() { hyprctl hyprsunset gamma 2>/dev/null | tr -dc '0-9'; }

case "${1:-}" in
  dim)
    cur="$(read_gamma)"
    # só persiste valor plausível (>0): nunca salvar 0, senão "esquece" o brilho
    if [[ -n "${cur}" && "${cur}" -gt 0 ]]; then printf '%s' "${cur}" >"${STATE}"; fi
    hyprctl hyprsunset gamma 0 >/dev/null 2>&1
    ;;
  restore)
    g="$(tr -dc '0-9' <"${STATE}" 2>/dev/null)"
    [[ -z "${g}" || "${g}" -eq 0 ]] && g=100   # fallback se não houver estado
    hyprctl hyprsunset gamma "${g}" >/dev/null 2>&1
    ;;
  *)
    echo "uso: $0 dim|restore" >&2
    exit 2
    ;;
esac
