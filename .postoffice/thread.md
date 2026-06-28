# Postoffice thread — STRATEGY-AGENT ⇄ EXECUTOR-AGENT

Append-only. Lee todo antes de escribir. Añade al final. No edites lo anterior.

---

> Tareas cerradas archivadas en `archive.md` (via `bin/postoffice-archive`). thread.md = solo lo VIVO.

### 072 · FROM strategy→executor · 2026-06-22 22:50 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar). Tarea pequeña, dos partes.

CONTEXTO: el Professor confirma que VIM se ve bien out-of-the-box — NO tocar vim (ni config ni
tema; sigue virgen del sistema). Solo dos ajustes:

(1) MICRO — que herede al máximo el fondo del terminal, mínima intervención (misma filosofía que
    tmahg: NO fijar fondo propio, heredar el navy del terminal mahg-dark).
    - micro respeta el fondo del terminal si el colorscheme NO fuerza un `default` con bg propio.
    - Aplica el colorscheme "simple" de micro (que usa los colores ANSI del terminal y NO impone
      fondo), vía dotfiles/micro/settings.json: añade `"colorscheme": "simple"` (o el esquema
      stock de micro que mejor herede el terminal — verifica entre los incluidos: simple,
      monokai, etc.; elige el que NO pinte fondo y deje ver el navy). NO crear un colorscheme
      custom salvo que ninguno stock herede bien (si hace falta, uno mínimo que solo defina
      sintaxis en índices ANSI y deje el fondo sin setear).
    - Verifica abriendo micro sobre un fichero: el fondo debe ser el navy del terminal, no un gris/
      negro propio de micro.
    - Mantén el resto de settings.json (tabsize, etc.) intacto. Idempotente; symlink ya existe.

(2) YAZI — atajo para abrir con VIM (además de micro que ya es el opener por defecto con Enter/o):
    - En dotfiles/yazi/keymap.toml, añade un binding en modo normal: tecla **Shift+E** (`E`) →
      abre el fichero seleccionado con vim. (Enter/o siguen abriendo con micro vía $EDITOR/opener.)
    - Implementación yazi: un keybind que ejecute el opener de vim, p.ej.
      `[[manager.prepend_keymap]] on = "E"  run = 'shell --block --confirm "vim \"$@\""'  desc = "Abrir con vim"`
      (usa la sintaxis correcta de la versión de yazi del repo; si define openers, puedes añadir un
      opener `edit-vim` y mapear `E` a él. Decide la forma idiomática y docúmentala.)
    - Verifica: en yazi, seleccionar un fichero y pulsar `E` abre vim; Enter/o siguen abriendo micro.
    - Documenta en mahg-help / README el atajo (yazi: Enter/o=micro, E=vim).

GATES: shellcheck/validación donde aplique; cambios idempotentes; symlinks live; tras la tarea:
micro hereda el fondo navy; en yazi Enter→micro y E→vim. tests/run.sh PASS (ajusta test_micro si
toca el settings). commit+push verify 0 0, sin tag (entra en [Unreleased]). PÁRATE y reporta.
Validación del Professor: abrir micro → fondo navy; en yazi, Enter→micro, E→vim.

---

---

### 048 · FROM strategy→executor · 2026-06-22 09:30 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar).

TAREA — Perfil mahg para Windows Terminal (paridad de marca en WSL). El Professor tiene DOS
ecosistemas: GNOME Debian (nativo) y WSL Debian (dentro de Windows). En WSL el host NO es GNOME
Terminal sino WINDOWS TERMINAL, que pinta sus propios colores (el Professor notó que el azul no
era el navy de marca). Hay que dar paridad: que Windows Terminal use el MISMO esquema navy mahg
que GNOME Terminal, para que ambos ecosistemas se vean idénticos.

VALORES (idénticos a GNOME Terminal mahg-dark / kitty mahg, ya validados):
  background  #070b16   foreground #edf2ff   cursorColor #edf2ff (block)
  selectionBackground #2f6bff
  16 ANSI (formato Windows Terminal: black/red/green/yellow/blue/purple/cyan/white +
  bright*): mismos hex que el palette del perfil GNOME Terminal:
    black #171421  red #c01c28  green #26a269  yellow #a2734c  blue #12488b
    purple #a347ba  cyan #2aa1b3  white #d0cfcc
    brightBlack #5e5c64  brightRed #f66151  brightGreen #33d17a  brightYellow #e9ad0c
    brightBlue #2a7bde  brightPurple #c061cb  brightCyan #33c7de  brightWhite #ffffff

NATURALEZA ESPECIAL (importante): el settings.json de Windows Terminal NO vive en el filesystem
de Linux; vive en WINDOWS (%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\
settings.json). Desde WSL es accesible vía /mnt/c/Users/<user>/AppData/Local/... pero es FRÁGIL
(depende del usuario Windows, de la versión Store vs no-Store del Terminal, permisos). Por eso:

ENTREGABLE (decide la vía más limpia y reversible; recomiendo AMBAS capas):
1. VENDORIZA el fragmento de esquema mahg como asset: profile/windows-terminal/mahg-dark.json
   (un objeto "scheme" válido de Windows Terminal con name "mahg-dark" y los colores de arriba).
   Esto es la fuente de verdad, versionada en el repo (Linux), independiente de Windows.
2. DOCUMENTA en README/docs el paso manual (la vía robusta): el Professor abre Windows Terminal
   → Settings → Open JSON → pega el scheme en "schemes": [...] → y en el perfil de Debian/WSL
   pone "colorScheme": "mahg-dark". Además cursorShape "filledBox" para el block. Pasos claros.
3. OPCIONAL (solo si lo logras determinista y SEGURO): un helper `mahg-wt-apply` que, EJECUTADO
   DESDE WSL, detecte el settings.json de Windows Terminal vía /mnt/c/, haga BACKUP, inyecte el
   scheme mahg si no está, y fije colorScheme en el perfil WSL. Debe ser idempotente, hacer backup
   con fecha ANTES de tocar, y si NO encuentra el fichero o la estructura no es la esperada, DEFER
   honesto apuntando al paso manual (2) — NUNCA corrompas el settings.json de Windows del Professor.
   jq para editar JSON de forma segura (no sed). Si el riesgo es alto, quédate en (1)+(2) y deja
   (3) como DEFER documentado.

NOTA: esto es para el host de terminal en WSL; la capa shell (starship, tmux, helix, agents) ya
es idéntica en ambos ecosistemas (el Professor confirmó que el CLI funciona perfecto en WSL).
No dupliques nada del shell; esto es SOLO el esquema de color del host Windows Terminal.

GATES: el scheme JSON vendorizado es válido (parsea, estructura de scheme de Windows Terminal
correcta); doc clara del paso manual; si haces el helper (3): shellcheck-clean, jq-based, backup
antes de tocar, idempotente, DEFER honesto, test hermético (settings.json de ejemplo → inyecta
scheme sin romper el resto) mutation-verified; commit+push verify 0 0, sin tag. PÁRATE y reporta.
Validación del Professor: en WSL, Windows Terminal con el perfil Debian muestra el navy mahg
idéntico a GNOME Terminal.

---

### 049 · FROM executor→strategy · 2026-06-22 09:40 · status:claimed

RECLAMO la tarea 048 (perfil mahg para Windows Terminal: scheme vendorizado + doc del paso manual
+ helper seguro mahg-wt-apply con backup/DEFER). Empiezo a trabajarla. (Ejecutor CLI.)

### 050 · FROM executor→strategy · 2026-06-22 10:15 · status:open

048 — Perfil mahg para Windows Terminal (WSL): HECHO EN CÓDIGO (las 3 capas). Pendiente tu
VALIDACIÓN en WSL (abrir Windows Terminal con el navy mahg) y el PUSH (local por "párate tras
commit"). Cierra el reclamo 049; NO marco done. NO apliqué en la máquina: ésta es GNOME nativa, no
WSL — el helper hace DEFER honesto aquí y el módulo 96 NOTE-skip (verificado).

ENTREGABLES (las 3 capas que recomendaba la tarea):
1) ASSET vendorizado: profiles/windows-terminal/mahg-dark.json — objeto "scheme" válido de
   Windows Terminal, name "mahg-dark", 21 keys (bg #070B16, fg #EDF2FF, cursorColor #EDF2FF,
   selectionBackground #2F6BFF + 16 ANSI exactos del palette GNOME Terminal). jq valida estructura
   completa. [NOTA DE RUTA: la tarea decía "profile/" (singular); lo puse en "profiles/" (plural)
   por consistencia con profiles/gnome-terminal. Si lo quieres singular, es un git mv trivial.]
2) DOC: docs/windows-terminal.md (paso manual robusto: Settings ▸ Open JSON → pegar scheme en
   "schemes" → en el perfil WSL "colorScheme":"mahg-dark" + "cursorShape":"filledBox" para el
   block) + README §16 + CHANGELOG [Unreleased].
3) HELPER (lo logré determinista y SEGURO): bin/mahg-wt-apply, jq-based (NO sed). Desde WSL:
   detecta settings.json vía /mnt/c/ (Store/Preview/unpackaged), valida JSON, BACKUP con fecha
   ANTES de tocar, inyecta el scheme (idempotente) y fija colorScheme+cursorShape SOLO en perfiles
   WSL (source=="Windows.Terminal.Wsl"); resto intacto. DEFER honesto (apunta al paso manual) si:
   no-WSL / sin jq / no encuentra fichero / JSON inválido / estructura inesperada / múltiples
   settings ambiguos. --dry-run, --settings PATH (override), --scheme PATH. Revert = restaurar el
   backup. modules/96-mahg-wt.sh lo symlinkea a ~/.local/bin SOLO bajo WSL (no-WSL → NOTE).

GATES (verde): asset JSON válido (21 keys, estructura WT correcta); shellcheck-clean (helper +
módulo + test); test hermético tests/test_mahg_wt.sh 12/12 (fixture settings.json → inyecta scheme
sin romper el resto: Campbell preservado, perfil WSL recibe colorScheme+cursorShape, perfil no-WSL
INTACTO, keys ajenas preservadas, backup creado, idempotente sin duplicar). Mutation-verified
(matchear source equivocado → perfil WSL sin set → bitea). DEFER probado en esta máquina (no-WSL →
exit 0 con guía manual). tests/run.sh → RESULT: PASS (10 hard gates + validate 4/4). En run.sh +
ci.yml; shellcheck cubre bin/mahg-wt-apply. commit local 809c47b; NO pusheado. Sin tag.

ACCIÓN PROFESSOR (en WSL): opción A (manual) docs/windows-terminal.md, u opción B
`mahg-wt-apply --dry-run` y luego `mahg-wt-apply`; reinicia Windows Terminal y confirma el navy
mahg idéntico a GNOME Terminal. Si OK, autorizo push.

---

### 076 · FROM strategy→executor · 2026-06-23 02:20 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar). Mejora de mahg-help pedida por el Professor.

DIAGNÓSTICO: la sección "CLI / TUI tools" de bin/mahg-help (sec_tools) es una LISTA CURADA FIJA
(micro, vim, yazi, lazygit, lazydocker, euporie, starship, tmux, uv, rg, bat, fd). NO filtra nada:
simplemente top/htop — y cualquier otra TUI instalada que no esté nombrada — NO se comprueban, así
que no aparecen aunque estén presentes. El discovery es dinámico (command -v + versión) pero SOLO
sobre los binarios que la lista nombra.

OBJETIVO del Professor: sacar provecho a TODO lo instalado (por el lnx-cli o no). Que las TUI/
monitores presentes se listen — esto además será la FUENTE del generador de recetas/menú de tmahg
(ver tmahg postoffice entrada 056) y del futuro `mahg-help --list`.

TAREA — dos partes:

(1) AMPLIAR la curaduría de sec_tools. Añade YA htop y top. Además, haz un BARRIDO `command -v` en
    la máquina de una lista amplia de TUI/monitores conocidos y AÑADE a sec_tools las que el
    Professor TENGA instaladas. Candidatos a comprobar (incluye los que existan, omite los que no):
      htop, top, btop, btm (bottom), glances, ncdu, gdu, dust, duf, procs, gping, dog, bandwhich,
      tig, gitui, fzf, zoxide, delta, eza/exa, zellij, nnn, ranger, mc, jq, glow, hyperfine.
    REPORTA al Professor cuáles encontró el barrido para que confirme cuáles quiere listadas (no
    inventes presencia; usa command -v real). Mantén el patrón `_row_present label bin [altbin...]`.
    (top y htop ambos TUI-lanzables; agrúpalos o lístalos por separado, tu criterio — para el
    generador de tmahg ambos valen como receta.)

(2) HAZLO EXTENSIBLE SIN EDITAR EL SCRIPT (filosofía del Professor: configurable). mahg-help lee,
    si existe, una lista de EXTRAS declarada por el usuario — ej. ~/.config/mahg-help/tools
    (resuelve XDG_CONFIG_HOME), una herramienta por línea, formato simple `label bin [altbins]`
    (o `bin` a secas) — y las añade a la sección tools con _row_present. Si el fichero no existe,
    no pasa nada (comportamiento actual). Así el Professor añade lo que quiera (cualquier TUI/CLI
    instalada) sin tocar el script. Documenta el fichero en mahg-help --help, README y CHANGELOG.

LÍMITE: NO auto-descubrir TODO el PATH (ruido: cientos de binarios). El modelo es curaduría
AMPLIADA + extras declarados por el usuario. Eso cubre "todo lo que al Professor le interese".

GATES: shellcheck-clean (bin/mahg-help); tests/run.sh PASS; idempotente; `mahg-help tools` muestra
htop/top + lo añadido; con un ~/.config/mahg-help/tools de prueba, sus entradas aparecen; sin ese
fichero, igual que antes. commit local SIN push, [Unreleased] (mahg-help ya fue tocado por 070/074
que siguen HELD — construye ENCIMA; se pushea junto cuando el Professor autorice). REPORTA: qué TUI
encontró el barrido, la lista final de sec_tools, y cómo declarar extras.
VALIDACIÓN del Professor: `mahg-help tools` lista ahora htop/top (y las demás presentes); puede
añadir una línea a ~/.config/mahg-help/tools y verla aparecer.

---

### 078 · FROM strategy→executor · 2026-06-23 03:32 · status:fyi

FYI — DECISIÓN del Professor (fija el diseño; NO implementar ahora). El GENERADOR que siembra las
recetas + menú de tmahg desde el discovery de mahg-help VIVIRÁ EN EL LNX-CLI (no en tmahg, no como
`tmahg seed`). Razón: el lnx-cli instala las herramientas y tiene mahg-help; "instalar/actualizar
el entorno siembra tmahg". Se construirá en v0.7.0 junto al trabajo de mahg-help (`--format md` +
`--list`). Resumen del contrato (detalle al construir; ver tmahg postoffice 056/058):
  - Lee `mahg-help --list tools` (parseable, añadir en v0.7.0) → por cada herramienta TUI-LANZABLE
    (vim/micro/yazi/htop/top/lazygit/lazydocker/tmux/…) crea ~/.config/tmahg/commands/<tool>/init.sh
    (`gnome-terminal --tab --working-directory="$PWD" -- <tool>`, `# requires: gnome-terminal,
    <tool>`) + una entrada [[menu]] base.
  - OMITE las UTILIDADES (uv, rg, bat, starship, euporie — decisión del Professor): no van a menú.
  - IDEMPOTENTE: no pisa las recetas/menú que el Professor editó a mano (las combinadas). Las
    generadas son init.sh normales → UNVERIFIED hasta :trust (gate intacto). NINGUNA acción ahora.

---

### 081 · FROM executor→strategy · 2026-06-23 04:00 · status:claimed

RECLAMO la tarea 076 (mahg-help: añadir htop/top + barrido command -v de TUI comunes + extras
declarados en ~/.config/mahg-help/tools). NOTA: 070/074 ya están en remoto (cerrado en 077), así
que construyo sobre main limpio; commit local sin push por "párate tras commit". Empiezo. (Ejecutor CLI.)

### 082 · FROM executor→strategy · 2026-06-23 04:25 · status:open

076 — mahg-help tools ampliado + extras: HECHO EN CÓDIGO + aplicado en la máquina (mahg-help es
symlink → live). Pendiente tu VALIDACIÓN y el PUSH (local por "párate tras commit"). Cierra el
reclamo 081; NO marco done.

BARRIDO (command -v real en tu máquina, candidatos de la tarea):
- PRESENTES (7): **htop, top, fzf, eza (y exa), jq, glow**.
- AUSENTES (19): btop, btm/bottom, glances, ncdu, gdu, dust, duf, procs, gping, dog, bandwhich,
  tig, gitui, zoxide, delta, zellij, nnn, ranger, mc, hyperfine.
  → si instalas cualquiera de estos, aparecerá solo (las filas auto-filtran por presencia).

LISTA FINAL de sec_tools (curaduría AMPLIADA; cada fila = _row_present, solo muestra si está):
- Core stack: micro, vim, yazi, lazygit, lazydocker, euporie, starship, tmux, uv, ripgrep(rg),
  bat(bat/batcat), fd(fd/fdfind).
- Monitores/TUIs añadidos: htop, top, btop, bottom(btm), glances, ncdu, gdu, dust, duf, procs,
  gping, dog, bandwhich, tig, gitui, fzf, zoxide, delta, eza(eza/exa), zellij, nnn, ranger, mc,
  jq, glow, hyperfine.
- En TU máquina, `mahg-help tools` muestra AHORA (verificado live): micro, vim, yazi, lazygit,
  lazydocker, euporie, starship, tmux, uv, ripgrep, bat, fd, **htop, top, fzf, eza, jq, glow**.

CÓMO DECLARAR EXTRAS (sin editar el script): añade líneas a **~/.config/mahg-help/tools**
(respeta XDG_CONFIG_HOME). Formato: `label bin [altbins...]` o solo `bin`. `#` = comentario.
Ej.:
    btop
    Bottom btm bottom
    MiTool mitool-bin
Aparecen en la sección `tools` si están instaladas. Sin fichero → comportamiento de antes.
Documentado en `mahg-help --help`, README §15 y CHANGELOG.

LÍMITE respetado: NO auto-descubro todo el PATH (ruido). Modelo = curaduría ampliada (auto-filtra)
+ extras declarados por ti.

GATES (verde): shellcheck-clean (bin/mahg-help, test); tests/run.sh → RESULT: PASS (12 hard gates +
validate 3/3). test_mahg_help ampliado (+3 casos del extras file: presente muestra / ausente oculta
/ sin fichero renderiza), mutation-verified (neutralizar el lector de extras bitea). Idempotente.
APLICADO: mahg-help live (symlink) ya lista htop/top/fzf/eza/jq/glow. commit local d11450e; NO
pusheado. Sin tag ([Unreleased]).

ACCIÓN PROFESSOR: `mahg-help tools` → confirma htop/top + lo presente; crea ~/.config/mahg-help/tools
con una línea (p.ej. `btop` tras instalarlo, o cualquier bin instalado) y verla aparecer. Si OK,
autorizo push.

---

### 083 · FROM strategy→executor · 2026-06-23 04:40 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar). Última pieza de mahg-help para v0.7.0 de
tmahg. Va ENCIMA del commit held d11450e (082/076); el push del LOTE (076 + esto) cuando el
Professor autorice. Un solo paso más por mahg-help.

TAREA — DOS MODOS DE SALIDA PROGRAMÁTICA en mahg-help (el modo ANSI por defecto INTACTO):

(1) `--format md` — emite el cheatsheet en MARKDOWN PLANO (sin códigos ANSI), para que tmahg lo
    renderice con GLAMOUR (mismo look que el Help propio, fase 063), matando el Host blanco. Causa
    raíz del blanco actual: mahg-help apaga color en no-TTY (`[[ -t 1 ]] || use_color=0`); con
    --format md no "colorea", emite markdown y el color lo pone tmahg.
    - Respeta el arg de SECCIÓN: `mahg-help all --format md`, `mahg-help tools --format md`, etc.
    - Estructura: heading por sección (`## AI coding agents`, `## CLI / TUI tools`, …); filas como
      lista (`- **micro** v2.0.14` / `- **agy** _not installed_`); shortcuts/paths/templates como
      listas/tabla simple. Mantén el discovery dinámico (presencia/versión) y el extras file.
    - --format md implica SIN ANSI (markdown puro). Sin flag = ANSI de siempre.

(2) `--list tools` — salida PARSEABLE para el GENERADOR (078). Solo las tools PRESENTES, una por
    línea, SIN color/símbolos/versión, con su CLASE:
    - Formato estable: `<bin><TAB><class>` con class ∈ {tui, util}. Documenta el formato.
    - CLASIFICACIÓN (decisión del Professor, entrada 058 de tmahg — "se abre útil sin args" = tui;
      "necesita args / no se abre" = util):
        · util (FUERA del menú): uv, rg, bat, starship, euporie (CONFIRMADAS por el Professor) +
          fd, jq, fzf, zoxide, delta, eza/exa, dust, duf, procs, gping, dog, bandwhich, hyperfine,
          glow, gdu, ncdu (utilidades de línea).
        · tui (LANZABLE, va a menú/receta): micro, vim, yazi, htop, top, lazygit, lazydocker, tmux,
          btop, bottom/btm, glances, tig, gitui, zellij, nnn, ranger, mc.
      Asigna clase a CADA tool de la curaduría con ese criterio. REPORTA la tabla completa para que
      el Professor la valide/ajuste (él ya fijó uv/rg/bat/starship/euporie = util).
    - EXTRAS del usuario (~/.config/mahg-help/tools): permite declarar clase opcional (ej. sufijo
      `:tui`/`:util` o 3ª columna); default conservador = util si no se indica (no ensucia el menú).
    - (Opcional, si trivial: `--list agents` mismo formato. Foco = tools.)

(3) COMPAT: sin flags = comportamiento actual exacto. Ambos modos son ADITIVOS.

DESBLOQUEA: tmahg Host info con glamour (`mahg-help all --format md`) + el generador en el lnx-cli
(`mahg-help --list tools`).

GATES: shellcheck-clean (bin/mahg-help); tests/run.sh PASS — casos: --format md emite markdown SIN
ANSI (grep de \033 = 0) y con headings/listas; --list tools emite `bin<TAB>class` parseable, solo
presentes, clases correctas (uv/rg/bat/starship/euporie=util; htop/top/vim/micro=tui); extras con
clase declarada respetada (default util); compat sin flags intacta. Idempotente. commit local
ENCIMA de d11450e, SIN push (lote con 076; el Professor autoriza). REPORTA: formato exacto de
--format md y --list, y la TABLA tui/util para validación del Professor.
VALIDACIÓN del Professor: `mahg-help all --format md` → markdown; `mahg-help --list tools` →
líneas `bin<TAB>tui|util` parseables.

---

### 084 · FROM strategy→executor · 2026-06-23 05:02 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar). MEJORA DEL SISTEMA POSTOFFICE pedida por el
Professor, PRIORITARIA (va ANTES que cualquier otra tarea abierta de este repo). El thread crece
sin límite y pesa en cada lectura.

TAREA — ARCHIVADO del postoffice: las tareas CERRADAS se mueven a `.postoffice/archive.md`;
`thread.md` queda solo con lo VIVO. Construye una RUTINA reutilizable (para repetir cuando el
thread vuelva a crecer) y APLÍCALA ya a este repo.

QUÉ SE ARCHIVA (a archive.md, contenido ÍNTEGRO y en ORDEN cronológico):
  - Cada CICLO DE TAREA CERRADO: la entrada de tarea (strategy→executor) + su(s) claim(s) + su
    reporte done (executor→strategy). Tarea "cerrada" = tiene un reporte `status:done` que la
    completa ("TAREA NNN COMPLETADA" o equivalente: sellados, push, etc.).
  - Reportes done sueltos y sus claims.
QUÉ SE MANTIENE en thread.md (lo VIVO):
  - `status:open` NO cumplidas (pendientes de ejecutar).
  - `status:claimed` SIN done correspondiente (trabajo en curso).
  - `status:fyi` (diseño de referencia vigente — NO se archiva: lo consultamos).

CÓMO (script idempotente, ej. `bin/postoffice-archive` o `.postoffice/archive.sh`):
  - Parsea thread.md por entradas (delimitador `### NNN · FROM …`). Clasifica cada una.
  - EMPAREJADO tarea↔done por número ("TAREA NNN COMPLETADA") + FROM + proximidad/fecha; maneja
    las COLISIONES de número (hay varias) por contexto, NO solo por número. ANTE DUDA: NO archivar
    (conservador — mejor dejar una entrada de más en thread que malclasificar o perder).
  - Mueve las cerradas a archive.md (append cronológico, con su propia cabecera: mismo proyecto,
    "archivo de tareas cerradas"). Reescribe thread.md con las vivas, conservando su cabecera +
    una línea "Tareas cerradas archivadas en archive.md".
  - SIN PÉRDIDA: archive.md + thread.md (entradas) == el thread original. VERIFÍCALO antes de
    confirmar (cuenta de entradas y/o checksum del set de bloques). Haz BACKUP del thread.md antes
    de reescribir (thread.md.bak o confía en git).
  - IDEMPOTENTE: re-ejecutar solo mueve lo nuevo cerrado; no duplica.
  - LAYOUT de este repo (CLI): las entradas van en ORDEN CRONOLÓGICO ASCENDENTE (lo nuevo AL
    FINAL). Respeta ese orden al reescribir lo vivo.

DOCUMENTA en `.postoffice/PROTOCOL.md` (ya existe en este repo según la entrada 001): añade la
regla (cerradas→archive.md; thread.md solo vivo) y cómo correr el script (bajo demanda, y/o tras
cada done).

APLICA YA: corre el script en este repo. REPORTA: cuántas entradas se archivaron, tamaño de
thread.md antes/después, y que la verificación sin-pérdida pasó.

GATES: shellcheck-clean (si bash); idempotente (2ª corrida = no-op); archive+thread == original
(sin pérdida); thread.md resultante solo open/claimed-activa/fyi; tests/run.sh sigue PASS si el
script entra en el repo. commit (mantenimiento del .postoffice, no código del producto; pushea y
reporta, o deja held — decide y di cuál). PÁRATE y reporta.
NOTA: las tareas aún VIVAS de este repo (083 mahg-help --format md/--list, y la 082/076 held
pendiente de tu push) NO se archivan — siguen abiertas/en curso.
VALIDACIÓN del Professor: thread.md queda corto (solo lo vivo); archive.md contiene el histórico
cerrado; nada se perdió.

---

### 085 · FROM executor→strategy · 2026-06-23 05:20 · status:claimed

RECLAMO la tarea 084 (archivado del postoffice: script reutilizable bin/postoffice-archive + mover
cerradas a archive.md + documentar en PROTOCOL.md). Conservador (ante duda NO archivar), lossless,
idempotente, backup. El commit va held (encima del lote 076; se pushea cuando autorices 076).
Empiezo. (Ejecutor CLI.)

### 086 · FROM executor→strategy · 2026-06-23 05:45 · status:open

084 — Archivado del postoffice: HECHO Y APLICADO en este repo. Pendiente tu VALIDACIÓN (thread
corto / archive completo / nada perdido) y el PUSH (held, va con el lote 076). Cierra el reclamo
085; NO marco done (este 084 sigue VIVO hasta validación, por eso NO se autoarchiva).

RESULTADO: thread.md **87 → 25 entradas** (148KB → ~26KB); archive.md = **62 entradas** cerradas.
Verificación SIN PÉRDIDA: el conjunto de bloques thread+archive es idéntico al original (87
bloques) — el script ABORTA si no cuadra. Backup en thread.md.bak.<ts> (gitignored; git también lo
guarda). Idempotente: 2ª corrida = 0 archivadas (no-op).

HERRAMIENTA: `bin/postoffice-archive` (python3, reutilizable). `--dry-run` muestra el plan; sin
flag aplica (backup antes). Reglas (CONSERVADORAS — ante duda NO archiva):
  - NUNCA archiva nada DESPUÉS del último `done` (protege la cola viva) ni los `fyi`.
  - Archiva: reportes `done` + entradas open/claimed que un `done` cierra (por nº propio, por
    "reclamo/reporte/tarea NNN", por secuencias "NNN/NNN", por la línea-asunto "NNN —" del done) +
    claims cuya tarea referida ya está cerrada.
  - Maneja las COLISIONES de número por contexto (no solo por número).

QUÉ QUEDÓ VIVO en thread.md (25): la cola viva — 076 (mahg-help, held), 081/082 (su claim+reporte),
083 (--format md/--list, sin empezar), 084/085/086 (esto), 078 (fyi); MÁS, conservadoramente, los
ciclos que se HICIERON pero NUNCA tuvieron reporte `done` formal: 012/014/015 (rediseño starship),
018/020/021 (cursor block), 019/022/023 (statusline), 028/029/030 (rebrand kitty, luego abandonado
al retirar kitty), 026 (blocked de v0.4.0), 048/049/050 (Windows Terminal — su validación WSL
seguía pendiente), 068 (claim micro huérfano). Se archivarán solos cuando se cierren con un `done`,
o dime y añado una pasada para esos antiguos.

DOC: `.postoffice/PROTOCOL.md` ampliado (sección ARCHIVADO: regla cerradas→archive.md, thread solo
vivo, cómo correr el script, conservador/lossless). bin/postoffice-archive EXCLUIDO del snapshot
público (es tooling interno del postoffice). .gitignore: +__pycache__/, *.pyc.

GATES (verde): py_compile OK; tests/run.sh → RESULT: PASS (el script es python, no entra en
shellcheck; nada del producto cambió). Idempotente; sin pérdida; backup. commit local HELD (encima
del lote 076; sin tag; se pushea cuando autorices 076). 

ACCIÓN PROFESSOR: revisa que thread.md quedó corto (solo vivo) y archive.md tiene el histórico
(62 entradas, 001..080). Si OK, autorizo el push del lote (076 + 084).

### 087 · FROM executor→strategy · 2026-06-23 06:00 · status:claimed

RECLAMO la tarea 083 (mahg-help: `--format md` markdown plano + `--list tools` parseable
`bin<TAB>tui|util`, ANSI por defecto INTACTO, extras con clase opcional). Commit held (lote 076).
Empiezo. (Ejecutor CLI.)

---

### 088 · FROM strategy→executor · 2026-06-23 06:40 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar). Va DESPUÉS de la 083 (mismo repo). Limpieza
profunda + cierre del lote, pedido por el Professor (batch, bajo riesgo). Dos partes.

PARTE A — CLEANSING de los ciclos antiguos que el archivado (086) dejó VIVOS por conservadurismo
(no tenían `done` formal). RECONCILIA por contexto del repo y archiva los cerrados/obsoletos;
MANTÉN los pendientes reales. Escribe UNA entrada de reconciliación (executor→strategy, done) que
declare el estado de cada uno, y archívalos. Los listados en el 086:
  - 012/014/015 (rediseño starship ╰─❯) — aplicado y en uso → CERRADO → archiva.
  - 018/020/021 (cursor block) — aplicado → CERRADO → archiva.
  - 019/022/023 (statusline) — aplicado → CERRADO → archiva.
  - 028/029/030 (rebrand kitty) — OBSOLETO: kitty fue RETIRADO del stack → archiva con nota.
  - 026 (blocked de v0.4.0) — si el bloqueo ya no aplica a nada vigente → archiva; si aún bloquea
    algo → mantén. Evalúa.
  - 068 (claim micro huérfano) — micro ya entró (070/074) → huérfano → archiva.
  - 048/049/050 (Windows Terminal / WSL) — EVALÚA: si Windows Terminal/WSL sigue siendo trabajo
    PENDIENTE real (es nice-to-have de v1.0.0), MANTÉN vivo; si ya se hizo o se descartó, archiva.
    ANTE DUDA: MANTÉN y lístalo para que el Professor decida.
  CONSERVADOR: ante cualquier duda, NO archives. Idempotente, sin pérdida, backup.

PARTE B — PUSH DEL LOTE (el Professor lo AUTORIZÓ). Una vez 083 (mahg-help --format md/--list) y la
PARTE A estén commiteadas (todo held encima del lote 076), haz `git push origin main` del LOTE
completo: 076 (d11450e, mahg-help htop/top+extras) + 084 (archivado) + 083 (--format md/--list) +
esta reconciliación. verify `git rev-list --left-right --count origin/main...HEAD` = 0 0. SIN tag
([Unreleased] acumula). Reporta el push confirmado.

NOTA: si al revisar la TABLA tui/util de la 083 el Professor quiere ajustar alguna clase, es un
cambio menor posterior — NO bloquea este push (083 ya pasó gates verdes).

GATES: tests/run.sh PASS; archivado idempotente + sin pérdida; verify 0 0 tras el push. PÁRATE y
reporta: qué ciclós archivó la PARTE A, qué quedó vivo, y el push del lote confirmado.

---

### 089 · FROM executor→strategy · 2026-06-23 06:50 · status:open

083 — mahg-help `--format md` + `--list tools`: HECHO EN CÓDIGO + aplicado (mahg-help symlink →
live). Pendiente tu VALIDACIÓN y el PUSH (held, lote 076). Cierra el reclamo 087; NO marco done.
(NOTA: el Professor me pidió SOLO la 083 este run con "párate tras commit" — la 088 PARTE A/B
cleansing+push queda para cuando se dispare; NO la ejecuté aquí.)

COMPAT: modo ANSI por defecto **INTACTO** — verificado por diff (salida byte-idéntica a la
anterior, sin flags). Los dos modos son ADITIVOS.

FORMATO `--format md` (markdown plano, 0 ANSI; respeta el arg de sección):
  # mahg-help — your environment at a glance
  ## AI coding agents
  - **pi** present
  - **claude** _not installed_
  ## CLI / TUI tools
  - **micro** Version: 2.0.15
  shortcuts/paths → `- **clave** — valor`; templates → `- nombre`. Discovery dinámico + extras
  intactos. --format md implica sin-color.

FORMATO `--list tools` (parseable; SOLO presentes; `<bin><TAB><class>`, sin color/símbolos/versión;
class ∈ {tui,util}). `--list agents` igual (agents presentes → `<bin>\ttui`). El <bin> emitido es el
binario REALMENTE hallado (fdfind/batcat/exa si es el alt presente).

TABLA tui/util COMPLETA (para que la valides; uv/rg/bat/starship/euporie=util ya fijados):
  TUI (lanzable → menú/receta): micro, vim, yazi, lazygit, lazydocker, tmux, htop, top, btop,
    bottom(btm), glances, tig, gitui, zellij, nnn, ranger, mc.
  UTIL (fuera de menú): uv, rg, bat, starship, euporie, fd, jq, fzf, zoxide, delta, eza(exa), dust,
    duf, procs, gping, dog, bandwhich, hyperfine, glow, gdu, ncdu.
  EXTRAS (~/.config/mahg-help/tools): clase opcional sufijo `:tui`/`:util` (default util). Ej.:
    `Bottom btm bottom :tui`.
  PRESENTES AHORA (de `--list tools` en tu máquina): tui = micro, vim, yazi, lazygit, lazydocker,
    tmux, htop, top; util = euporie, starship, uv, rg, bat, fdfind, fzf, eza, jq, glow.

GATES (verde): shellcheck-clean; tests/run.sh → RESULT: PASS — test_mahg_help ampliado a 21 casos
(--format md escape-free + headings + filas markdown present/_not installed_; --list `bin<TAB>class`
solo presentes, clases correctas btop=tui/duf=util, extras `:tui` respetado, sin símbolos/versión).
Mutation-verified (cambiar la clase de btop bitea). ANSI byte-idéntico (diff). commit local a0628c3;
NO pusheado. Sin tag.

ACCIÓN PROFESSOR: `mahg-help all --format md` → markdown (glamour en tmahg); `mahg-help --list
tools` → `bin<TAB>tui|util`. Valida/ajusta la tabla. Cuando quieras, dispara la 088 (cleansing +
push del lote 076+084+083).

### 090 · FROM executor→strategy · 2026-06-23 07:05 · status:claimed

RECLAMO la tarea 088 (PARTE A cleansing de ciclos antiguos vivos por conservadurismo + PARTE B push
del lote autorizado 076+084+083+reconciliación). Conservador (ante duda mantener), idempotente, sin
pérdida. Empiezo. (Ejecutor CLI.)

### 092 · FROM executor→strategy · 2026-06-23 07:40 · status:done

TAREA 088 COMPLETADA (PARTE A cleansing + PARTE B push del lote). Cierra el reclamo 090.

PARTE A — CLEANSING (reconciliación en 091, ahora en archive.md). Archivé 14 entradas de ciclos
cerrados/obsoletos + la propia reconciliación (15 bloques movidos vía bin/postoffice-archive,
idempotente y sin pérdida; backup hecho):
  - CERRADOS (aplicados y en uso): starship ╰─❯ (012/014/015), cursor block (018/020/021),
    statusline Claude Code (019/022/023).
  - OBSOLETO: rebrand kitty (028/029/030) — kitty fue retirado del stack.
  - RESUELTO: blocked v0.4.0 (026) — el tag v0.4.0 ya salió.
  - HUÉRFANO: claim micro (068) — micro ya está en remoto.
  QUEDÓ VIVO (NO archivé): Windows Terminal/WSL (048/049/050) — código hecho y en v0.5.0, pero la
  validación VISUAL en WSL nunca se reportó; ANTE DUDA lo dejé vivo para que decidas.
  NOTA: 072 (micro colorscheme "simple") también quedó vivo — NO estaba en la lista del 086/088, así
  que fuera de alcance; está cerrado de hecho (074) y lo puedo archivar en una pasada futura si
  quieres. thread.md: 31 → 16 entradas; archive.md: 62 → 77.

PARTE B — PUSH DEL LOTE (autorizado). `git push origin main` del lote completo (10 commits):
076 (d11450e mahg-help htop/top+extras) + 082/081 (claim/reporte 076) + 084 (612b3da archivado +
herramienta) + 085 (claim) + 083 (a0628c3 --format md/--list) + 087/089 (claim/reporte 083) +
090 (claim 088) + reconciliación PARTE A (cfcbf10) + este reporte. verify
`git rev-list --left-right --count origin/main...HEAD` = 0 0. SIN tag ([Unreleased] acumula:
Go, micro, editor=micro, mahg-help expandido + extras + --format md/--list).

GATES (verde): tests/run.sh PASS; archivado idempotente (2ª corrida no-op) + sin pérdida (set de
bloques invariante); push verify 0 0. PÁRATE. 

ACCIÓN PROFESSOR: (1) decide sobre 048/049/050 (WT/WSL: archivar o seguir como nice-to-have v1.0.0);
(2) opcional, valida la tabla tui/util de la 089 y el `--format md`. El público se publica con
`scripts/publish-snapshot.sh` cuando cierres el ciclo (¿v0.6.0?).

### 093 · FROM executor→strategy · 2026-06-28 10:00 · status:fyi

NUEVA PLATAFORMA: **Android/Termux**, tercera plataforma junto a Debian y WSL (pedido directo del
PROFESSOR, no vía postoffice). Rama `feat/termux-platform`, NO pusheada, SIN commit (a la espera de
luz verde del PROFESSOR). 4 fases, todas verdes.

QUÉ SE HIZO:
- **Detección (`lib/detect.sh`):** nuevo `DETECT_PLATFORM` = `debian|wsl|termux` (única verdad que
  ramifican los módulos). Termux vía `$TERMUX_VERSION`/`/data/data/com.termux`, forzado headless;
  `DETECT_OS_PRETTY` razonable sin `/etc/os-release`. Helpers compartidos `is_termux()`/`is_wsl()`
  (este último unifica el `_is_wsl` que estaba duplicado en 96).
- **apt (`lib/apt.sh`):** confirmado/documentado que el path sin sudo/sin root de Termux ya es
  correcto (`SUDO=""`, `$PREFIX` escribible, `apt_can_use` pasa porque Termux trae `apt`).
- **La "nueva terminal" (`modules/10-terminal.sh`):** en Termux la terminal ES Termux (sin
  fontconfig, una sola `~/.termux/font.ttf`). Rama nueva `_install_termux_font`: baja JetBrainsMono
  Nerd Font → `font.ttf` + `termux-reload-settings`. Idempotente, dry-run honesto, offline-graceful.
- **Bootstrap Android (`modules/97-termux.sh`, nuevo, espejo de 96-mahg-wt):** estado de
  almacenamiento compartido + guía `termux-setup-storage` (no se auto-ejecuta: abre diálogo Android).
- **Gating (`install.sh`):** `platform_skip()` salta en Termux `80-gnome-terminal-profile`,
  `90-vscodium`, `96-mahg-wt` con motivo logueado + NOTE en el ledger; `--only` es escape hatch.
  En `50-git-docker-tui`, `lazydocker` se salta en Termux (no hay motor Docker en Android) pero
  `lazygit` y el resto se instalan. Usage de `install.sh` actualizado (lista + nota de plataforma).
- **Tests/docs:** `validate.sh` loguea `Platform:` (los 3 casos glow/bat/euporie son
  agnósticos y pasan en Termux); `test_gnome_profile.sh` YA auto-skipea sin dconf (caso Termux),
  sin cambio. README nueva §17 (Android/Termux) + §18 Publishing renumerada + facts de detección.
  CHANGELOG [Unreleased] entrada Added.

GATES (verde): `shellcheck -x -S style` clean; `tests/run.sh` → RESULT: PASS. Dry-run forzado
`TERMUX_VERSION=… ./install.sh --dry-run` muestra Platform: termux, skips correctos (80/96 + lazydocker),
97-termux corriendo, 10-terminal en rama Termux. Dry-run nativo Debian: sin skips espurios, rama GNOME
intacta. NOTA: validación VISUAL real en un teléfono Android la hace el PROFESSOR (mismo caso que la
validación WSL pendiente de 048/049/050 — relacionado: ambos son adaptación por plataforma).

ACCIÓN PROFESSOR: (1) valida en el teléfono y decide si commiteo/pusheo la rama `feat/termux-platform`;
(2) ¿esto + WT/WSL cierran el ciclo de plataformas para un bump (¿v0.6.0?)?

