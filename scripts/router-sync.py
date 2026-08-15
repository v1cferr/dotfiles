"""router-sync — espelha o UCI do roteador OpenWrt no repo, com segredo redigido.

POR QUE EXISTE: a config do roteador era CEGA — 750 linhas que só existiam no
aparelho, invisíveis ao repo e a qualquer revisão. Isto não torna o roteador
declarativo (o Nix não alcança lá); torna a config VERSIONADA e o drift VISÍVEL,
que é o que estava faltando de verdade.

DUAS AÇÕES, as duas seguras:
  pull  — traz o estado do aparelho pro repo (bootstrap, e depois de mexer no LuCI)
  diff  — compara aparelho vs repo e sai 1 se divergirem (serve de gate)

NÃO ESCREVE NO ROTEADOR. Empurrar config é decisão separada, com risco próprio
(uma linha errada de rede tranca você fora) e exige commit-confirm — ver o item
do TODO em docs/open-items.md.

⚠️ REDAÇÃO DE SEGREDO É FAIL-SAFE, e a direção importa: redige por DEFAULT tudo
que o nome sugere ser credencial, e só libera o que reconhece como público. Um
segredo novo que apareça num pacote futuro nasce redigido sem ninguém lembrar —
o contrário (lista de bloqueio) vazaria em silêncio. Regra 12: o repo não guarda
credencial, nem por acidente.
"""

import subprocess
import sys
from pathlib import Path

HOST = "v1cferr@192.168.1.1"
MARCA = "<REDIGIDO — valor real no roteador; ver docs/history/>"

# Nome da opção (folha) que carrega credencial. `key` genérico entra porque é o
# nome que o wireless usa pra senha do WiFi.
SUSPEITAS = {
    "private_key",
    "preshared_key",
    "password",
    "passwd",
    "psk",
    "secret",
    "token",
    "key",
}

# Exceções verificadas UMA a UMA, com o motivo — sem isso a lista viraria fé:
#   public_key  → é público por definição (peers do WireGuard)
# O outro caso comum, `uhttpd.main.key` e `luci.flash_keep.passwd`, NÃO precisa de
# exceção nominal: os dois valem um CAMINHO de arquivo, e caminho não é segredo.
# Por isso o teste de "começa com /" abaixo — ele generaliza pra opções futuras.
PUBLICAS = {"public_key"}


def raiz_do_repo():
    """MESMO idioma do scripts/sync-secrets.sh. `__file__` NÃO serve: o script é
    copiado pro /nix/store, então o caminho relativo a ele aponta pra dentro da
    store (que é read-only) em vez do repo. Já mordeu na primeira execução."""
    r = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True
    )
    if r.returncode != 0:
        print("rode de dentro do repo (git rev-parse falhou).", file=sys.stderr)
        sys.exit(2)
    return Path(r.stdout.strip())


def uci_configs():
    """Nomes dos arquivos em /etc/config, sem os backups que a gente mesmo criou."""
    out = ssh("ls /etc/config/")
    return sorted(c for c in out.split() if c and ".bak" not in c and "-bak" not in c)


def ssh(cmd):
    r = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", HOST, cmd],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        print(f"ssh falhou: {r.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    return r.stdout


def redigir(linha):
    """`config.secao.opcao='valor'` → redige o valor quando a opção cheira a segredo."""
    if "=" not in linha:
        return linha
    opcao, valor = linha.split("=", 1)
    folha = opcao.rsplit(".", 1)[-1]
    if folha in PUBLICAS or folha not in SUSPEITAS:
        return linha
    # Caminho de arquivo não é segredo — é ponteiro. Cobre uhttpd.main.key e afins.
    if valor.strip("'\"").startswith("/"):
        return linha
    return f"{opcao}='{MARCA}'"


def exportar():
    """{nome do config: texto redigido}. `uci show` e não `uci export`: a saída é
    uma linha por opção, então o diff do git aponta a LINHA que mudou em vez do
    bloco inteiro."""
    saida = {}
    for cfg in uci_configs():
        bruto = ssh(f"sudo uci show {cfg} 2>/dev/null || true")
        linhas = [redigir(x) for x in bruto.splitlines() if x.strip()]
        if linhas:
            saida[cfg] = "\n".join(linhas) + "\n"
    return saida


def main():
    acao = sys.argv[1] if len(sys.argv) > 1 else "diff"
    raiz = raiz_do_repo() / "router" / "uci"
    vivo = exportar()

    if acao == "pull":
        raiz.mkdir(parents=True, exist_ok=True)
        for antigo in raiz.glob("*.conf"):
            if antigo.stem not in vivo:
                antigo.unlink()
                print(f"  removido  {antigo.name} (não existe mais no roteador)")
        for cfg, texto in sorted(vivo.items()):
            destino = raiz / f"{cfg}.conf"
            antes = destino.read_text() if destino.exists() else None
            if antes != texto:
                destino.write_text(texto)
                print(f"  {'atualizado' if antes else 'novo':<10} {cfg}.conf")
        print(f"\n{len(vivo)} configs em {raiz}")
        return 0

    if acao == "diff":
        divergiu = False
        for cfg, texto in sorted(vivo.items()):
            destino = raiz / f"{cfg}.conf"
            if not destino.exists():
                print(f"  SÓ NO ROTEADOR  {cfg}")
                divergiu = True
            elif destino.read_text() != texto:
                print(f"  DIVERGE         {cfg}")
                divergiu = True
        for antigo in sorted(raiz.glob("*.conf")) if raiz.exists() else []:
            if antigo.stem not in vivo:
                print(f"  SÓ NO REPO      {antigo.stem}")
                divergiu = True
        if divergiu:
            print("\nrodar `router-sync pull` pra trazer o estado do roteador.")
            return 1
        print("roteador e repo em sincronia.")
        return 0

    print(f"uso: router-sync [pull|diff]  (recebido: {acao})", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
