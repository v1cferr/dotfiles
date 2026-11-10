# Installing the t480s: one command from the desk, and what stays manual

The laptop is declared in `hosts/t480s/` ([decision 0018](../decisions/0018-a-shared-laptop.md)).
Installing it is one destructive command run from the desk, plus the few steps that live in the
firmware or in a person's head, which Nix cannot reach (rule 3).

## Before

1. In the BIOS (F1 at power on): Secure Boot **disabled**. Limine signs itself with keys that
   are not enrolled yet, so an enforcing firmware would refuse it.
2. Boot the NixOS minimal ISO (F12 for the boot menu) and get it on the network. A cable is
   better than Wi-Fi: the install copies the whole system across.
3. On the laptop, authorize the desk's key for the installer's `nixos` user, since the ISO has
   no password to log in with:

   ```bash
   mkdir -p ~/.ssh && curl -L https://github.com/v1cferr.keys > ~/.ssh/authorized_keys
   ```

   This runs ON THE LAPTOP. Run on the desk it replaces the desk's own `authorized_keys` and
   lets every key on that GitHub account in, which happened on 10/11/2026.

## The install

From the repo root, on the desk:

```bash
nix run .#t480s-install -- nixos@<the laptop's address>
```

It asks, each typed twice and never shown:

- the disk's LUKS passphrase, which is typed at every boot from then on;
- one login password per account that the host declares with a `hashedPasswordFile`.

Then nixos-anywhere partitions the disk with `hosts/t480s/disko.nix`, **erasing everything on
it**, builds the system on the desk, copies it over and reboots. The password hashes land in
`/var/lib/login-passwords/`, readable by root only; nothing typed here reaches git or the store.

**The passphrase and the keyboard.** The prompt at boot may not use the layout the passphrase was
typed with on the desk. Until that prompt has been seen working, keep the passphrase to lowercase
letters, digits and spaces, which sit on the same keys in every layout this house uses.

## After the first boot

- Clone this repo on the laptop at the SAME path as on the desk,
  `~/Projects/GitHub/v1cferr/dotfiles`: Hyprland's and Quickshell's configs are live links into
  the checkout, and without it the session comes up with no config (10/11/2026).
- From then on the laptop applies what the desk committed with `pull-rebuild`, and a local edit
  with `rebuild`; from the desk it is `ssh t480s`. Version bumps (`update`, `upgrade`) stay on
  the desk, so the two machines never race on `flake.lock`.
- Each person changes their own password with `passwd`. The files in `/var/lib/login-passwords/`
  only seeded the accounts.
- Cesar's home is his: standalone Home Manager from his repository, with no `sudo`. The first
  run, before the `home-manager` command exists, is
  `nix run home-manager/release-26.05 -- switch --flake <his repository>`.

## What is NOT done yet

- **Secure Boot.** The keys exist in `/var/lib/sbctl` but are not enrolled. The runbook is the
  desk's, in [boot](../notes/boot-and-storage/boot.md).
- **Unlocking by TPM.** The disk asks for its passphrase at every boot. `systemd-cryptenroll` can
  seal a second key in the TPM, which only means something once Secure Boot is enforced.
- **My home on one screen.** `modules/home/` arrives whole, with the desk's two monitors and its
  desk-only services ([open items](../open-items.md)).
