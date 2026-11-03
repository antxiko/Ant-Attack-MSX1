"""Create or apply an IPS patch without external dependencies."""
from pathlib import Path
import argparse


def create(old: bytes, new: bytes) -> bytes:
    out = bytearray(b"PATCH")
    i = 0
    limit = max(len(old), len(new))
    old = old.ljust(limit, b"\0")
    new = new.ljust(limit, b"\0")
    while i < limit:
        if old[i] == new[i]:
            i += 1
            continue
        start = i
        while i < limit and old[i] != new[i] and i - start < 0xFFFF:
            i += 1
        block = new[start:i]
        out.extend(start.to_bytes(3, "big"))
        out.extend(len(block).to_bytes(2, "big"))
        out.extend(block)
    out.extend(b"EOF")
    if len(new) != len(old):
        out.extend(len(new).to_bytes(3, "big"))
    return bytes(out)


def apply(old: bytes, patch: bytes) -> bytes:
    if not patch.startswith(b"PATCH"):
        raise ValueError("No es un parche IPS")
    out = bytearray(old)
    p = 5
    while patch[p:p + 3] != b"EOF":
        offset = int.from_bytes(patch[p:p + 3], "big")
        size = int.from_bytes(patch[p + 3:p + 5], "big")
        p += 5
        if size:
            data = patch[p:p + size]
            p += size
        else:
            run = int.from_bytes(patch[p:p + 2], "big")
            data = patch[p + 2:p + 3] * run
            p += 3
        if len(out) < offset + len(data):
            out.extend(bytes(offset + len(data) - len(out)))
        out[offset:offset + len(data)] = data
    p += 3
    if len(patch) >= p + 3:
        del out[int.from_bytes(patch[p:p + 3], "big"):]
    return bytes(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=("create", "apply"))
    ap.add_argument("source", type=Path)
    ap.add_argument("patch", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    if args.mode == "create":
        args.output.write_bytes(create(args.source.read_bytes(), args.patch.read_bytes()))
    else:
        args.output.write_bytes(apply(args.source.read_bytes(), args.patch.read_bytes()))


if __name__ == "__main__":
    main()

