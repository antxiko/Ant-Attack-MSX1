# Ant Attack: contrato entre el motor Spectrum y la capa MSX

Revisión del 13-10-2026. Fuente: snapshot original, su BASIC extraído en
`build/original_basic_listing.txt` y desensamblado `build/engine_dis.asm`.
Las direcciones siguientes corresponden exclusivamente a este snapshot.

## Ciclo del juego

`8000` inicia la sesión de código máquina. `8009` es el comienzo de cada
vuelta, lee la salida y llama a `8E80`. Este ejecuta, en orden:

| Entrada | Operación | Adaptación MSX |
|---|---|---|
| `82C0` | Entrada y movimiento del jugador | `msx_control_input`, `msx_player_move` |
| `8F80` | Compañero: búsqueda, recogida y seguimiento | Motor original |
| `83E0` | Granada: entrada, movimiento y explosión | Entrada MSX y alcance ampliado |
| `80D3` | Actualización de hormigas | Motor original |
| `8400` | Teclas de ángulo y recolocación | Teclas traducidas por `keymap` |
| `84A0` | Generación y presentación de la vista | Cámara antes del mapa; volcado MSX al final |
| `81B0` | Selectores de profundidad desde terreno proyectado | Caché validada por los 672 bytes de entrada |
| `8100` | Copia del bitmap compuesto a disposición Spectrum | `msx_copy_bitmap`, misma copia con LDI desplegado |
| `8F00` | Consumo de impactos y energía | Motor original; eventos al PSG/HUD |
| `8FD0` | Eventos de la granada | Motor original; sonido sustituido |
| `8DD0` | Reloj y antiguo texto BASIC | `game_timer_hook`, sin llamadas a ROM ZX |

Después se comprueba salida de la ciudad (`8EA0`) y fin por energía/tiempo
(`8ED0`). No se debe avanzar un nivel sólo por recoger al compañero:
`B49D=1` es seguimiento; `B49D=2` es rescate completado fuera de la ciudad.

## Datos persistentes

| RAM | Significado |
|---|---|
| `B420`, `B421` | Origen de cámara en coordenadas de mundo, bytes modulares |
| `B422` | Ángulo 0..3 |
| `B42D` | Eventos de lanzamiento/explosión |
| `B42E` | Tiempo restante de vuelo de la granada |
| `B430` | Munición |
| `B432` | Energía de la entidad controlada; no significa siempre GIRL |
| `B434` | Energía del acompañante |
| `B435` | Divisor del reloj original |
| `B436:B437` | Tiempo, byte alto primero |
| `B438` | Vueltas antes de retornar; `FF` mantiene la partida |
| `B480` | Jugador, registro de 16 bytes |
| `B490` | Compañero, registro de 16 bytes |
| `B4A0` | Granada, registro de 16 bytes |
| `B4B0..B4F0` | Cinco hormigas; las cuatro últimas reciben dificultad BASIC |

Registro de entidad: `+0/+1/+2` = X/Y/altura, `+3` sprite base,
`+4` orientación, `+5` caída, `+6` inmovilización, `+7` banderas
(bit 1 salto, bit 2 avance), `+8` animación, `+9` espera de reaparición,
`+A/+B/+C` posición de reaparición, `+F` evento de impacto.
`+D/+E` dependen del tipo: seguimiento/distancia del compañero o cadencia
de la hormiga. No pueden interpretarse igual para todas las entidades.

## Cámara, proyección y datos temporales

`8600` proyecta las ocho entidades en `B450..B467`. La entrada del jugador
se encuentra entonces en `B465`; después `8580` ordena la lista y `85D0`
la convierte a diferencias. Por tanto, leer `B465` al final de una vuelta
NO devuelve de forma fiable la coordenada de pantalla del jugador. Las
primeras trazas del port no respetaban esa fase y su interpretación era
incorrecta. Una proyección rechazada lleva un marcador alto `FF` durante
la fase en que lo usa el scroll original.

Con X/Y relativos a la cámara, las vistas forman `(L,H)` como
`(X,Y)`, `(Y,-X)`, `(-X,-Y)` o `(-Y,X)`. Después suman altura a L y la
restan a H. El motor exige `0 <= L+H < 32` y `0 <= H-L < 32`.

El seguimiento MSX conserva un margen de tres casillas por eje, corrige
la altura según la vista y recorta al borde del margen antes de generar
el mapa. Desde el 15-10-2026, `camera_bottom_margin` adelanta el seguimiento
inferior: si H-L supera 23, desplaza la cámara en diagonal en el mundo,
manteniendo L+H. Esto sitúa `L+H` en 9..21 y `H-L` en 15..23 (antes 27).
No modifica los límites superior ni laterales. El caso de
`AntAttack (4).omr` demuestra por qué seis por eje era incorrecto:
X=-9, Y=24, altura=0 daban H-L=33 y el motor omitía al jugador.

## Vídeo e interrupciones

La capa está en RAM `0000..37FF`. Stack inicial `3FF0`; durante juego
`7FF0`. La imagen Spectrum se conserva en `4000..57FF`, atributos en
`5800..5AFF`. Shadow de los 480 tiles jugables en `6000..6EFF`;
shadow de atributos en `3500..37FF`. El mapa/recursos del juego ocupan
las zonas originales altas. El mapa de colisión usa seis bits de altura
por casilla; `8920` consulta y `8940` altera ocupación.

La caché de profundidad guarda la entrada B180..B41F en `7000..729F` y
los 512 bytes de resultado B500..B6FF en `7300..74FF`. Se invalida al iniciar
o reintentar un nivel. En cada dibujo se compara TODA la entrada; si cambia
un byte se ejecuta el cálculo original. En acierto se restaura el resultado,
porque el compositor 8500 modifica B500..B6FF al recorrerlo. Esta caché no
sustituye el dibujo de personajes ni la composición/ocultación de edificios.
La copia al VDP usa ocho escrituras desplegadas: separación nominal de
35 T, más las esperas MSX. No eliminar más instrucciones sin medir el VDP.

SCREEN 2: patrones `0000..17FF`, nombres `1800..1AFF`, colores
`2000..37FF`. El mapa usa y=8..127; cabecera y=0..7; HUD y=128..191.
Los tres sprites SCAN tienen atributos en `1B00` y patrón en `3800`.
La tabla de atributos del mapa convierte el blanco Spectrum a amarillo MSX
10, tanto en tinta como en papel. Conserva la polaridad de los patrones y
los demás colores. El HUD y los menús usan tablas de color independientes.

La ISR reconoce VBlank leyendo el estado VDP y actualiza el PSG. Esa lectura
reinicia el biestable del puerto de control. `vaddr` protege ambas escrituras
de dirección con DI y restaura el estado anterior. Los datos pueden enviarse
con IRQ activa porque la ISR no escribe VRAM. No añadir escritura VDP en la
ISR sin revisar este contrato. La ISR conserva AF/BC/DE/HL; no toca IX/IY
ni registros alternativos usados por el motor original.

## BASIC sustituido y diferencias intencionadas

- BASIC 750 pone 1001 al comenzar nivel. BASIC 70 reintenta conservando el
  tiempo: el port auditado preserva B436/B437 en `restart`.
- BASIC 190 fija B4CD/B4DD/B4ED/B4FD a `2 + floor(rescates/4)` desde el
  primer nivel. No basta con cambiar esos bytes a partir del cuarto rescate.
- Puntuación: tiempo restante por número de rescate (1..10). Máximo normal
  55055, cabe en el contador de 16 bits del port.
- Las posiciones alternativas de rescate corresponden a DATA 1001..1091.
  La variante es el tiempo final módulo cuatro; el nivel inicial tiene una.
- Extras pedidos: redefinición, retroceso, modo direccional, HUD con marcos,
  granadas con vuelo ampliado, reloj aproximadamente 30% más rápido y
  señal PSG al completar nivel. El timbre PSG es una aproximación al beeper.
- Los relatos y pantallas de la adaptación son más sencillos que el BASIC.

## Verificación

Cambios de esta revisión: recorte inmediato de cámara al margen válido,
tiempo conservado al reintentar, cadencia inicial de las cuatro hormigas
ajustada al BASIC y contador de rescates actualizado a diez antes de victoria.

`python tools/audit_ant.py` arranca Philips VG-8020, se sincroniza por
entradas del código y registra resultados y hash de ROM en
`build/audit/results.json`. Las llamadas de diagnóstico y estados preparados
no constituyen una partida completada por una persona. Los OMR antiguos
sirven para reconstruir fallos y observar secuencias; sus entradas pueden
divergir tras cambiar los ciclos de CPU de una ROM. La escucha comparativa
y el hardware real deben declararse aparte.
