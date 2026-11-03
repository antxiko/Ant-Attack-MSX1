"""Inspect the user's Ant Attack v1 .z80 without changing the original."""
from pathlib import Path
from struct import unpack_from

SNAPSHOT = Path(__file__).resolve().parents[1] / "JUEBOS" / "Ant_Attack_1983_Quicksilva.z80"


def unpack_rle(data: bytes, expected: int) -> bytes:
    result = bytearray()
    pos = 0
    while pos < len(data) and len(result) < expected:
        if data[pos:pos + 2] == b"\xed\xed":
            count, value = data[pos + 2:pos + 4]
            if count == 0:
                break
            result.extend(bytes((value,)) * count)
            pos += 4
        else:
            result.append(data[pos])
            pos += 1
    if len(result) != expected:
        raise ValueError(f"Snapshot RAM: expected {expected}, got {len(result)}")
    return bytes(result)


def load_snapshot(path: Path = SNAPSHOT) -> tuple[bytes, dict[str, int]]:
    data = path.read_bytes()
    pc = unpack_from("<H", data, 6)[0]
    if pc == 0:
        raise ValueError("This extractor expects a version 1 .z80 snapshot")
    ram = unpack_rle(data[30:], 0xC000) if data[12] & 0x20 else data[30:30 + 0xC000]
    memory = bytes(0x4000) + ram
    return memory, {"pc": pc, "sp": unpack_from("<H", data, 8)[0],
                    "im": data[29] & 3, "i": data[10]}


if __name__ == "__main__":
    from skoolkit.basic import BasicLister
    memory, registers = load_snapshot()
    print("Snapshot:", registers)
    print("Game entry 8000:", memory[0x8000:0x8010].hex(" "))
    print("Basic:")
    for line in BasicLister().list_basic(list(memory)).splitlines():
        try:
            number = int(line.split()[0])
        except (IndexError, ValueError):
            continue
        if number <= 230 or 700 <= number <= 870 or 1000 <= number <= 1100:
            print(line)
