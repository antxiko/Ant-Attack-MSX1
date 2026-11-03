"""Create the deterministic 64 KiB base image expected by the IPS patch."""
from pathlib import Path
import hashlib

from inspect_ant import load_snapshot

ROOT = Path(__file__).resolve().parents[1]
SNAP = ROOT / "JUEBOS" / "Ant_Attack_1983_Quicksilva.z80"
OUT = ROOT / "build" / "Ant_Attack_MSX1_base.rom"
SHA256 = "aad0783b2fe3274be1aaeb3587e26187cf61a2c62a3cd997618a427d9932f1cd"


def main() -> None:
    if hashlib.sha256(SNAP.read_bytes()).hexdigest() != SHA256:
        raise ValueError("El snapshot no es la revision esperada")
    memory, _ = load_snapshot(SNAP)
    # Banco de arranque vacío seguido por la imagen RAM original de 48 KiB.
    base = bytes(0x4000) + memory[0x4000:]
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_bytes(base)
    print(f"{OUT} ({len(base)} bytes)")


if __name__ == "__main__":
    main()

