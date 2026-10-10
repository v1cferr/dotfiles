# CRYPTO: Stack Wallet (self-custody) and Bisq 2 (P2P buying), launched by hand, no service or port.
# Threat model, backups, why each Tor is the app's own, the first purchase: docs/notes/apps/crypto.md
{ pkgs, ... }:

{
  home.packages = [
    pkgs.stack-wallet # ./pkgs: the official AppImage, pinned to the sha256 upstream publishes
    pkgs.unstable.bisq2 # nixpkgs verifies upstream's GPG signature; stable lags 3 releases behind
  ];
}
