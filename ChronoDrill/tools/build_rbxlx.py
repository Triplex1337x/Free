#!/usr/bin/env python3
"""Собирает папку src/ (структура как в Rojo) в файл плейса .rbxlx для Roblox Studio.

  *.server.lua -> Script, *.client.lua -> LocalScript, *.lua -> ModuleScript, папки -> Folder.
"""
import os
import sys
import itertools
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "ChronoDrill.rbxlx")

_ref = itertools.count(1)


def ref():
    return "RBX%032X" % next(_ref)


def prop_string(name, value):
    return '<string name="%s">%s</string>' % (name, escape(value))


def item(cls, props, children=""):
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (
        cls, ref(), "".join(props), children)


def script_item(path, fname):
    if fname.endswith(".server.lua"):
        cls, name = "Script", fname[: -len(".server.lua")]
    elif fname.endswith(".client.lua"):
        cls, name = "LocalScript", fname[: -len(".client.lua")]
    else:
        cls, name = "ModuleScript", fname[: -len(".lua")]
    with open(os.path.join(path, fname), encoding="utf-8") as f:
        source = f.read()
    assert "]]>" not in source, "CDATA terminator in " + fname
    props = [prop_string("Name", name), '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>' % source]
    if cls != "ModuleScript":
        props.append('<bool name="Disabled">false</bool>')
    return item(cls, props)


def folder_contents(path):
    out = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            out.append(item("Folder", [prop_string("Name", entry)], folder_contents(full)))
        elif entry.endswith(".lua"):
            out.append(script_item(path, entry))
    return "".join(out)


def service(cls, extra_props=(), children=""):
    return item(cls, [prop_string("Name", cls)] + list(extra_props), children)


def main():
    rs = folder_contents(os.path.join(SRC, "ReplicatedStorage"))
    sss = folder_contents(os.path.join(SRC, "ServerScriptService"))
    sps = folder_contents(os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts"))

    parts = [
        service("Workspace", [
            '<bool name="StreamingEnabled">false</bool>',
            '<float name="FallenPartsDestroyHeight">-500</float>',
            '<float name="Gravity">196.2</float>',
        ]),
        service("Lighting", [
            '<token name="Technology">4</token>',
            '<float name="Brightness">2.4</float>',
            '<float name="ClockTime">14.2</float>',
            '<bool name="GlobalShadows">true</bool>',
            '<float name="EnvironmentDiffuseScale">1</float>',
            '<float name="EnvironmentSpecularScale">1</float>',
        ]),
        service("ReplicatedStorage", children=rs),
        service("ServerScriptService", children=sss),
        service("StarterPlayer", [
            '<float name="CharacterWalkSpeed">18</float>',
            '<float name="CameraMaxZoomDistance">80</float>',
        ], children=item("StarterPlayerScripts", [prop_string("Name", "StarterPlayerScripts")], sps)
                    + item("StarterCharacterScripts", [prop_string("Name", "StarterCharacterScripts")])),
        service("StarterGui", ['<bool name="ResetPlayerGuiOnSpawn">false</bool>']),
        service("SoundService"),
        service("Players"),
    ]
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        '<Meta name="ExplicitAutoJoints">true</Meta>'
        '<External>null</External><External>nil</External>'
        + "".join(parts)
        + "</roblox>"
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("written", OUT, len(xml), "bytes")


if __name__ == "__main__":
    main()
