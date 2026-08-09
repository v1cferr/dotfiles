# ═══════════════════════════════════════════════════════════════════════════
# CURVA DE BRILHO POR HORÁRIO — backlight REAL, via DDC/CI.
#
# Irmão do ./hyprsunset.nix: aquele cuida da COR, este da LUMINÂNCIA. A divisão
# importa porque a literatura de ergonomia inverte a intuição — reduzir brilho vem
# ANTES de temperatura de cor, e modo noturno não substitui brilho adequado.
#
# O ACHADO QUE MOTIVOU (08/08/2026): `ddcutil getvcp 10` devolveu **100** às 20h,
# num quarto escuro. O monitor passava o dia inteiro no talo. Nenhuma curva de
# Kelvin salva isso — a luz emitida era o problema, e o `gamma` do hyprsunset NÃO
# a reduz: ele escurece o SINAL, o backlight segue igual.
#
# ⚠️ SÓ FUNCIONA NO DP-2. Medido: o LG ULTRAGEAR (DisplayPort) responde MCCS
# (VCP 2.1); a LG TV no HDMI diz "does not support DDC/CI — I2C slave address x37
# is unresponsive". A TV tem barramento i2c, ela é que não fala o protocolo. Pra
# ela, o gamma do hyprsunset segue sendo o único recurso.
#
# COMPORTAMENTO DE OVERRIDE, igual ao hyprsunset: ajuste manual (`ddcutil setvcp
# 10 N`) VALE até o próximo degrau da curva. O serviço só escreve quando o alvo
# MUDA — sem isso ele desfaria seu ajuste a cada 5 min, e escrever DDC à toa é
# lento e faz o monitor piscar.
#
# CALIBRAR: os valores abaixo são ponto de partida, não verdade. O critério da
# literatura é comparar com uma folha de papel branco ao lado da tela — se a tela
# parece mais clara que o papel, está alta demais. Ajuste os degraus da noite
# primeiro, que é onde dói.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  # Espelha a estrutura do hyprsunset de propósito: mesma leitura, mesmo lugar
  # mental. Horário em "HHMM" pra comparação numérica direta no shell.
  curva = [
    {
      hora = "0000";
      valor = 25;
    } # madrugada: mínimo confortável
    {
      hora = "0700";
      valor = 60;
    } # amanhecer
    {
      hora = "0800";
      valor = 90;
    } # dia: quarto claro, tela precisa competir
    {
      hora = "1730";
      valor = 70;
    } # começa a cair junto com a temperatura
    {
      hora = "1800";
      valor = 55;
    } # CHEGADA DO TRABALHO — maior degrau, como no hyprsunset
    {
      hora = "1900";
      valor = 45;
    }
    {
      hora = "2000";
      valor = 40;
    }
    {
      hora = "2200";
      valor = 32;
    } # pré-sono
    {
      hora = "2330";
      valor = 28;
    }
  ];

  # `--model` e não `--display N`: o número é atribuído por ordem de descoberta e
  # muda se outro monitor DDC entrar; o modelo é estável.
  script = pkgs.writeShellApplication {
    name = "brightness-curve";
    runtimeInputs = with pkgs; [ ddcutil ];
    text = ''
      MODELO="LG ULTRAGEAR"
      ESTADO="''${XDG_RUNTIME_DIR:-/tmp}/brightness-curve.last"
      agora=$(date +%H%M)

      # Último degrau cujo horário já passou. A lista está em ordem crescente, e
      # 0000 garante que a madrugada sempre casa — não existe "nenhum degrau".
      alvo=""
      ${builtins.concatStringsSep "\n" (
        map (p: ''[ "$agora" -ge ${p.hora} ] && alvo=${toString p.valor}'') curva
      )}

      anterior=$(cat "$ESTADO" 2>/dev/null || echo "")
      if [ "$alvo" = "$anterior" ]; then
        exit 0  # curva não mudou: preserva ajuste manual e não escreve à toa
      fi

      if ddcutil --model "$MODELO" setvcp 10 "$alvo" 2>/dev/null; then
        echo "$alvo" > "$ESTADO"
        echo "<5>brilho: $alvo%"   # <5>=notice, sobrevive ao LogLevelMax da unit
      else
        # Monitor desligado/desconectado é NORMAL, não falha: sai 0 pra não sujar
        # o status da unit, mas registra em <4>=warning pra aparecer no journal.
        echo "<4>brilho: ddcutil não respondeu (monitor desligado?), alvo era $alvo%" >&2
      fi
    '';
  };
in
{
  systemd.user.services.brightness-curve = {
    Unit.Description = "Aplica a curva de brilho do horário (DDC/CI)";
    Service = {
      Type = "oneshot";
      ExecStart = "${script}/bin/brightness-curve";
      # Deixa passar o <5> da mudança e corta o "Starting…/Finished…" do systemd,
      # senão 1×/5min viraria ruído puro. Mesmo truque do sunshine-healthcheck.
      LogLevelMax = "notice";
    };
  };

  systemd.user.timers.brightness-curve = {
    Unit.Description = "Reavalia a curva de brilho a cada 5 min";
    Timer = {
      # 30s após o login: o monitor precisa estar acordado pro DDC responder.
      OnStartupSec = "30s";
      OnUnitActiveSec = "5min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
