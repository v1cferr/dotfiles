# The fans: the GPU's and the board's, under one interface.
# What this card actually does, and when the kernel patch leaves: docs/notes/hardware/fans.md
{ config, lib, ... }:

{
  # THE SWITCH for the kernel patch below, set per host. Off = the binary cache's kernel in minutes
  # and the card back on its own stock curve (zero RPM included); on = manual GPU fan, an hour per bump.
  options.my.fans.gpuControl = lib.mkEnableOption "manual GPU fan control through a patched `xe`";

  # WITHOUT THIS THE GPU HAS NO FAN CONTROL AT ALL. Karthik Poosa's "Add fan control support"
  # for `drm/xe/hwmon` adds `pwm1`, `pwm1_enable` and a ten point curve, and programs them over
  # the PCODE mailbox. The series is in review and NOT in mainline, so it costs a local kernel
  # build on every bump, with no binary cache, which is about an hour on this machine.
  #
  # THIS IS v2 (9 patches, 17/07/2026), taken from the intel-xe list itself. The file that was
  # here before came from a third party, was named after the patchwork series, and turned out to
  # be v1 (5 patches, 07/06/2026): verified by diffing it against both revisions, 561 of 562
  # lines matching v1. v2 is what is under review, and it adds suspend/resume preservation of the
  # user table plus a late binding refresh that v1 never had.
  #
  # It is here because the card answered a question nobody had published an answer to: the series
  # is reported working on an Arc Pro B60 (`8086:e211`), and this is a consumer B580
  # (`8086:e20b`). MEASURED on 14/10/2026 with v1: the fan sat at 0 RPM, took the command, and
  # held 3926 RPM while the package temperature fell from 35 C to 31 C.
  #
  # REMOVE when the series reaches the channel's kernel. That is the only thing that makes the
  # local build unnecessary, and the attributes appearing without the patch is the signal.
  config.boot.kernelPatches = lib.mkIf config.my.fans.gpuControl [
    {
      name = "xe-fan-control";
      patch = ../../../pkgs/xe-fan-control/fan-control-v2.patch;
    }
  ];

  # The board's Super I/O chip, a Nuvoton NCT6798D at 0x2e. The kernel ships the driver but
  # autoloads nothing for it, which is why `sensors` saw no motherboard fan at all before this
  # line: not an absent sensor, an unbound one. It binds with no ACPI resource conflict on this
  # board, so none of the usual `acpi_enforce_resources=lax` advice applies here.
  config.boot.kernelModules = [ "nct6775" ];

  # ONE interface for all three fans, which is the point: CoolerControl speaks plain hwmon, so
  # the GPU's new `pwm1` and the board's two headers are the same kind of thing to it. LACT was
  # the earlier pick and covers the GPU alone, which stopped making sense the moment the board
  # turned out to have controllable headers of its own.
  #
  # NO CURVE IS DECLARED HERE, on purpose. A curve is app state: CoolerControl owns its own
  # config, and writing it from the closure would take the GUI's edits away from it.
  config.programs.coolercontrol.enable = true;
}
