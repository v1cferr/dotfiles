# curseforge-fix-java — devolve o bit +x à JRE que o CurseForge baixa. É o conserto de um
# BUG DO APP, não de uma peculiaridade do NixOS: em distro nenhuma esse Java abriria.
#
# O QUE ACONTECE (medido em 15/08/2026, agent 1.316.0-37372): o app baixa a JRE dele
# (`OpenJDK21U-jre_x64_linux_hotspot_21.0.4_7.tar.gz`) e extrai com um extrator .NET que
# NÃO preserva permissão. Os 6 binários de `bin/` e as 37 `.so` saem `rw-r--r--`, então o
# primeiro `java -version` morre em `Permission denied` (System.ComponentModel.Win32Exception
# no log do agent) e o app conclui, na cara do usuário, "Java Runtime Environment is missing
# or out of date" — mensagem que aponta pro lado errado e faz perder horas procurando Java.
#
# ⚠️ E ELE NÃO SE CURA SOZINHO: ao tentar rebaixar a JRE pra consertar, a extração falha em
# `The file '…/Jre_21/NOTICE' already exists.` — o extrator também não sobrescreve. Ou seja,
# o "Retry" da interface roda pra sempre sem sair do lugar. Sem este script o app fica
# preso, e o único sintoma visível continua sendo "falta Java".
#
# POR QUE NÃO RESOLVER COM JAVA DECLARATIVO (a tentativa óbvia, e ERRADA): pôr `java` no
# PATH do FHS não adianta — o app só consulta a JRE que ele gerencia. Com três JRE
# instalados o log do agent seguiu citando 18× o java DELE e ZERO vez o nosso. Por isso
# pkgs/curseforge.nix não tem Java nenhum, e este script existe.
#
# ONDE RODA: na activation do home-manager (home/apps/curseforge.nix), a cada rebuild — e
# na mão, quando o app baixar uma JRE nova no meio de uma sessão. É idempotente: sem
# arquivo pra corrigir, não escreve nada e não fala nada.
{
  writeShellApplication,
  findutils,
  coreutils,
}:

writeShellApplication {
  name = "curseforge-fix-java";
  runtimeInputs = [
    findutils
    coreutils
  ];

  # set -euo pipefail já vem do writeShellApplication (bashOptions padrão).
  text = ''
    # Caminho por ARGUMENTO com default, pra ficar testável sem tocar no diretório real.
    raiz="''${1:-$HOME/Documents/curseforge/minecraft/Install/java}"

    # Silêncio quando o app ainda não baixou JRE nenhuma: isto roda em TODA activation, e
    # avisar sobre a ausência normal viraria ruído que ninguém mais lê.
    [ -d "$raiz" ] || exit 0

    # `bin/*` é o que trava de fato (o `java`); jspawnhelper/jexec são executados pela
    # própria JVM. As `.so` entram porque o tar original as traz 755 — restaurar o que o
    # extrator perdeu é mais defensável do que julgar quais o dlopen aceitaria sem +x.
    mapfile -t quebrados < <(
      find "$raiz" -type f \( -path '*/bin/*' -o -name '*.so' -o -name jspawnhelper -o -name jexec \) \
        ! -perm -u+x
    )

    [ ''${#quebrados[@]} -gt 0 ] || exit 0

    chmod +x "''${quebrados[@]}"
    echo "curseforge-fix-java: +x em ''${#quebrados[@]} arquivo(s) sob $raiz"
  '';

  meta = {
    description = "Restaura o bit +x na JRE que o CurseForge baixa (o extrator dele o perde)";
    mainProgram = "curseforge-fix-java";
  };
}
