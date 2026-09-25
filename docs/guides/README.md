# guides

Step by step for **what Nix cannot reach**, plus the reusable TEST protocols. A page lands here
when the thing it describes lives on firmware, on somebody else's machine, or behind a web UI, so
declaring it is not an option and the only defense is that redoing it is written down.

## How it relates to the rest of docs/

| Folder | Question it answers |
| --- | --- |
| [`../notes/`](../notes/) | "Why is THIS module like this?" The reasoning behind what IS declared |
| `guides/` (here) | "What do I type to redo this by hand?" Steps outside Nix's reach |
| [`../history/`](../history/) | "What happened on that day?" Chronological, append-only |

A guide is NOT a diary entry: it describes the procedure as it stands today, so rule 16 applies
in full and a guide that stopped working is a bug.

## The pages

| Guide | What you would come here asking |
| --- | --- |
| [bios-ex-b560m-v5](bios-ex-b560m-v5.md) | the board's desired BIOS state, which no `fwupd` here can read or write |
| [disaster-recovery](disaster-recovery.md) | the three drills that prove this repo still rebuilds the machine |
| [router-hardening](router-hardening.md) | the audit of the one public-facing box Nix does not reach |
| [fai-gateway-router](fai-gateway-router.md) | the half of the FAI gateway that lives on the router |
| [per-client-dns-block](per-client-dns-block.md) | blocking a domain for ONE machine, across its dual boot |
| [wireguard-moonlight](wireguard-moonlight.md) | the tunnel MTU and Moonlight test, and why it cannot run from home |
| [cesar-windows-manual-steps](cesar-windows-manual-steps.md) | what has to exist INSIDE my brother's Windows |
| [context-exports](context-exports.md) | getting each provider's export onto disk for the context repository, one web UI at a time |
