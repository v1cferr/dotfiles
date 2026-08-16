# azure-mcp

Module: [`pkgs/azure-mcp.nix`](../../pkgs/azure-mcp.nix)

Microsoft's Azure MCP Server (`azmcp`), which is what lets Claude Code TOUCH portal.azure.com by
command (resource group, storage, keyvault, monitor, RBAC and so on) instead of clicking through
the interface.

## Why it is vendored here

It is NOT in nixpkgs (checked on 14/08/2026, stable and unstable). And the recipe Microsoft
publishes is `npx -y @azure/mcp@latest server start`, which rule 13 forbids: an implicit "latest"
plus a fetch with no hash ON EVERY START of the MCP, which means the server could change version
in the middle of a session. Here the binary is FIXED.

## Why a binary and not a build from source

npm's `@azure/mcp` is only a JS shim that picks, in the postinstall, one of the six
`@azure/mcp-<os>-<arch>` packages. What has the real server is the platform package, and inside it
comes ONE self-contained 150 MB .NET binary (AOT, `dist/azmcp`), with no JS to run and no C#
source in the tarball. So we fetch the platform tarball directly and skip node entirely: no
`nodejs` in the closure, and `npx` drops out of the picture.

## Why LD_LIBRARY_PATH and not RPATH, which would be the right thing in Nix

The app is single-file and it UNPACKS the .NET native libs into `~/.net/azmcp/<hash>/` on the
first start (`libpal_azure_c_shared_openssl3.so` is there, you can check). It is that extracted
`.so`, outside the store and with no RUNPATH of ours, that dlopens libssl, so
`runtimeDependencies` (which only touches the RPATH of the store binary) does NOT reach it.

Tried and rejected in this order, with each one's error:

| Attempt | Result |
| --- | --- |
| nothing | `Couldn't find a valid ICU package` |
| icu plus openssl in `runtimeDependencies` | ICU passes, then `No usable version of libssl was found` plus a core dump |
| LD_LIBRARY_PATH in the wrapper | works: the extracted libs inherit it |

## The dependencies, all measured against the binary

Not copied from a tutorial.

- **icu, openssl, libstdc++**: the .NET runtime. Without them the binary does not even start.
- **libsecret and dbus**: the pair that is NOT obvious, and the one that decides whether you can
  log in at all. `azmcp` tries the whole DefaultAzureCredential chain and the last link,
  DeviceCodeCredential (the "open login.microsoft.com/device and type ABC123" one), does a
  "persistence check" on the MSAL token cache BEFORE issuing the code. That check is libsecret
  talking to the Secret Service over D-Bus, this machine's gnome-keyring. Without them the error
  is `Persistence check failed`, with no hint at all that the problem is a missing library, and
  the ONLY way out left in the chain would be installing azure-cli: 1.19 GiB of closure to do the
  same login. With them, the cost is ~0, since both are already on the system through
  Plasma/keyring.

The `msalruntime`/libX11 that show up in the error log do NOT matter: that is the WAM broker,
which only exists on Windows, and the chain steps right over it.

## Bumping the version

Change `version` and the hashes of BOTH architectures. The hashes come ready from the registry,
in the SRI format `fetchurl` accepts:

```sh
curl -sL https://registry.npmjs.org/@azure/mcp-linux-x64/latest \
  | jq -r '.version, .dist.integrity'
```

Same thing swapping `-x64` for `-arm64`. npm's `latest` today is a BETA, which is the channel
Microsoft publishes, not a choice of ours.
