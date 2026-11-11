"""Builds RiftBattlegrounds.rbxlx (a Roblox place file) straight from src/.

Mirrors default.project.json without needing Rojo:
  src/shared  -> ReplicatedStorage.Shared                       (Folder)
  src/server  -> ServerScriptService.Server                     (Script, init.server.luau)
  src/client  -> StarterPlayer.StarterPlayerScripts.Client      (LocalScript, init.client.luau)
Folders become Folders, *.luau files become ModuleScripts, and a folder with
init.server/init.client/init.luau becomes that script with its siblings as
children (same rules as Rojo).

    python3 roblox/tools/build_place.py [output.rbxlx]
"""

from __future__ import annotations

import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "src")


class Builder:
    def __init__(self):
        self.next_ref = 0
        self.lines: list[str] = []

    def ref(self) -> str:
        self.next_ref += 1
        return f"RBX{self.next_ref:08X}"

    def open_item(self, cls: str, name: str, source: str | None = None, extra: str = ""):
        self.lines.append(f'<Item class="{cls}" referent="{self.ref()}">')
        self.lines.append("<Properties>")
        self.lines.append(f'<string name="Name">{escape(name)}</string>')
        if source is not None:
            # CDATA cannot contain "]]>", so split it across sections.
            safe = source.replace("]]>", "]]]]><![CDATA[>")
            self.lines.append(f'<ProtectedString name="Source"><![CDATA[{safe}]]></ProtectedString>')
        if extra:
            self.lines.append(extra)
        self.lines.append("</Properties>")

    def close_item(self):
        self.lines.append("</Item>")

    def add_path(self, path: str, name: str):
        """Adds a file or directory following Rojo's conventions."""
        if os.path.isfile(path):
            if path.endswith(".server.luau"):
                cls = "Script"
            elif path.endswith(".client.luau"):
                cls = "LocalScript"
            else:
                cls = "ModuleScript"
            self.open_item(cls, name, read(path))
            self.close_item()
            return

        init = None
        for candidate, cls in (("init.server.luau", "Script"), ("init.client.luau", "LocalScript"), ("init.luau", "ModuleScript")):
            if os.path.exists(os.path.join(path, candidate)):
                init = (candidate, cls)
                break
        if init:
            self.open_item(init[1], name, read(os.path.join(path, init[0])))
        else:
            self.open_item("Folder", name)

        for entry in sorted(os.listdir(path)):
            if init and entry == init[0]:
                continue
            full = os.path.join(path, entry)
            if os.path.isdir(full):
                self.add_path(full, entry)
            elif entry.endswith(".luau"):
                child = entry
                for suffix in (".server.luau", ".client.luau", ".luau"):
                    if child.endswith(suffix):
                        child = child[: -len(suffix)]
                        break
                self.add_path(full, child)
        self.close_item()


def read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


def build() -> str:
    b = Builder()
    b.lines.append('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
                   'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                   'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')

    b.open_item("Workspace", "Workspace")
    b.close_item()

    # 12-player servers (the published server size is set on the Creator
    # Dashboard -> Places -> Server Size; this matches it for Studio tests).
    b.open_item("Players", "Players", extra='<int name="MaxPlayers">12</int><int name="PreferredPlayers">12</int>')
    b.close_item()

    b.open_item("ReplicatedStorage", "ReplicatedStorage")
    b.add_path(os.path.join(SRC, "shared"), "Shared")
    b.close_item()

    b.open_item("ServerScriptService", "ServerScriptService")
    b.add_path(os.path.join(SRC, "server"), "Server")
    b.close_item()

    # GameSettingsAvatar 1 = R15 (the fighting animations are authored for R15;
    # R6 avatars still get a converted version).
    b.open_item("StarterPlayer", "StarterPlayer", extra='<token name="GameSettingsAvatar">1</token>')
    b.open_item("StarterPlayerScripts", "StarterPlayerScripts")
    b.add_path(os.path.join(SRC, "client"), "Client")
    b.close_item()
    b.open_item("StarterCharacterScripts", "StarterCharacterScripts")
    b.close_item()
    b.close_item()

    b.lines.append("</roblox>")
    return "\n".join(b.lines)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "RiftBattlegrounds.rbxlx")
    xml = build()
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"Wrote {out} ({len(xml) // 1024} KB)")


if __name__ == "__main__":
    main()
