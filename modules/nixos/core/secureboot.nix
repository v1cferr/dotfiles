# SECURE BOOT: our own keys through sbctl. Limine signs its own binary on every install
# (limine.nix); boot-trust.nix proves it did. The runbook: docs/notes/boot-and-storage/boot.md
{ pkgs, ... }:

{
  # The tool for the runbook above (create-keys / enroll-keys / status / verify).
  environment.systemPackages = [ pkgs.sbctl ];
}
