"""zen-lab: a dependency-free Marionette client for the theme lab, in the browser's CHROME context.
Why Marionette and not the DevTools MCP, and the lab's rules: docs/notes/apps/zen.md"""

import base64
import json
import socket
import sys

# It loads ONE extra user sheet at a time, so a new `css` replaces the last instead of stacking.
INJECT = """
const wu = window.windowUtils;
if (window.__zenLabSheet) {
  try { wu.removeSheetUsingURIString(window.__zenLabSheet, wu.USER_SHEET); } catch (e) {}
  window.__zenLabSheet = null;
}
if (arguments[0]) {
  const uri = "data:text/css;charset=utf-8," + encodeURIComponent(arguments[0]);
  wu.loadSheetUsingURIString(uri, wu.USER_SHEET);
  window.__zenLabSheet = uri;
}
return Boolean(window.__zenLabSheet);
"""


class Marionette:
    """One session on the lab's port: `len:json` frames, commands as [0, id, name, params]."""

    def __init__(self, port: int) -> None:
        try:
            self.sock = socket.create_connection(("127.0.0.1", port), timeout=30)
        except ConnectionRefusedError:
            raise SystemExit(f"nothing on port {port}: run `zen-theme-lab start` first") from None
        self.buf = b""
        self.last_id = 0
        self._read()  # the server's hello
        self.cmd("WebDriver:NewSession", {"capabilities": {}})
        self.cmd("Marionette:SetContext", {"value": "chrome"})

    def _read(self) -> list:
        while b":" not in self.buf:
            self.buf += self.sock.recv(65536)
        size, rest = self.buf.split(b":", 1)
        while len(rest) < int(size):
            rest += self.sock.recv(1 << 20)
        self.buf = rest[int(size) :]
        return json.loads(rest[: int(size)])

    def cmd(self, name: str, params: dict | None = None) -> dict:
        self.last_id += 1
        data = json.dumps([0, self.last_id, name, params or {}]).encode()
        self.sock.sendall(str(len(data)).encode() + b":" + data)
        while True:
            msg = self._read()
            if msg[1] == self.last_id:
                if msg[2]:
                    raise SystemExit(f"{name}: {msg[2]}")
                return msg[3]

    def js(self, script: str, *args: str) -> object:
        return self.cmd("WebDriver:ExecuteScript", {"script": script, "args": list(args)}).get("value")


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: lab.py PORT eval JS | css FILE|- | shot OUT.png | quit")
    port, verb, arg = int(sys.argv[1]), sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else "")
    m = Marionette(port)
    if verb == "eval":
        print(json.dumps(m.js(arg), indent=1, ensure_ascii=False))
    elif verb == "css":
        css = sys.stdin.read() if arg in ("", "-") else open(arg, encoding="utf-8").read()
        print("injected" if m.js(INJECT, css) else "cleared")
    elif verb == "shot":
        png = m.cmd("WebDriver:TakeScreenshot", {"full": False})["value"]
        with open(arg, "wb") as out:
            out.write(base64.b64decode(png))
        print(arg)
    elif verb == "quit":
        try:
            m.cmd("Marionette:Quit", {"flags": ["eForceQuit"]})
        except OSError:
            pass  # the browser can close the socket before it answers
    else:
        raise SystemExit(f"unknown verb: {verb}")


if __name__ == "__main__":
    main()
