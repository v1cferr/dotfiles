# Desktop: Hyprland + greetd + áudio. Tradução gradual do rice do Arch.
# O greeter quickshell real (greetd/) será portado depois; por ora autologin.
{ pkgs, ... }:

{
  programs.hyprland.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      # Autologin direto no Hyprland (só p/ fase VM/staging)
      initial_session = {
        command = "Hyprland";
        user = "v1cferr";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      };
    };
  };

  # Bluetooth (capacidade é declarada; PAREAMENTO é estado, vive em /var/lib/bluetooth)
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # Super+B chama blueman-manager

  # Áudio (PipeWire, como no Arch)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # O rice vai pedindo pacotes conforme os exec-once/binds falharem na VM —
  # adicionar aqui é exatamente o processo de adaptação.
  environment.systemPackages = with pkgs; [
    kitty
    rofi
    quickshell
    hyprlock
    hypridle
    hyprsunset
    cliphist
    wl-clipboard
    playerctl
    brightnessctl
  ];
}
