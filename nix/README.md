# NixOS — flake do repo

Plano completo e contexto: [`NIXOS-MIGRATION.md`](../NIXOS-MIGRATION.md) na raiz.

## Estrutura

```text
flake.nix          # porta de entrada (raiz do repo)
nix/
├── hosts/         # um .nix por máquina (staging → depois desktop/Kingston)
├── modules/       # sistema: base, desktop; futuras traduções dos deploy.sh
└── home/          # home-manager (consome os dirs stow do repo)
```

## Pré-requisito (uma vez, no Arch)

```sh
sudo pacman -S nix
sudo systemctl enable --now nix-daemon.socket
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
```

(Não existe mais grupo `nix-users` no pacote do Arch — o acesso é via socket do
daemon, liberado por padrão. O grupo `nixbld` é interno, dos builders.)

## Uso

**REGRA DE OURO: flakes só enxergam arquivos rastreados pelo git.**
Criou/renomeou arquivo → `git add` antes de qualquer build.

```sh
# Bootar a config como VM (iteração diária — segundos, nada instalado)
nix build .#nixosConfigurations.staging.config.system.build.vm
./result/bin/run-nixos-staging-vm
# login: v1cferr / nixos

# home-manager standalone no Arch (fase de aprendizado)
nix run github:nix-community/home-manager -- switch --flake .#v1cferr@arch
home-manager switch --flake .#v1cferr@arch   # das próximas vezes

# Atualizar os pins (manutenção)
nix flake update && git add flake.lock

# Validar sem construir
nix flake check
```

## Fase bare metal (quando o NVMe novo chegar)

1. Escrever o layout disko em `nix/hosts/` (particionamento declarativo);
2. Boot no ISO do NixOS → `disko` → `nixos-install --flake .#staging`;
3. Validar NVIDIA/dual-monitor/NetExtender → cutover no Kingston (host `desktop`).

## Notas

- A VM roda sem GPU real: rice lento/glitchado ali é esperado (llvmpipe), não é bug de config.
- `system.stateVersion`/`home.stateVersion` NUNCA mudam depois da primeira instalação.
- Segredos: sops-nix entra antes de qualquer serviço com credencial (nunca rastrear segredo em claro — vai pra /nix/store legível).
