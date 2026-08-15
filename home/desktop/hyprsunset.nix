# Filtro de luz azul do ecossistema Hyprland (hyprsunset). Age via CTM no compositor
# (hyprland-ctm-control-v1), então NÃO aparece em screenshot/gravação — importante
# porque uso o Flameshot direto. Docs: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/
#
# ⚠️ CORREÇÃO (08/08/2026): este bloco dizia que a escolha foi "no lugar de
# gammastep/wlsunset porque não é shader". O argumento estava torto — gammastep e
# wlsunset TAMBÉM não usam shader. Quem usa é o hyprshade, e é contra ELE que o wiki
# do Hyprland recomenda o hyprsunset ("preferred to screen shaders as it will not be
# captured via recording/screenshots"). O motivo real de preferir aos outros dois é
# ser nativo do protocolo do Hyprland, não a questão do shader.
#
# ⚠️ OS 13 PERFIS NÃO SÃO EXCESSO. Verificado no código do hyprsunset 0.3.3: ZERO
# ocorrências de transition/interpolate/gradual, e a issue "Graduated transition"
# segue ABERTA. Ele salta seco no horário de cada perfil. Degrau pequeno e frequente
# é a ÚNICA forma de obter curva suave numa ferramenta que só sabe saltar — se um dia
# ele interpolar, isto colapsa pra 3 perfis (ver docs/ideas.md).
#
# O módulo services.hyprsunset sobe um SERVIÇO systemd --user (dispensa exec-once)
# e gera ~/.config/hypr/hyprsunset.conf a partir de `settings`. Os `profile` trocam
# a temperatura por horário do relógio sozinhos; os keybinds F9 (home/hypr.nix) são
# só override manual pontual via `hyprctl hyprsunset`.
# Kelvin: 6500=dia neutro · 4000=noite · 3000=noite avançada · 2000=madrugada.
#
# A NOITE É AGRESSIVA DE PROPÓSITO (06/08/2026, reescrita do schedule herdado do
# Arch): trabalho o dia inteiro em OUTRO PC sem filtro, então quando chego às 18h
# o olho já vem castigado e não dá pra tratar 18h como "início de noite leve". O
# schedule antigo só descia de 500 em 500K e chegava em 5500K às 18h — perto do
# neutro, ou seja, alívio real só às 22h, 4h depois de chegar.
#
# SEGUNDA DESCIDA (13/08/2026): a de 06/08 ainda parecia fraca, e esta tira mais
# ~200–400K de cada degrau pós-18h. O maior degrau segue sendo o das 18h (5000→3800)
# e às 19h já está em 3200K — onde a curva anterior só chegava às 20h.
# ⚠️ ESCOLHIDO O EIXO DA COR, e isso CONTRARIA o que docs/ideas.md registra como
# prioridade (reduzir BRILHO vem antes de temperatura de cor). Foi deliberado: o
# dim automático por gamma já existiu e foi REVERTIDO em 08/08 junto com o DDC, e
# trazê-lo de volta às 18h é mudança maior que baixar Kelvin. Se esta curva não
# bastar, o PRÓXIMO passo é gamma progressivo a partir das 18h — NÃO continuar
# descendo Kelvin, que daqui pra baixo só piora a cor sem alívio proporcional.
#
# ⚠️ A CURVA ATRAVESSA OS ~3200K DE PROPÓSITO, e isso muda o contrato do escape
# hatch: abaixo disso a cor fica visivelmente laranja e ESTRAGA filme/jogo/foto —
# das 19h em diante esse é o estado NORMAL, não a exceção. SUPER+SHIFT+F9
# (`hyprctl hyprsunset identity` = filtro OFF) deixa de ser recurso raro e vira o
# gesto de sempre que abrir mídia à noite; o próximo perfil do relógio retoma a
# curva sozinho. Se atrapalhar demais, o ajuste é subir SÓ o degrau das 18h/18:30
# — não achatar a curva inteira.
{ ... }:

{
  services.hyprsunset = {
    enable = true;
    settings = {
      max-gamma = 150; # teto do gamma em % (default 100); folga p/ ajuste via IPC

      # Perfis por horário (transição suave ao longo do dia). identity = filtro OFF.
      #
      # `gamma` = brilho PERCEBIDO (1.0 = normal; <1 escurece), e é o único dimming
      # automático que alcança AS DUAS telas — por isso ele voltou em 08/08/2026,
      # depois de uma tentativa de usar backlight real que foi REVERTIDA.
      #
      # A TENTATIVA E O PORQUÊ DA REVERSÃO: o DP-2 aceita DDC/CI e ganhou curva de
      # backlight de verdade (bem melhor que gamma, que escurece o SINAL com a luz
      # de fundo no talo). Só que a LG TV do HDMI NÃO fala DDC/CI, não está na rede
      # (nada de webOS) e CEC não cobre brilho — não há caminho automático pra ela.
      # Uma tela a 32% ao lado de outra a 100% obriga a pupila a se readaptar toda
      # vez que o olhar troca, e isso cansa mais do que o ganho na tela boa.
      # Decisão: dimming pior nas duas > dimming ótimo em uma. Detalhes e a medição
      # que motivou tudo (o monitor estava em 100% às 20h) em docs/history/2026/.
      #
      # Auto-dim SÓ de noite: dia e início de noite em brilho cheio (pode estar
      # trabalhando); das 22h em diante escurece até 0.8 (piso) e volta de manhã.
      # ⚠️ Perfil SEM gamma volta a 1.0 — cada perfil zera o que os outros setaram.
      profile = [
        {
          time = "0:00";
          temperature = 2000;
          gamma = 0.8;
        } # madrugada: quente + escuro
        {
          time = "6:00";
          temperature = 3000;
          gamma = 0.9;
        } # amanhecer: esfria + clareia
        {
          time = "7:00";
          temperature = 4000;
          gamma = 1.0;
        } # manhã: brilho normal de volta
        {
          time = "8:00";
          identity = true;
        } # dia (8h–17h30): neutro, sem filtro, brilho cheio
        {
          time = "17:30";
          temperature = 5000;
        } # fim de tarde: 1º aquecimento (sem dim ainda)
        {
          time = "18:00";
          temperature = 3800;
        } # CHEGADA DO TRABALHO: maior degrau da curva, é aqui que o alívio começa
        {
          time = "18:30";
          temperature = 3500;
        }
        {
          time = "19:00";
          temperature = 3200;
        } # ⚠️ daqui pra baixo a cor estraga mídia — ver o cabeçalho
        {
          time = "20:00";
          temperature = 3000;
        }
        {
          time = "21:00";
          temperature = 2800;
        }
        {
          time = "22:00";
          temperature = 2600;
          gamma = 0.9;
        } # pré-sono: reduz azul + dim leve
        {
          time = "23:00";
          temperature = 2400;
          gamma = 0.85;
        }
        {
          time = "23:30";
          temperature = 2200;
          gamma = 0.8;
        } # transição final p/ a madrugada
      ];
    };
  };
}
