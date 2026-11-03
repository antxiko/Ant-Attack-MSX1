# Ant Attack para MSX1

*(También disponible [en inglés](README.md).)*

Conversión no oficial de *Ant Attack* (Quicksilva, 1983) desde ZX Spectrum a
un cartucho ASCII16 de 64 KB para MSX1 con 64 KB de RAM.

**Web:** https://antxiko.github.io/Ant-Attack-MSX1/es/

No es una emulación genérica: conserva el motor original y añade una capa MSX
para SCREEN 2, teclado, menús y PSG. El mapa isométrico usa un shadow de tiles
y solo envía al VDP las casillas modificadas. Incluye HUD renovado, control
rotatorio o direccional, redefinición de teclas, seguimiento de cámara y las
melodías y efectos adaptados al PSG.

## Aplicar el parche

Necesitas Python 3, Pillow, SkoolKit y Pasmo en el `PATH`. Coloca tu snapshot
con este nombre:

`JUEBOS/Ant_Attack_1983_Quicksilva.z80`

La copia debe tener SHA-256
`aad0783b2fe3274be1aaeb3587e26187cf61a2c62a3cd997618a427d9932f1cd`.

```powershell
python -m pip install -r requirements.txt
python tools\normalize.py
python tools\make_ips.py apply build\Ant_Attack_MSX1_base.rom patch\Ant_Attack_MSX1.ips build\Ant_Attack_MSX1.rom
```

El resultado es `build/Ant_Attack_MSX1.rom`, de 65.536 bytes.
La compilación de referencia tiene SHA-256
`0cd4bb3ac868d4374925cd78a0fcade65bf9167d8d9099ef263b12bb4db54b1a`.

El IPS se aplica a la base normalizada, no directamente al `.z80`. De ese modo
el parche contiene la conversión y sus cambios, no una copia completa del
juego. `python tools\build.py` reconstruye la ROM desde las fuentes del parche
y permite verificar que produce exactamente la misma huella.

El desensamblado de referencia está en
[`disassembly/ant_attack_zx.asm`](disassembly/ant_attack_zx.asm).

## Controles

- Cursores: avanzar, retroceder y girar o desplazarse según el modo elegido.
- Espacio: saltar.
- M, N, B y V: lanzar granada con cuatro alcances.
- 1 a 4: elegir vista.
- 0: reiniciar desde la portada.
- K: redefinir teclas.

En la portada, `B` elige chico y `G` chica.

## Estado y validación

Araubi completó manualmente el juego. Además hay pruebas automatizadas de
cámara, controles, daño, rescates, niveles, HUD, temporizador y registros del
PSG sobre Philips VG-8020 en openMSX. Las pruebas de sonido verifican la
secuencia de registros y su finalización; no certifican equivalencia tímbrica
con el beeper original ni funcionamiento en hardware real.

Consulta [el mapa del motor](docs/ENGINE_MAP.md) y el
[aviso legal y los créditos](AVISO-LEGAL.md).

