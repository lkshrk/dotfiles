#!/usr/bin/env python3
"""Feeds Discord's hidden stream-thumbnail <video> only video tracks; its audio echoes and leaks outputs (Vesktop#1355)."""
import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import sys
import tempfile

ASAR = "/usr/lib/equibop/resources/app.asar"
RENDERER = ("dist", "js", "renderer.js")
INSTALLED = "/usr/local/lib/dotfiles/equibop-preview-video-only.py"
HOOK_PATH = "/etc/pacman.d/hooks/equibop-preview-video-only.hook"
STALE = (
    "/usr/local/lib/dotfiles/equibop-mute-stream-preview.py",
    "/etc/pacman.d/hooks/equibop-mute-stream-preview.hook",
)

PATCH_BODY = (
    r'Vencord.Plugins.addPatch({find:"ApplicationStreamPreviewUploadManager",replacement:['
    r'{match:/(\i)\.srcObject=(\i),\1\.play\(\)(?=;let \i=\i\.getContext\("2d"\))/,'
    r'replace:"$1.muted=!0,$1.srcObject=new MediaStream($2.getVideoTracks()),$1.play()"},'
    r'{match:/(\i)\.removeAttribute\("srcObject"\)/,replace:"$1.srcObject=null"}'
    r']},"Equibop","VesktopPatchGlobals")'
)
MARKER = f"/*dotfiles:equibop-preview-video-only:{hashlib.sha256(PATCH_BODY.encode()).hexdigest()[:8]}*/"
ANY_PATCH = re.compile(
    r',/\*dotfiles:(?:mute-stream-preview|equibop-preview-video-only)(?::\w+)?\*/'
    r'Vencord\.Plugins\.addPatch\(.*?,"Equibop","VesktopPatchGlobals"\)'
)
ANCHOR = "window.VesktopPatchGlobals={}"

HOOK = f"""[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = equibop-bin

[Action]
Description = Keeping Equibop's stream thumbnails video-only (Vesktop#1355)
When = PostTransaction
Exec = /usr/bin/python3 -I {INSTALLED} patch
"""

OK, NEEDED, UNPATCHABLE = 0, 1, 2


class Asar:
    def __init__(self, path):
        self.path = path
        with open(path, "rb") as f:
            self.data = f.read()
        pickle_size, json_size = struct.unpack_from("<I", self.data, 4)[0], struct.unpack_from("<I", self.data, 12)[0]
        self.header = json.loads(self.data[16 : 16 + json_size])
        self.base = 8 + pickle_size

    def entry(self, parts):
        node = self.header
        for part in parts:
            node = node["files"][part]
        return node

    def read(self, parts):
        node = self.entry(parts)
        start = self.base + int(node["offset"])
        return self.data[start : start + node["size"]]

    def write(self, parts, blob):
        node = self.entry(parts)
        offset, size = int(node["offset"]), node["size"]
        for other in self._files(self.header):
            if int(other.get("offset", -1)) > offset:
                other["offset"] = str(int(other["offset"]) + len(blob) - size)
        block = node.get("integrity", {}).get("blockSize", 4 * 1024 * 1024)
        node["size"] = len(blob)
        node["integrity"] = {
            "algorithm": "SHA256",
            "hash": hashlib.sha256(blob).hexdigest(),
            "blockSize": block,
            "blocks": [hashlib.sha256(blob[i : i + block]).hexdigest() for i in range(0, max(len(blob), 1), block)],
        }
        start = self.base + offset
        body = self.data[self.base : start] + blob + self.data[start + size :]
        raw = json.dumps(self.header, separators=(",", ":")).encode()
        pad = b"\0" * (-len(raw) % 4)
        inner = struct.pack("<II", 4 + len(raw) + len(pad), len(raw)) + raw + pad
        atomic_write(self.path, struct.pack("<II", 4, len(inner)) + inner + body, os.stat(self.path).st_mode)

    def _files(self, node):
        for child in node.get("files", {}).values():
            yield from self._files(child) if "files" in child else (child,)


def atomic_write(path, blob, mode):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=f".{os.path.basename(path)}.")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(blob)
        os.chmod(tmp, mode & 0o7777)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def renderer_state(asar):
    js = asar.read(RENDERER).decode()
    if MARKER in js:
        return OK, js
    clean = ANY_PATCH.sub("", js)
    return (NEEDED if clean.count(ANCHOR) == 1 else UNPATCHABLE), clean


def same_file(a, b):
    try:
        with open(a, "rb") as x, open(b, "rb") as y:
            return x.read() == y.read()
    except FileNotFoundError:
        return False


def hook_current():
    try:
        with open(HOOK_PATH) as f:
            return f.read() == HOOK
    except FileNotFoundError:
        return False


def cmd_check(args):
    state, _ = renderer_state(Asar(args.asar))
    if state == UNPATCHABLE:
        print("equibop: renderer.js changed shape; thumbnail patch can't be applied", file=sys.stderr)
        return UNPATCHABLE
    installed = same_file(__file__, INSTALLED) and hook_current() and not any(map(os.path.exists, STALE))
    return OK if state == OK and installed else NEEDED


def cmd_patch(args):
    asar = Asar(args.asar)
    state, clean = renderer_state(asar)
    if state == UNPATCHABLE:
        print(f"equibop: {ANCHOR} not found once in renderer.js; not patching", file=sys.stderr)
        return UNPATCHABLE
    if state == NEEDED:
        asar.write(RENDERER, clean.replace(ANCHOR, f"{ANCHOR},{MARKER}{PATCH_BODY}", 1).encode())
        print("equibop: stream thumbnails are video-only now")
    return OK


def cmd_install(args):
    os.makedirs(os.path.dirname(INSTALLED), exist_ok=True)
    shutil.copyfile(__file__, INSTALLED + ".tmp")
    os.chmod(INSTALLED + ".tmp", 0o644)
    os.replace(INSTALLED + ".tmp", INSTALLED)
    atomic_write(HOOK_PATH, HOOK.encode(), 0o644)
    for path in STALE:
        if os.path.exists(path):
            os.unlink(path)
    return cmd_patch(args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name, func, help_text in (
        ("check", cmd_check, "exit 0 when patched and installed, 1 when work is needed, 2 when unpatchable"),
        ("patch", cmd_patch, "patch app.asar in place"),
        ("install", cmd_install, "as root: install this script and the pacman hook, then patch"),
    ):
        p = sub.add_parser(name, help=help_text)
        p.add_argument("asar", nargs="?", default=ASAR)
        p.set_defaults(func=func)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
