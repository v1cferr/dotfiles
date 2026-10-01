# THE BOOT TEST: it boots the host in QEMU and reads which units actually came up. A PACKAGE and
# not a check on purpose, the gate reason is in docs/notes/repo/vm-boot.md
{
  inputs,
  pkgs,
  commonModules,
}:

pkgs.testers.runNixOSTest {
  name = "vm-boot";
  node.specialArgs = { inherit inputs; };
  # runNixOSTest pins the node's pkgs and makes `nixpkgs.*` READ-ONLY; this config sets
  # both (the overlays here, allowUnfree in modules/nixos/core), so the node builds its own.
  node.pkgsReadOnly = false;
  nodes.machine.imports = commonModules ++ [
    ../hosts/ex-b560m-v5
    ../hosts/ex-b560m-v5/vm-boot.nix
  ];
  testScript =
    let
      # Units that CANNOT come up inside a VM, each with its reason. Empty, and emptying
      # it is the goal: same contract as the other checkers' ALLOWED.
      allowedUnits = [ ];
      # ACTIVATION snippets, which do NOT show up in `systemctl --failed`: the first
      # version of this test passed green while these two had already failed.
      allowedSnippets = [
        # Both need /var/lib/sops-nix/key.txt, which lives OUTSIDE git by design (rule
        # 12). A VM with no key cannot install secrets, and that is the drill's job.
        "setupSecrets"
        "setupSecretsForUsers"
      ];
    in
    ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")

      # The config APPLIED, not just booted: the user, their shell, and the whole
      # home-manager generation having been activated.
      machine.succeed("getent passwd v1cferr | grep -q zsh")
      machine.succeed(
          "systemctl show -p Result --value home-manager-v1cferr.service | grep -qx success"
      )

      out = machine.succeed(
          "systemctl list-units --state=failed --plain --no-legend --no-pager || true"
      )
      failed = [line.split()[0] for line in out.splitlines() if line.strip()]
      print("failed units:", failed)
      unexpected = [u for u in failed if u not in ${builtins.toJSON allowedUnits}]
      assert not unexpected, "unexpected failed units: " + repr(unexpected)

      journal = machine.succeed("journalctl -b -o cat || true")
      snippets = sorted(
          {
              line.split("'")[1]
              for line in journal.splitlines()
              if "Activation script snippet" in line and "failed" in line
          }
      )
      print("failed activation snippets:", snippets)
      unexpected = [s for s in snippets if s not in ${builtins.toJSON allowedSnippets}]
      assert not unexpected, "unexpected activation failures: " + repr(unexpected)
    '';
}
