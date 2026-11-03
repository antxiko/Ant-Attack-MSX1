# Ant Attack for MSX1

*(También disponible [en castellano](README.es.md).)*

An unofficial conversion of *Ant Attack* (Quicksilva, 1983) from ZX Spectrum
to a 64 KB ASCII16 cartridge for an MSX1 with 64 KB of RAM.

**Website:** https://antxiko.github.io/Ant-Attack-MSX1/

It retains the original game engine and adds an MSX layer for SCREEN 2,
keyboard input, menus and PSG sound. The isometric renderer keeps a tile
shadow and only sends changed cells to the VDP. It also adds a redesigned HUD,
rotational or directional controls, key redefinition, camera tracking and PSG
adaptations of the original tunes and effects.

## Applying the patch

Install Python 3, Pillow, SkoolKit and Pasmo. Put your own snapshot at:

`JUEBOS/Ant_Attack_1983_Quicksilva.z80`

Its SHA-256 must be
`aad0783b2fe3274be1aaeb3587e26187cf61a2c62a3cd997618a427d9932f1cd`.

```powershell
python -m pip install -r requirements.txt
python tools\normalize.py
python tools\make_ips.py apply build\Ant_Attack_MSX1_base.rom patch\Ant_Attack_MSX1.ips build\Ant_Attack_MSX1.rom
```

The 65,536-byte result must have SHA-256
`0cd4bb3ac868d4374925cd78a0fcade65bf9167d8d9099ef263b12bb4db54b1a`.
The IPS targets the normalised base rather than the compressed `.z80`, so it
contains the conversion changes rather than a complete copy of the game.

The reference disassembly is in
[`disassembly/ant_attack_zx.asm`](disassembly/ant_attack_zx.asm). Patch sources
are included and `python tools\build.py` reproduces the same ROM.

## Status

Araubi completed the game manually. Automated openMSX tests cover camera,
controls, damage, rescues, levels, HUD, timer and PSG register sequences on a
Philips VG-8020. This does not certify real-hardware operation or exact audible
equivalence with the Spectrum beeper.

See the [legal notice and credits](AVISO-LEGAL.md).

