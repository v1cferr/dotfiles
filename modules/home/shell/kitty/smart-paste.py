"""smart-paste: an IMAGE in the clipboard is pasted as a FILE PATH, on the remote side when the
window is running ssh. Why, and the traps: docs/notes/desktop/desktop-plumbing.md"""

import os
import subprocess

from kittens.tui.handler import result_handler
from kitty.clipboard import get_clipboard_string

# The ssh flags that swallow the NEXT argument, so their value is never read as the host. The
# test is the LAST letter, which is what tells `-p 22` (a value follows) from `-p22` (attached).
VALUE_FLAGS = "BbcDEeFIiJLlmOoPpQRSWw"


def main(args: list[str]) -> None:
    """Never runs, since the handler is no_ui, and kitty refuses a kitten that lacks it."""


def clipboard_has_image() -> bool:
    """Whether the clipboard OFFERS an image, which costs a mime listing and no data."""
    try:
        listing = subprocess.run(
            ["wl-paste", "--list-types"],
            capture_output=True,
            text=True,
            timeout=1,
            check=False,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return False  # no wl-paste, or a clipboard owner that hung: fall back to a plain paste
    return any(line.startswith("image/") for line in listing.splitlines())


def ssh_host(window) -> str:
    """The host the window's ssh is talking to, empty when what runs there is local."""
    for process in window.child.foreground_processes:
        cmdline = process.get("cmdline") or []
        if not cmdline or os.path.basename(cmdline[0]) != "ssh":
            continue
        skip = False
        for arg in cmdline[1:]:
            if skip:
                skip = False
            elif arg.startswith("-"):
                skip = arg[-1] in VALUE_FLAGS
            else:
                return arg  # the first non-flag argument is the destination
    return ""


def paste_clipboard(window) -> None:
    """kitty's own paste_from_clipboard, aimed at the window the key was pressed in instead of at
    whatever happens to be active, which is not the same window once a transfer has taken 2 s."""
    if window.send_paste_event():
        return
    text = get_clipboard_string()
    if text:
        window.paste_with_actions(text)


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    if not clipboard_has_image():
        paste_clipboard(window)  # everything that is not an image is kitty's paste, untouched
        return

    # clipboard-push leaves the path IN THE CLIPBOARD, so the success path is the same paste as
    # above: what changed by then is what the clipboard holds.
    def pasted(wait_status: int, err: Exception | None) -> None:
        target = boss.window_id_map.get(target_window_id)  # it may have closed in the meantime
        if target is not None and err is None and os.waitstatus_to_exitcode(wait_status) == 0:
            paste_clipboard(target)

    destination = ssh_host(window) or "local"
    pid = os.posix_spawnp("clipboard-push", ["clipboard-push", destination], os.environ)
    boss.monitor_pid(pid, pasted)
