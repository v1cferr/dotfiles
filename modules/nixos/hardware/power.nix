# POWER PROFILES: power-profiles-daemon owns the CPU's energy preference (Balanced/Gaming/Eco).
# Why ppd, the profile map, GameMode's hold and the rollback: docs/notes/hardware/power.md
{ ... }:

{
  # The one owner of intel_pstate's EPP, over D-Bus behind polkit (the active session may switch).
  services.power-profiles-daemon.enable = true;
}
