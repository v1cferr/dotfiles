# curseforge-bump — deixa o CurseForge na última versão, sem editar pkgs/curseforge.nix
# à mão. Irmão do vscode-bump, e existe pelo MESMO motivo estrutural: um src com hash
# travado nunca se atualiza sozinho — o que existe é BUMP AUTOMATIZADO.
#
# A diferença pro vscode-bump: lá dava pra usar URL versionada e o bump só troca o
# número. Aqui NÃO existe URL versionada (a Overwolf publica só
# `curseforge-latest-linux.AppImage`), então o hash é a única âncora — e ele precisa ser
# RECALCULADO, não só trocado. Sem isso, a próxima release da Overwolf quebra o
# `nix build .#curseforge` em qualquer store fria (o arquivo por trás da URL mudou).
#
# ONDE RODA: no alias `update`/`upgrade` (home/shell/zsh.nix), junto do vscode-bump.
#
# POR QUE O .deb DECIDE SE MUDOU: baixar 139 MiB a cada `update` só pra descobrir que
# nada mudou seria absurdo, e não há API de versão. O `.deb` da MESMA release entrega a
# versão no `control`, que fica nos primeiros KiB do arquivo — então um range request de
# 256 KiB responde "mudou?" por ~0,2% do custo. O AppImage só é baixado quando a resposta
# é sim. Medido em 14/08/2026: os dois artefatos são publicados no mesmo instante e
# carregam a mesma release (`1.316.0~37372-37372` no .deb, `1.316.0-37372.37372` no
# X-AppImage-Version) — as strings só diferem em formatação, daí a normalização abaixo.
# Se um dia dessincronizarem, o pior caso é baixar o AppImage à toa: o script compara e
# reescreve, não quebra.
#
# PEGADINHAS (as mesmas do vscode-bump):
#   • O caminho do repo vem por ARGUMENTO, nunca literal aqui (regra 11).
#   • O `nix` NÃO entra em runtimeInputs: usa o do sistema, pra não arrastar um segundo
#     Nix na store com versão possivelmente divergente do daemon.
#   • Deixa o repo SUJO de propósito — o commit é do usuário, atômico (regra 13).
#   • É NO-OP quando já está na última, porque roda em todo `upgrade`.
{
  writeShellApplication,
  curl,
  gnused,
  gnutar,
  xz,
  binutils,
}:

writeShellApplication {
  name = "curseforge-bump";
  runtimeInputs = [
    curl
    gnused
    gnutar
    xz # o control.tar.xz do .deb; o GNU tar autodetecta a compressão, mas precisa do binário
    binutils # `ar` — o .deb é um archive ar
  ];

  # set -euo pipefail já vem do writeShellApplication (bashOptions padrão).
  text = ''
    repo="''${1:?uso: curseforge-bump <caminho-do-repo-do-flake>}"
    nix_file="$repo/pkgs/curseforge.nix"
    base="https://curseforge.overwolf.com/downloads"

    # Versão TRAVADA hoje: o pkgs/curseforge.nix é a SSOT dela.
    atual=$(sed -n 's|^  version = "\(.*\)";$|\1|p' "$nix_file")
    if [ -z "$atual" ]; then
      echo "curseforge-bump: não achei o \`version\` em $nix_file" >&2
      echo "                 (o pacote mudou de forma? conferir pkgs/curseforge.nix)" >&2
      exit 1
    fi

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # SÓ o começo do .deb: o `control` mora antes do `data.tar.*`, que é o volume todo.
    curl -fsSL -r 0-262143 -o "$tmp/head.deb" "$base/curseforge-latest-linux.deb"
    membro=$(ar t "$tmp/head.deb" | sed -n '/^control\.tar/p' | head -1)
    if [ -z "$membro" ]; then
      echo "curseforge-bump: o .deb não tem control.tar* nos primeiros 256 KiB" >&2
      exit 1
    fi
    # Passa por ARQUIVO e não por pipe de propósito: o GNU tar só autodetecta a
    # compressão quando pode dar seek, então `ar p … | tar -xO` morre em "Archive is
    # compressed. Use -J option" (medido). Em arquivo ele resolve sozinho — o que também
    # deixa o script sobreviver ao dia em que a Overwolf trocar o .xz por .zst.
    ar p "$tmp/head.deb" "$membro" > "$tmp/control.tar"
    # `1.316.0~37372-37372` → `1.316.0-37372`: o `~` vira `-` e o build repetido no fim sai.
    latest=$(tar -xOf "$tmp/control.tar" ./control |
      sed -n 's|^Version: \(.*\)$|\1|p' | sed 's|~|-|; s|-[0-9]*$||')
    case "$latest" in
      *[!0-9.-]* | "")
        echo "curseforge-bump: o .deb devolveu uma versão implausível: '$latest'" >&2
        exit 1
        ;;
    esac

    if [ "$atual" = "$latest" ]; then
      echo "curseforge-bump: já na última ($atual)."
      exit 0
    fi

    echo "curseforge-bump: $atual → $latest (baixando o AppImage pro hash…)"
    curl -fsSL -o "$tmp/cf.AppImage" "$base/curseforge-latest-linux.AppImage"
    novo_hash=$(nix hash file --type sha256 --sri "$tmp/cf.AppImage")

    # Um `version` e um `hash` no arquivo; casa o padrão genérico e não o valor atual
    # interpolado (cujos pontos virariam curinga de regex).
    sed -i \
      -e "s|^  version = \".*\";$|  version = \"$latest\";|" \
      -e "s|hash = \"sha256-[^\"]*\";|hash = \"$novo_hash\";|" \
      "$nix_file"

    echo "curseforge-bump: pronto. Commit sugerido:"
    echo "  git -C \"$repo\" commit -am 'chore(curseforge): $atual → $latest'"
  '';

  meta = {
    description = "Bump de version+hash do pkgs/curseforge.nix para a última release da Overwolf";
    mainProgram = "curseforge-bump";
  };
}
