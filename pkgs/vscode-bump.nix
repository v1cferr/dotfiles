# vscode-bump — deixa o VS Code na ÚLTIMA versão stable, sem editar o flake.nix à mão.
#
# POR QUE EXISTE: o input `vscode-tarball` (flake.nix) aponta pra uma URL VERSIONADA de
# propósito — `/1.132.0/linux-x64/stable` e não `/latest/`. O motivo está escrito lá e é
# estrutural: `/latest/` é PONTEIRO, então a cada release do VS Code o narHash travado no
# lock deixa de casar e o flake não avalia mais em máquina limpa (CI, clone novo). Ou
# seja, "input que se atualiza sozinho" não existe com hash travado — o que existe é
# BUMP AUTOMATIZADO, e é isto. O preço da URL fixa (uma edição manual por release) deixa
# de ser pago pela pessoa: quem consulta a API oficial e reescreve o número é o script.
#
# ONDE RODA: nos aliases `update`/`upgrade` (home/shell/zsh.nix), ANTES do `nix flake
# update`. É por isso que "sempre latest" funciona sem `git pull` e sem bot commitando na
# branch: o momento em que a versão importa é o do rebuild.
#
# PEGADINHAS:
#   • O caminho do repo vem por ARGUMENTO, nunca literal aqui (regra 11): a SSOT é
#     `programs.nh.flake`, e quem a lê é o zsh.nix via `osConfig`.
#   • O `nix` NÃO entra em runtimeInputs de propósito — usar o do sistema (o
#     writeShellApplication só PREFIXA o PATH) evita um segundo Nix na store, cuja
#     versão poderia divergir do daemon.
#   • Deixa o repo SUJO (flake.nix + flake.lock modificados) e isso é intencional: o
#     commit é do usuário, atômico, como qualquer bump (regra 13 — o lock entra no mesmo
#     commit da mudança que o exigiu).
#   • É NO-OP quando já está na última, porque roda em todo `upgrade`.
{
  writeShellApplication,
  curl,
  jq,
  gnused,
}:

writeShellApplication {
  name = "vscode-bump";
  runtimeInputs = [
    curl
    jq
    gnused
  ];

  # set -euo pipefail já vem do writeShellApplication (bashOptions padrão).
  text = ''
    repo="''${1:?uso: vscode-bump <caminho-do-repo-do-flake>}"
    nix_file="$repo/flake.nix"

    # Versão TRAVADA hoje: lida do próprio flake.nix, que é a SSOT da versão do VS Code.
    atual=$(sed -n \
      's|.*update\.code\.visualstudio\.com/\([0-9][0-9.]*\)/linux-x64/stable.*|\1|p' \
      "$nix_file")
    if [ -z "$atual" ]; then
      echo "vscode-bump: não achei a URL versionada do vscode-tarball em $nix_file" >&2
      echo "             (o input mudou de forma? conferir flake.nix)" >&2
      exit 1
    fi

    # Versão SERVIDA agora pelo canal stable. `productVersion` e não `version` — o
    # segundo é o hash do commit ("df53daa…"), não o 1.132.0 que vai na URL.
    latest=$(curl -fsSL \
      https://update.code.visualstudio.com/api/update/linux-x64/stable/latest |
      jq -r '.productVersion')
    case "$latest" in
      *[!0-9.]* | "")
        echo "vscode-bump: a API devolveu uma versão implausível: '$latest'" >&2
        exit 1
        ;;
    esac

    if [ "$atual" = "$latest" ]; then
      echo "vscode-bump: já na última ($atual)."
      exit 0
    fi

    echo "vscode-bump: $atual → $latest"
    # Reescreve só o número, casando o padrão genérico (e não o "$atual" interpolado,
    # cujos pontos virariam curinga de regex).
    sed -i \
      "s|\(update\.code\.visualstudio\.com/\)[0-9.]*\(/linux-x64/stable\)|\1$latest\2|" \
      "$nix_file"

    # Sem isto o flake.nix e o lock ficariam discordando até a próxima avaliação: é este
    # comando que baixa o tarball novo e grava o narHash dele.
    nix flake update vscode-tarball --flake "$repo"

    echo "vscode-bump: pronto. Commit sugerido:"
    echo "  git -C \"$repo\" commit -am 'chore(vscode): $atual → $latest'"
  '';

  meta = {
    description = "Bump do input vscode-tarball para a última versão stable do VS Code";
    mainProgram = "vscode-bump";
  };
}
