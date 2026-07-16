# CONFIG do git (~/.gitconfig), declarado. O binário `git` vem do system/
# (systemPackages). Aqui é só a identidade/preferências. Preencha abaixo (deixei
# comentado pra não chutar — seus commits usam dev.victorferreira@gmail.com).
{ ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = "Victor Ferreira";
      email = "dev.victorferreira@gmail.com";
    };
  };
}
