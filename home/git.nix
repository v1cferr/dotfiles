# CONFIG do git (~/.gitconfig), declarado. O binário `git` vem do system/
# (systemPackages). Aqui é só a identidade/preferências. Preencha abaixo (deixei
# comentado pra não chutar — seus commits usam dev.victorferreira@gmail.com).
{ ... }:

{
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
    };
  };
}
