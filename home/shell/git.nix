# CONFIG do git (~/.gitconfig), declarado. O binário `git` vem do system/
# (systemPackages). Aqui é só a identidade/preferências. Preencha abaixo (deixei
# comentado pra não chutar — seus commits usam dev.victorferreira@gmail.com).
{ pkgs, lib, ... }:

{
  # O plugin `github` do Claude Code fala com o MCP remoto (api.githubcopilot.com) e lê
  # o token SÓ da env GITHUB_PERSONAL_ACCESS_TOKEN — sem ela o header sai `Bearer ` vazio
  # e o server responde HTTP 400. Reaproveita o token que o gh já guarda, em vez de gerar
  # um PAT novo e deixar em texto puro. O gh só lê GH_TOKEN/GITHUB_TOKEN, então esse nome
  # NÃO sequestra o `gh auth status/refresh`. `|| true` = máquina sem gh logado não quebra.
  programs.zsh.initContent = lib.mkOrder 1000 ''
    export GITHUB_PERSONAL_ACCESS_TOKEN="$(${pkgs.gh}/bin/gh auth token 2>/dev/null || true)"
  '';

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Victor Ferreira";
        email = "dev.victorferreira@gmail.com";
      };
      # GitHub via HTTPS usa o token do gh (GitHub CLI) como credential helper →
      # `git push/pull` funcionam sem SSH e sem gravar token em texto puro.
      credential."https://github.com".helper = "!gh auth git-credential";
      # `git pull` rebaseia commits locais em cima do remoto (histórico linear; acaba
      # com o prompt "divergent branches"). Repo pessoal single-author = rebase é limpo.
      pull.rebase = true;
    };
  };
}
