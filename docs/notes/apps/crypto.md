# Crypto: Stack Wallet and Bisq 2

Module: [`modules/home/apps/crypto.nix`](../../../modules/home/apps/crypto.nix). Package:
[`pkgs/stack-wallet/`](../../../pkgs/stack-wallet/package.nix). Two GUI apps for holding and
buying cryptocurrency myself: no service, no autostart, no open port, nothing that runs until I
open it from the launcher.

**Nix installs the apps and nothing else.** A seed, a private key, a wallet password, an address
or a balance never enters this repo, the Nix store, sops, Bitwarden, Dropbox, a CI artifact or an
AI agent's transcript. Creating the wallet, writing the seed down, buying and sending are done by
me, by hand, every time.

## What each piece does

| Piece | Job | Where it comes from |
| --- | --- | --- |
| Stack Wallet | holds the keys; makes the receiving address; later spends | `pkgs.stack-wallet`, the official AppImage, pinned |
| Bisq 2 (Bisq Easy) | finds a seller and runs the trade chat; it holds NO coins | `pkgs.unstable.bisq2`, from nixpkgs |
| Pix | the BRL leg, paid from my bank app, outside both programs | |
| Bitcoin mainnet | the seller's on-chain transaction to my Stack Wallet address | |

The flow is `BRL/Pix -> Bisq Easy seller -> on-chain BTC -> Stack Wallet`. Bisq Easy has no wallet
of its own: the buyer pastes a receiving address into the trade chat, which is why the two apps
are separate and neither depends on the other.

## Why these two, and what lost

Compared on 10/10/2026 (rule 1).

- **Stack Wallet**: open source (GPL-3.0), maintained (v2.7.1 on 24/08/2026, commits the day
  before this note), and one app for the chains I may pick later: its README lists 23 (Bitcoin,
  Ethereum with tokens, Solana, Monero, Litecoin and more). Keys stay on the device and the node
  is configurable.
- **Bisq 2 / Bisq Easy**: open source, P2P over Tor, no platform KYC, any payment method the two
  sides agree on (so Pix works), and built for exactly the first-time buyer: no security deposit,
  no fee, no BSQ, a limit per trade of 6 to 600 USD equivalent ([Bisq Easy](https://bisq.wiki/Bisq_Easy)).

| Rejected | Why |
| --- | --- |
| Sparrow, Electrum | excellent and in nixpkgs, but Bitcoin only, and the goal covers other chains later. Sparrow is the natural second wallet for a hardware wallet one day |
| Exodus, Trust Wallet desktop | not open source |
| Bisq 1 | security deposits and BSQ fees; meant for larger trades |
| RoboSats, Peach, HodlHodl | Lightning-first, mobile-first, or escrow I would have to learn on top of the first purchase |
| an exchange (Binance, Mercado Bitcoin) | KYC, and the coins sit with a custodian until withdrawn |
| building Stack Wallet from source | Flutter plus about ten native libraries (Monero, Epic Cash, MWC, Firo Spark, Xelis, FROST), each with its own Rust or C++ toolchain; a project of its own |
| Stack Wallet's Flatpak | a second package system next to Nix |
| a third-party Stack Wallet flake | none worth trusting existed, and the AppImage is verifiable directly |

## Installation, verification and upgrades

Both arrive with the normal `rebuild`. The two packages are trusted in different ways, and it is
worth knowing which:

- **Bisq 2** comes from nixpkgs, whose recipe REFUSES to build unless the `.deb` verifies against
  upstream's GPG signature. It also swaps Bisq's bundled Tor binary for nixpkgs' Tor. The keys
  that recipe imports come from the same GitHub release, so on 10/10/2026 I cross-checked the
  signer against the copy on `bisq.network/pubkey/E222AA02.asc` (the one the
  [Bisq 2 wiki](https://bisq.wiki/Bisq_2) says to import): both carry the primary key
  `B493 3191 06CC 3D1F 252E 19CB F806 F422 E222 AA02`, and the release's `signingkey.asc` names
  E222AA02 as its signer. **unstable and not stable**: stable had 2.1.10 and upstream was on
  2.1.13 (MEASURED 10/10/2026), and a trading client should carry the fixes.
- **Stack Wallet** publishes NO signature for the Linux AppImage, only a sha256. The download of
  `sw-v2.7.1-linux.AppImage` hashed to `81e0f7ed…8fbf`, equal to GitHub's asset digest and to the
  line in the release notes (MEASURED 10/10/2026). That proves the file is the one Cypher Stack's
  GitHub account published, no more: a compromised account could publish a matching pair. The
  bump keeps that check on every update (it refuses when the two disagree), see
  [version bumps](../repo/version-bumps.md).

Upgrades: `update` runs `stack-wallet-bump` (a new AppImage only when upstream tags one) and moves
the lock, which moves `unstable.bisq2`. Neither app updates itself in place: they live in the
read-only store.

### What was tested, and what was not

MEASURED on 10/10/2026, with `HOME` pointed at a scratch directory:

- Stack Wallet starts under Hyprland and reaches its create-or-restore screen. The only library
  the AppImage environment lacked was `libepoxy`.
- **Webcam QR scanning does NOT work**: the camera plugin wants OpenCV 4.6 (`.so.406`) and
  nixpkgs ships 4.13. Receiving and pasting an address need no camera.
- Bisq 2 starts, bootstraps its own Tor and publishes its onion service. The JVM ignores `$HOME`
  (it reads the passwd entry), so that test created a fresh `~/.local/share/Bisq2` in the REAL
  home: an unused node identity with no profile, deleted right after.

No wallet was created, no seed was generated, and no transaction was made or tested.

## Where the state lives

All of it is runtime state (rule 6): nothing here is declared.

| Path | What it holds |
| --- | --- |
| `~/.stackwallet/isar/` | the wallets, the seeds included, encrypted with the password I choose at first launch |
| `~/.stackwallet/` (`hive/`, `sqlite/`, `themes/`) | preferences, node list, caches |
| `~/Stack_Logs/` | Stack Wallet's log; may contain addresses and txids. Path and level are in its settings |
| `~/.local/share/Bisq2/` | the Bisq profile (nickname, reputation keys), trade history and chats, its own `backups/` |
| `~/.local/share/Bisq2/bisq.log` | **records the onion service's PRIVATE key** (the `ADD_ONION` line, seen 10/10/2026). Never post it in a bug report unedited |
| `~/.local/share/Bisq2/tor/` | deleted by the nixpkgs launcher on every start |

## Tor: each app brings its own

The system Tor ([`tor.nix`](../../../modules/nixos/network/tor.nix)) is a SOCKS port on
`127.0.0.1:9050` and nothing more. Neither app uses it, on purpose:

- **Bisq 2** must PUBLISH an onion service, which needs a Tor control port. Pointing it at the
  system Tor would mean opening a control port to my user on a root service, a real weakening for
  no gain. Its own Tor is a child process: random localhost ports, alive only while Bisq is open,
  and gone when it closes (MEASURED 10/10/2026, no conflict with 9050). It also binds the onion's
  local target on all interfaces, which the firewall keeps closed.
- **Stack Wallet** has Tor built in (an in-process library), OFF by default. Turned on in its
  settings, it routes the wallet's node traffic. Nothing else on the machine is affected.

Nothing forces the system's traffic through Tor, and nothing should.

## First launch: creating the wallet (by hand)

1. Before anything, in a quiet moment: no screen sharing, no Sunshine stream, no AI agent
   session open on this desk.
2. Open Stack Wallet from the launcher. Choose a STRONG app password: it is what encrypts
   `~/.stackwallet` on a disk that has no LUKS.
3. In settings, turn **Tor ON** before adding a wallet, so the first sync already hides my IP from
   the node.
4. Add a Bitcoin wallet, "create new". Write the words (12 by default; 24 is offered) **on paper,
   by hand, in order**. Never a photo, a screenshot, a text file, the clipboard, a password
   manager or a cloud note.
5. Do the app's word check. Then store the paper away from the computer.
6. Restore drill, FOR FREE: create a second, throwaway wallet on **Bitcoin testnet**, write its
   words, delete it, and restore it from the paper. That proves I can restore before real money is
   at stake. Delete the testnet wallet after.

## Receiving bitcoin

Stack Wallet v2.7.1 hands out **Taproot** addresses (`bc1p…`) by default (BIP86 in the source of
`build_316`). Most wallets send to them, but some still refuse: the desktop receive screen has an
address type selector, and **Native SegWit** (`bc1q…`) is the safe fallback.

- Use a FRESH address for every trade; Stack Wallet generates a new one per receive.
- Copy it with the app's copy button and, after pasting, compare the first and the last 6
  characters on screen. Clipboard hijacking malware swaps exactly this.
- On-chain is public forever: the seller learns this address, and anyone who links it to me can
  follow what it does next.

## Buying with Bisq Easy, BRL by Pix (by hand)

R$ 40 to 100 sits near the BOTTOM of Bisq Easy's 6 USD minimum, so check the offer's minimum in
the app first: below it, no trade is possible. Small amounts also carry a hidden cost: the coins
arrive as one small output that costs a mining fee to spend later.

1. Open Bisq 2, create the profile (a nickname, no real name). A buyer needs no reputation.
2. Bisq Easy, market **BTC/BRL**, filter by payment method **Pix**, settlement **on-chain**
   (not Lightning).
3. For each candidate seller, check:
   - **reputation score** and how it was earned (the [reputation](https://bisq.wiki/Reputation)
     page explains burned and bonded BSQ, account age); higher is safer;
   - **price**: the premium over the market price shown in the offer;
   - **amount range**: does it include my R$ amount;
   - **who pays the mining fee** and the exact BTC I will receive: ask in the chat if unclear.
4. Take the offer. The seller sends the Pix key in the trade chat; I send my Stack Wallet address
   there.
5. Pay by Pix from the bank app, **only to the key the seller sent in the trade chat**, the
   exact amount. Then mark "payment sent" in Bisq.
6. Wait for the seller's on-chain transaction. Stack Wallet shows it as incoming, then confirmed.
   Wait at least one confirmation before calling it done.
7. If something goes wrong (no BTC after a reasonable time, a request to move off-platform), open
   **mediation** from the trade. Never pay twice, never talk outside Bisq.

Pix is NOT anonymous: the seller sees my name and bank, and the bank sees the transfer. Bisq hides
my IP from the seller; Pix does not hide my identity. Bisq Easy has no escrow: once the Pix is
sent, the seller's reputation is all that stands behind the trade.

## Threat model

Written for this machine on 10/10/2026: a desktop at home, no LUKS
([0006](../../decisions/0006-no-disk-encryption.md)), an encrypted local backup
([0011](../../decisions/0011-local-disk-backup.md)), no offsite copy yet
([0008](../../decisions/0008-no-offsite-backup-yet.md)).

| Risk | What it means here | What holds it back |
| --- | --- | --- |
| malware in my session | anything running as `v1cferr` can read `~/.stackwallet`, log keys, swap the clipboard; the `docker` group makes my session root-equivalent anyway | the app password protects the file at rest, NOT a live session. Keep amounts small; a hardware wallet is the real answer |
| theft or loss of the NVMe | no LUKS, so `~` is readable | the wallet store is encrypted by the app password; the seed on paper restores everything on new hardware |
| seed exposure | the seed IS the money | paper only, never digital, never typed into anything but the wallet's restore screen |
| a compromised upstream binary | Stack Wallet has no signature, only a hash from the same account | the hash pins ONE artifact, so a later swap fails the build; the first trust is still upstream's GitHub. Bisq is GPG-verified |
| logs, history, clipboard, screenshots | `~/Stack_Logs` and `bisq.log` hold addresses and keys of the network identity; **cliphist keeps every copied text** in `~/.cache/cliphist`; Flameshot and Sunshine see the screen | never copy a seed; after copying an address, `cliphist wipe` if it bothers me; no screenshots of wallet screens |
| an AI agent's transcript | anything an agent reads or prints stays in its logs | never ask an agent to read wallet files, logs or screenshots of them; this module was written without touching any |
| RPC privacy | by default Stack Wallet asks Cypher Stack's Electrum server (`bitcoin.stackwallet.com`), which sees my IP and all my addresses | Tor ON hides the IP, not the address set. A node of my own is the full fix, later |
| Pix identity | the seller and the bank tie the BTC amount and time to my CPF | accepted; it is the price of buying with BRL. Do not reuse the receiving address |
| publishing wallet metadata | an address, txid or balance in this public repo, in a commit message, in `docs/` | none goes here; `gitleaks` does NOT catch an address, so this is on review |

### Hardening later, as its own plan

Not done here, and not silently: the disk layout changed nowhere.

1. **A hardware wallet** (open source firmware) with Sparrow or Stack Wallet as the watch-only
   front end. The single biggest step: keys leave the computer entirely.
2. **LUKS on the next reinstall**, the moment [0006](../../decisions/0006-no-disk-encryption.md)
   already names for it, with a backup in place first.
3. **My own Bitcoin node and Electrum server**, so no third party learns my addresses.
4. **An offsite copy** of the restic repo, which closes [0008](../../decisions/0008-no-offsite-backup-yet.md).

## Backups and recovery

**The seed on paper is the backup.** Everything else is convenience.

- **What restic already covers.** The daily backup takes all of `~` minus an exclude list
  ([restic](../boot-and-storage/restic.md)), and none of those patterns matches `~/.stackwallet`,
  `~/Stack_Logs` or `~/.local/share/Bisq2` (REASONED from the list on 10/10/2026, not measured:
  the directories did not exist yet). After the first launch, confirm with
  `sudo restic -r /mnt/backup/restic --password-file /run/secrets/restic_password ls latest /home/v1cferr/.stackwallet`.
  The repo is encrypted, so the wallet store sits there encrypted twice.
- **A live database.** Stack Wallet uses Isar on libmdbx (its log says so). A copy taken while it
  writes can be torn. The backup runs at 03:00 and the app is normally closed then; if it is open,
  the snapshot may be useless for that night, and the seed still restores the wallet.
- **Restoring the wallet**: install from this flake, open Stack Wallet, "restore", type the words,
  let it rescan. Labels and the address book are what only a file backup brings back.
- **Restoring Bisq**: the profile, its reputation and trade history are NOT derived from any seed.
  They come back only from restic (`~/.local/share/Bisq2`), or are lost. For a buyer with no
  reputation that loss is small.

### Why no Dropbox or age backup

The task allowed an opt-in `age` export to Dropbox, and it was left out on purpose:

- the seed on paper already IS the offsite copy, and it needs no credential;
- the wallet store is already encrypted by the app, and the backup by restic: a third layer adds a
  third secret to keep alive, which is how people lose access to their own money;
- Dropbox is a third party, and the export would run on the same session malware could read.

If an offsite FILE is ever wanted, Stack Wallet's own encrypted backup (in its settings) is the
upstream path; where it is stored is a decision for that day, not a default here.

## Upstream documentation

- Stack Wallet: <https://github.com/cypherstack/stack_wallet> and its
  [releases](https://github.com/cypherstack/stack_wallet/releases)
- Bisq 2: <https://github.com/bisq-network/bisq2>, [Bisq 2 wiki](https://bisq.wiki/Bisq_2)
- Bisq Easy: [protocol and limits](https://bisq.wiki/Bisq_Easy), [reputation](https://bisq.wiki/Reputation)

## Tested versions

| App | Version | Checked | How |
| --- | --- | --- | --- |
| Stack Wallet | 2.7.1 (`build_316`, commit `f920c36`) | 10/10/2026 | sha256 against digest and notes; launched with a scratch `HOME` |
| Bisq 2 | 2.1.13 (nixpkgs-unstable) | 10/10/2026 | GPG at fetch; signer fingerprint against bisq.network; launched |
