# The Control Center: the everyday switches, in one panel

`modules/home/desktop/quickshell/control/`, opened from the bar's right side or with SUPER+A. One
panel for what changes during a day: the network, Bluetooth, the VPN, do-not-disturb, the playing
track and the sound. Before 12/11/2026 each of these was its own item on the bar with its own
popover, or had no control at all (the volume was a scroll and a mute, Bluetooth a key that opened
Blueman).

It owns no state. Every tile reads and sets the service that does, so the panel, the bar and the
OSD can never disagree.

## What it holds, and what stays in the NixOS Center

| Control Center (changes during a day)   | NixOS Center (operation and history)                        |
| --------------------------------------- | ----------------------------------------------------------- |
| Network, Bluetooth, VPN, Focus          | The notification history                                    |
| Now playing                             | Status cards: weather, temperatures, memory, disk           |
| The volume, the outputs, the microphone | The power profile and the memory behind it                  |
|                                         | Boot trust, screenshots, the session, idle, the away screen |

Do-not-disturb is in both, since it belongs to both subjects, and has one owner (`Notifs.qml`). A
row at the foot of the Control Center opens the NixOS Center.

## The parts

| Part      | Reads and sets                                                                                            |
| --------- | --------------------------------------------------------------------------------------------------------- |
| Network   | `Quickshell.Networking` and the bar's link state; its tile opens the Network page                         |
| Bluetooth | `Quickshell.Bluetooth`: the adapter's switch and the connected devices; its tile opens the Bluetooth page |
| VPN       | the `vpn` CLI through the bar's `runVpn`; its tile opens the VPN page                                     |
| Focus     | `Notifs.dnd`                                                                                              |
| Media     | `Media.qml`: the cover, the track, previous, play or pause, next                                          |
| Sound     | `Audio.qml`: the volume and the mute; its chevron opens the Sound page                                    |

A tile is a round icon that is the switch, a name, and what it is now. A click on the icon flips
it; a click anywhere else on a tile that has a page opens the page in place, with a way back. A
tile whose hardware is not there (no Bluetooth adapter) stays, faded, and says so; the VPN tile is
absent on a host that has no `vpn` command at all.

## The building blocks

Three widgets came with it, since the shell had no slider and no switch:

- `widgets/Slider.qml`: a tall rounded track with its icon inside the left end. A drag or a click
  sets the level, the wheel moves it 5%, a tap on the icon is the mute. A press that starts on the
  icon sets nothing until the pointer travels 4 px, so a mute never zeroes the volume. With the
  keyboard, Left and Right set the level and Up and Down walk the panel.
- `widgets/ControlTile.qml`: the tile above.
- `control/PageHeader.qml` and `control/PageLink.qml`: a page's way back, and the quiet row that
  leaves for a fuller tool.

`widgets/IconButton.qml` learned the bar's rule: a Material Symbols name draws in the icon font, any
other string is a glyph of the text font.

## Network

The Network page reads NetworkManager through `Quickshell.Networking`, which the shell had never
used: until 12/11/2026 the link was an `nmcli` poll, and there was no way to pick a network. It
lists the wired links (the cable, the connection, the link speed) and, where the machine has a
Wi-Fi device, a switch and up to eight networks: the connected one first, then the saved ones, then
by signal. A click connects a saved or an open network and disconnects the connected one. One that
needs a password opens a field under its row; Enter hands the password to NetworkManager and the
field forgets it. The scan runs only while this page is on screen. The row at the foot opens the
link's own panel, with the rates, the latency and the speed test, which did not move.

## Bluetooth

The Bluetooth page reads BlueZ through `Quickshell.Bluetooth`. `MY DEVICES` are the paired ones,
each with its state (connecting, connected with its battery when the device reports one, not
connected); a click connects or disconnects. `IN RANGE` are devices that are not paired and said
their name; a click pairs, and Blueman answers any prompt, since it stays the pairing agent.
Discovery is switched on when the page opens and off when it closes or the panel does: nothing
scans in the background. `Bluetooth manager` hands over to Blueman.

## Sound

The Sound page lists the outputs and the inputs, the one in use carrying a check; picking one sets
`Pipewire.preferredDefaultAudioSink` or `Source`. Under the inputs, the microphone's level and its
mute; then one slider per app that is playing. Pipewire reports a node's audio only while something
tracks it, so the app streams are tracked only while this page is the one on screen. `Mixer` hands
over to pavucontrol.

## VPN

The `vpn` CLI's JSON says connected or not, nothing else, and its `connect` returns as soon as the
unit starts. The bar now keeps a phase per tunnel on top of it (`vpnPhase` in `Bar.qml`):

| State         | When                                                                                      |
| ------------- | ----------------------------------------------------------------------------------------- |
| Off           | no tunnel and nothing asked                                                               |
| Connecting    | from the command until the tunnel exists                                                  |
| Connected     | the CLI's own test: the unit is active AND the interface is there                         |
| Disconnecting | while the command runs                                                                    |
| Error         | 45 s passed with no tunnel (the CLI's own patience); the text is `vpn diagnose`'s verdict |
| Unknown       | the `vpn` command did not answer                                                          |

A unit that is merely active never reads as connected. No privilege was added: every action is the
CLI's, under the polkit rule that already let the user start the two units. The tile's switch
connects the VPN used last, or takes every tunnel down.

## What it did to the bar

With the Control Center on, what it holds leaves the strip: the network keeps its icon and loses
its numbers, the VPN shows only while it is up or coming up, the sound only while muted, and the
bell goes (do-not-disturb turns the Control Center's own icon into its sign). A scroll on that icon
is the volume. The details: [bar.md](bar.md#the-distribution-12112026).

## Turning it off

`my.shell.controlCenter.enable = false` (`quickshell/flags.nix`) removes the entry point, and the
bar shows its own network, VPN, sound and bell items again. The flag and one host fact, whether
the `vpn` units exist, reach the shell through `~/.config/theme/shell.json`, read by `Theme.qml`
like the palette.

## Checked, and not

**Rendered on 12/11/2026** in a second Quickshell on a copy of the tree inside a headless sway: the
main view, the Sound page against the machine's real Pipewire nodes (six outputs, one input, one
app stream), the VPN page with both tunnels off, the Network page (one wired link, connected at
1 Gb/s), the Bluetooth page (three paired devices, discovery on while open and reported off by
`bluetoothctl show` after it closed), the bar with the flag on and off, and no error in the log.

Not verified, since the harness has no pointer and no keyboard, and its Pipewire and BlueZ are the
live machine's: dragging a slider, picking an output, the Bluetooth switch, connecting a VPN and
its error path, connecting or pairing a Bluetooth device, the keyboard walk, and Escape leaving a
page. The whole Wi-Fi half of the Network page has never run: the desk has no Wi-Fi device, so the
switch, the list, the password field and its failure path wait for the laptop.
