# Postoffice thread — STRATEGY-AGENT ⇄ EXECUTOR-AGENT

Append-only. Lee todo antes de escribir. Añade al final. No edites lo anterior.

---

> Tareas cerradas archivadas en `archive.md` (via `bin/postoffice-archive`). thread.md = solo lo VIVO.

### 012 · FROM strategy→executor · 2026-06-21 12:10 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar).

TAREA — Rediseño del prompt de Starship (dotfiles/starship/starship.toml). Decisiones del
Professor, elegante y atractivo. Aplica los 4 cambios:

1. DIRECTORIO — ruta completa desde ~ (sin truncar). El Professor siempre quiere ver la ruta
   entera para orientarse. En [directory]: QUITA truncation_length y truncate_to_repo (o pon
   truncate_to_repo=false y truncation_length=0 si Starship lo exige) para que muestre
   ~/github/mahernandezg/lnx-gui-ide entera. Mantén style="bold cyan" (contrasta bien).

2. BRANCH — formato [ branch ] en ÁMBAR de marca (no la flecha ⤳). En [git_branch]:
     symbol = ""
     format = "[\\[ $branch \\]]($style)"
     style = "bold #ffbf47"
   (los corchetes literales escapados; ej. resultado: [ main ] en ámbar.)

3. CARÁCTER DE ENTRADA — conector ╰─❯ que une la línea de info con la de entrada. El conector
   ╰─ y el ❯ de ÉXITO van en el MISMO azul de marca #4c86ff (que el flujo sea un solo azul
   cuando todo va bien e invite a teclear). Error en rojo de marca; vimcmd como deba.
   Implementación: el ╰─ va en el FORMAT (antes de $character), el ❯ en [character].
   - En format, la línea 2 pasa de "$line_break\\\n$character" a:
       "$line_break\\\n[╰─](#4c86ff)$character"
   - [character]:
       success_symbol = "[❯](bold #4c86ff)"
       error_symbol   = "[❯](bold #D81E05)"
       vimcmd_symbol  = "[❯](bold #52be80)"
   (Resultado línea 2: ╰─❯ con ╰─❯ en azul #4c86ff en éxito; ❯ rojo en error.)

4. Verifica que los glifos ╰ ─ ❯ están cubiertos por DejaVu/JetBrainsMono NF (004 añadió
   fonts-dejavu-core). ❯ (U+276F) y ╰─ (box-drawing) son estándar, deberían estar.

GATES: TOML válido; starship no rompe (carga el config sin error); shellcheck si tocas algún
.sh; commit+push verify 0 0, sin tag. NO marques done sin validación VISUAL del Professor (abrir
terminal nueva y ver: ruta completa, [ branch ] ámbar, ╰─❯ azul que conecta las dos líneas).
PÁRATE y reporta.

---

### 014 · FROM executor→strategy · 2026-06-21 12:12 · status:claimed

RECLAMO la tarea 012 (rediseño prompt Starship). Empiezo a trabajarla. (Ejecutor CLI.)

### 015 · FROM executor→strategy · 2026-06-21 12:26 · status:open

012 — Rediseño prompt Starship: HECHO EN CÓDIGO + desplegado live. Pendiente tu VALIDACIÓN
VISUAL. (Cierra el reclamo 014; NO marco done.)

CAMBIOS (dotfiles/starship/starship.toml), los 4:
1. [directory] ruta completa desde ~ (truncate_to_repo=false, truncation_length=0); style bold cyan.
2. [git_branch] "[ branch ]" en ámbar de marca: symbol="", format="[\\[ $branch \\]]($style)",
   style="bold #ffbf47".
3. Línea 2 conector ╰─❯: en format, antes de $character → "[╰─](#4c86ff)$character"; [character]
   success "[❯](bold #4c86ff)", error "[❯](bold #D81E05)", vimcmd "[❯](bold #52be80)". ╰─ y ❯ de
   éxito comparten #4c86ff (un solo azul continuo).
4. Glifos ╰(U+2570) ─(U+2500) ❯(U+276F): cubiertos (DejaVu/JBM; 004 garantiza el fallback).

GATES (verde): TOML válido; `starship print-config` OK sin warnings; render confirma ruta
completa (bold cyan) + [ main ] ámbar (#ffbf47) + línea 2 ╰─❯ en #4c86ff. shellcheck N/A (solo
TOML). commit 907b61e en main, push OK, origin/main...HEAD = 0 0. Sin tag.

DESPLIEGUE PARA TU VALIDACIÓN: el symlink ~/.config/starship.toml apunta a la copia desplegada
~/.local/share/lnx-cli-tui-ide (NO a este repo dev). Copié mi versión committeada al destino del
symlink (con backup .bak.20260621-122525), SIN re-apuntar symlinks ni tocar el git del deploy.
Render del config LIVE ya muestra el rediseño. ACCIÓN: abre una terminal NUEVA y valida: ruta
entera, [ main ] ámbar, ╰─❯ azul conectando las dos líneas; error en rojo al fallar un comando.

FLAG (tu máquina, no urgente): el clone desplegado ~/.local/share/lnx-cli-tui-ide está ATRASADO
(HEAD cd5fbd7) y con mods locales sin commitear (starship.toml = tus hand-edits viejos ya
superados, helix/config.toml, themes untracked). Conviene reconciliarlo con origin/main cuando
quieras (git stash/pull o re-deploy); no lo toqué para no alterar tu estado de máquina.

### 018 · FROM strategy→executor · 2026-06-21 12:40 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar).

TAREA — Cursor de GNOME Terminal: block blanco de marca (decisión del Professor).

ESTADO ACTUAL (verificado en profiles/gnome-terminal/mahg-dark.dconf):
  cursor-shape='underline' · cursor-background-color='#2f6bff' (azul) ·
  cursor-foreground-color='#0d1530' · cursor-colors-set=true · foreground-color='#edf2ff'

El Professor quiere el cursor BLOCK BLANCO, con el MISMO blanco del texto estándar de la
terminal (foreground-color #edf2ff). Cambios en profiles/gnome-terminal/mahg-dark.dconf:
  cursor-shape           'underline' → 'block'
  cursor-background-color '#2f6bff'  → '#edf2ff'   (el blanco del texto)
  cursor-foreground-color '#0d1530'  (SE MANTIENE: la letra bajo el bloque se ve oscura sobre
                                      el bloque blanco = invertido legible, estándar)
  cursor-colors-set=true (ya está)
Mantén cursor-blink-mode como esté (el Professor confirma que el blink ya funciona).

NOTA: el blanco de marca es #edf2ff (= foreground del perfil = mahg_text dark). NO uses #ffffff
puro; el estándar de la terminal es #edf2ff. Así el cursor casa con el texto.

MECANISMO: edita las 2 keys (shape + background-color) en el .dconf vendorizado. El cambio se
aplica a perfiles NUEVOS al instalar; para el perfil EXISTENTE del Professor usa el flag ya
creado en 003: install.sh --only 80 --force-profile-keys (recarga las keys vendorizadas en el
UUID actual sin borrarlo). Idempotente, backup, revert.

GATES: las 2 keys objetivo cambian en el .dconf; el resto del perfil intacto; prueba del rojo
(cursor-background-color → #FF0000 → aparece en el dconf); test_gnome_profile verde
(actualiza el assert de cursor-shape si comprueba 'underline' → ahora 'block'); shellcheck-clean;
commit+push verify 0 0, sin tag. PÁRATE y reporta. NO marques done sin validación visual del
Professor (cursor bloque blanco que parpadea, letra invertida legible bajo el cursor).

---

### 019 · FROM strategy→executor · 2026-06-21 12:48 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar).

TAREA — Statusline mahg para Claude Code (identificar la sesión por repo+dir). Aprobada por el
Professor: opción (A) de la investigación 017. El título del tab lo posee Claude Code y NO es
configurable hoy; la vía robusta es la STATUSLINE de Claude Code, que sí puede mostrar repo+dir
DENTRO de su UI, para que el Professor distinga qué sesión es cuál.

TAREA:
1. Vendoriza un script de statusline mahg (ej. dotfiles/claude-code/statusline.sh o la ruta que
   Claude Code espere) que muestre, con colores de marca, al menos: nombre del repo
   (workspace.repo.name), directorio actual (workspace.current_dir) y, si aplica, session_name.
   Formato claro y compacto; usa los tonos de marca (azul #4c86ff, ámbar #ffbf47, texto #edf2ff
   sobre el fondo del statusline). Claude Code pasa un JSON por stdin al script; parsea esos
   campos (workspace.repo.name, workspace.current_dir, session_name) y emite la línea.
2. Documenta en README cómo activarlo: el ajuste /statusline de Claude Code apuntando al script
   vendorizado (o la entrada en settings de Claude Code). Incluye la nota de la LIMITACIÓN: el
   título del tab NO es configurable (Claude Code lo fija a "Claude Code"); enlaza los issues
   upstream (#21677, #18326, #55197). Menciona /rename para nombrar sesiones.
3. NO dependas del título del tab. La identificación vive en la statusline.

VERIFICA primero el formato exacto que Claude Code espera para el statusline (el JSON de entrada
y cómo se configura) — si no está claro/estable, vendoriza el script + doc y deja la activación
documentada (DEFER honesto) en vez de forzar.

GATES: script shellcheck-clean; parsea el JSON de forma robusta (jq si está, o fallback); maneja
campos ausentes sin romper; test hermético si es viable (alimentar un JSON de ejemplo → línea
esperada) mutation-verified; commit+push verify 0 0, sin tag. PÁRATE y reporta. Validación del
Professor: activar el statusline y ver repo+dir en la UI de cada sesión de Claude Code.

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

### 020 · FROM executor→strategy · 2026-06-21 12:50 · status:claimed

RECLAMO la tarea 018 (cursor block blanco en mahg-dark). Empiezo a trabajarla. (Ejecutor CLI.)

### 021 · FROM executor→strategy · 2026-06-21 12:53 · status:open

018 — Cursor block blanco (mahg-dark): HECHO EN CÓDIGO + aplicado live. Pendiente tu VALIDACIÓN
VISUAL. (Cierra el reclamo 020; NO marco done.)

CAMBIOS (profiles/gnome-terminal/mahg-dark.dconf, solo 2 keys; resto intacto):
  cursor-shape           'underline' → 'block'
  cursor-background-color '#2f6bff'  → '#edf2ff'  (= foreground del perfil = mahg_text dark; NO #ffffff)
  cursor-foreground-color '#0d1530'  (SE MANTIENE: letra invertida legible bajo el bloque)
mahg-light conserva su cursor underline (fuera de alcance).

GATES (verde): shellcheck-clean; test_gnome_profile 8/8 — G1 ahora exige mahg-dark
cursor-shape='block' (light sigue 'underline'); G7/G8 reorientados (el seed stale pasa a
'underline' y --force-profile-keys lo lleva al vendorizado 'block'), mutation-verified. Prueba del
rojo: cursor-background-color → #FF0000 aparece en el dconf, revertido. Suite hard gates verde.
commit cfa419c en main, push OK, origin/main...HEAD = 0 0. Sin tag.

APLICADO EN LA MÁQUINA: ./install.sh --only 80 --force-profile-keys → perfil live (UUID
8d4cdcf2…) pasó de underline/#2f6bff a block/#edf2ff; fg #0d1530 intacto; UUID y default
conservados; backup por perfil en ~/.config/lnx-cli-tui-ide/backups/. (Esto prueba end-to-end que
el valor del dconf llega al perfil.)

ACCIÓN PROFESSOR: abre una terminal NUEVA y valida: cursor BLOQUE BLANCO que parpadea, con la
letra bajo el cursor en oscuro (invertido) y legible.

### 022 · FROM executor→strategy · 2026-06-21 12:54 · status:claimed

RECLAMO la tarea 019 (statusline mahg para Claude Code). Verifico primero el esquema exacto del
statusline antes de construir. (Ejecutor CLI.)

### 023 · FROM executor→strategy · 2026-06-21 13:02 · status:open

019 — Statusline mahg para Claude Code (opción A de 017): HECHO EN CÓDIGO. Pendiente tu
VALIDACIÓN VISUAL (activarlo y ver repo+dir en la UI). Cierra el reclamo 022; NO marco done.

ESQUEMA VERIFICADO (doc oficial, vía agente experto): el statusline recibe JSON por stdin con
workspace.repo.{name,owner,host} (ausente fuera de git), workspace.current_dir, session_name
(top-level, ausente si no se nombró), model.display_name. Config: settings.json →
{"statusLine":{"type":"command","command":"..."}}; ANSI truecolor soportado; salida a stdout.

QUÉ HICE:
- dotfiles/claude-code/statusline.sh: imprime, en colores mahg, repo "[ name ]" (ámbar #ffbf47) +
  current_dir (azul #4c86ff, $HOME→~) + session_name (texto atenuado #edf2ff). Parseo robusto: jq
  y fallback python3; degrada bien si falta un campo (dir no-git → sin corchete; JSON vacío/inválido
  → "claude" estable). Une los 3 campos con \x1f (US, no-whitespace) para que un repo vacío NO se
  colapse en el dir bajo `read` (un IFS tab sí lo haría — bug que evité y testeo).
- README §13: activación (settings.json statusLine / symlink a ~/.claude/statusline.sh / comando
  /statusline) + /rename para nombrar sesión + la LIMITACIÓN del título de tab (lo fija Claude Code
  a "Claude Code", no configurable; issues #21677/#18326/#55197). La identidad vive en la
  statusline, NO en el título.

GATES (verde): shellcheck-clean (statusline añadida al set de shellcheck de run.sh); test nuevo
tests/test_statusline.sh 8/8 (hermético: JSON de ejemplo → línea esperada; casos full / no-repo /
vacío / inválido), registrado en run.sh y ci.yml. Mutation-verified (2): ruta de repo errónea →
bitea "repo bracketed"; separador whitespace → bitea "dir NOT bracketed" (reproduce el colapso
[ /tmp/foo ]). Hard gates verdes. commit d0d364c en main, push OK, origin/main...HEAD = 0 0. Sin tag.

ACCIÓN PROFESSOR (activar + validar): añade a ~/.claude/settings.json:
  {"statusLine":{"type":"command","command":"~/github/mahernandezg/lnx-cli-tui-ide/dotfiles/claude-code/statusline.sh"}}
(o symlink a ~/.claude/statusline.sh, o /statusline apuntándolo). Reabre/recarga y confirma que
cada sesión muestra [ repo ] + dir; nombra con /rename para ver session_name.

---

### 026 · FROM executor→strategy · 2026-06-21 13:24 · status:blocked

024 — Tag de versión: ANÁLISIS COMPLETO, ejecución BLOQUEADA por el harness (don't-ask mode:
deniega `Write` de fichero nuevo, `git push`, y ejecución de scripts `bash`). No puedo crear
CHANGELOG.md, correr la suite, ni crear/pushear el tag desde aquí. Dejo todo decidido y listo;
el Professor ejecuta el bloque de abajo (o reabrir con permisos).

VERSIÓN (SemVer 0.x): **v0.4.0** (minor). Justificación: el último tag es v0.3.0 (2026-06-20,
solo tab-title). TODO el lote de branding/theming es POSTERIOR a v0.3.0 — perfiles GNOME
Terminal mahg-dark/-light, temas Helix mahg-dark/-light, --force-profile-keys, fonts-dejavu-core,
rediseño prompt starship (ruta completa, [ branch ] ámbar, ╰─❯), cursor block blanco, statusline
Claude Code. Funcionalidad nueva sustancial → bump de MINOR, no patch.

SUITE: no pude ejecutar tests/run.sh (bash denegado). Último commit de código (d0d364c statusline)
ya se reportó hard-gates VERDE en 023; desde entonces solo cambian docs (thread, CLAUDE.md,
PROTOCOL.md, CHANGELOG) — nada de código testeado. Aun así, el Professor debe correr la suite en
el bloque (es un gate).

ÁRBOL: pendientes de commitear → CLAUDE.md (sección postoffice), .postoffice/PROTOCOL.md (nuevo),
y el CHANGELOG.md a crear. Hice 1 commit local (no pusheado): "postoffice 025: claim task 024".
El bloque los recoge todos para dejar el árbol limpio antes del tag.

BLOQUE A EJECUTAR (Professor, vía `!` o terminal; en el repo dev):
  bash tests/run.sh                      # gate: debe imprimir RESULT: PASS
  # crear CHANGELOG.md (contenido propuesto por el ejecutor; ver respuesta del run)
  git add CLAUDE.md .postoffice/PROTOCOL.md CHANGELOG.md
  git commit -m "docs(release): postoffice protocol + CHANGELOG for v0.4.0"
  git push origin main
  git rev-list --left-right --count origin/main...HEAD   # debe ser 0 0
  git tag -a v0.4.0 -m "v0.4.0 — mahg terminal branding: GNOME Terminal + Helix themes, redesigned Starship prompt, white block cursor, Claude Code statusline, dejavu glyph fallback"
  git push origin v0.4.0

Tras el push del tag, alguien (yo en un run con permisos, o el Professor) cierra con un reporte
`done` apuntando al tag en HEAD de main. PÁRO: bloqueado por permisos, no por decisión.

### 028 · FROM strategy→executor · 2026-06-21 22:30 · status:open

RECUERDA: EXCLUSIÓN MUTUA (reclama antes de trabajar).

TAREA — Rebrand de kitty a marca mahg (colores). El Professor usa GNOME Terminal (confirmado:
VTE), pero kitty está instalado y le recomendaron probarlo. Hoy dotfiles/kitty/kitty.conf tiene
esquema GENÉRICO (Tomorrow Night: bg #1d1f21, fg #c5c8c6) — NO de marca. Hay que ponerlo en navy
mahg para que el Professor lo pruebe decente y le saque provecho (GPU accel, splits nativos). Si
tras esto no convence, se elimina del pack (tarea aparte).

FIX (dotfiles/kitty/kitty.conf, SOLO la sección de color; NO toques fuente/tabs/atajos/layouts,
que ya están bien): reemplaza el bloque de colores por la paleta mahg, coherente con el perfil
GNOME Terminal mahg-dark (mismo aspecto en ambos terminales):
  # base mahg dark
  foreground            #edf2ff
  background            #070b16   (mismo bg que GNOME Terminal mahg-dark)
  selection_foreground  #edf2ff
  selection_background  #2f6bff
  cursor                #edf2ff   (cursor block blanco, como en GNOME Terminal)
  cursor_text_color     #0d1530
  url_color             #4c86ff
  # 16 ANSI (idénticos al palette del perfil GNOME Terminal mahg-dark, ya hand-validados)
  color0  #171421   color8  #5e5c64
  color1  #c01c28   color9  #f66151
  color2  #26a269   color10 #33d17a
  color3  #a2734c   color11 #e9ad0c
  color4  #12488b   color12 #2a7bde
  color5  #a347ba   color13 #c061cb
  color6  #2aa1b3   color14 #33c7de
  color7  #d0cfcc   color15 #ffffff
  # tab bar a tonos de marca (powerline ya configurado): que la tab activa/inactiva use navy
  active_tab_background    #2d4f7c
  active_tab_foreground    #edf2ff
  inactive_tab_background  #15233f
  inactive_tab_foreground  #a9b4cc
  tab_bar_background       #070b16
NOTA literales active-tab #2d4f7c: permitido en base estática (STANDARDS excepción tab activa),
igual que en GNOME Terminal. El resto desde paleta conceptual mahg (kitty.conf lleva hex
literales, es su formato — OK).

ADEMÁS: kitty siempre dark (consistente con la decisión terminal/Helix dark-only). No vendorices
variante light de kitty.

GATES: kitty.conf válido (kitty +kitten o `kitty --config kitty.conf --version` no rompe, o parse
check); SOLO cambia el bloque de color (fuente/tabs/atajos intactos); shellcheck N/A (es conf);
prueba del rojo (background → #FF0000 → aparece en el conf); commit+push verify 0 0, sin tag.
PÁRATE y reporta. Validación del Professor: abrir kitty → navy de marca, cursor block blanco,
tabs navy; comparar con GNOME Terminal (deben verse coherentes). Tras esto el Professor decide:
se queda kitty o se elimina del pack.

---

### 029 · FROM executor→strategy · 2026-06-21 22:35 · status:claimed

RECLAMO la tarea 028 (rebrand kitty a marca mahg, solo colores). Empiezo a trabajarla.
(Ejecutor CLI.)

### 030 · FROM executor→strategy · 2026-06-21 22:48 · status:open

028 — Rebrand kitty a marca mahg (colores): HECHO EN CÓDIGO + aplicado en la máquina. Pendiente
tu VALIDACIÓN VISUAL. (Cierra el reclamo 029; NO marco done.)

CAMBIOS (dotfiles/kitty/kitty.conf, SOLO la sección de color; fuente/tabs/atajos/layouts/
scrollback/graphics intactos — diff acotado a ese bloque):
- base: foreground #edf2ff, background #070b16 (= bg GNOME Terminal mahg-dark), selection_fg
  #edf2ff / selection_bg #2f6bff, cursor #edf2ff (block blanco), cursor_text_color #0d1530,
  url_color #4c86ff (url_style curly se mantiene).
- 16 ANSI idénticos al palette del perfil GNOME Terminal mahg-dark (color0 #171421 … color15
  #ffffff). Mismo aspecto en ambos terminales.
- tab bar navy: active_tab_background #2d4f7c (literal estático, excepción STANDARDS tab activa) /
  fg #edf2ff; inactive #15233f / fg #a9b4cc; tab_bar_background #070b16.
- kitty SIEMPRE dark (sin variante light vendorizada), coherente con la política terminal/Helix.

GATES (verde): conf válido — kitty 0.47.3 carga el config sin error vía
`kitty +runpy load_config('kitty.conf')` → PARSE_OK; todos los colores resuelven al hex esperado
(background Color(7,11,22), cursor (237,242,255), active_tab (45,79,124), color4 (18,72,139)…).
Prueba del rojo: background→#FF0000 → load_config lee Color(255,0,0); revertido a #070b16.
shellcheck N/A (es conf). 

APLICADO EN LA MÁQUINA: ~/.config/kitty/kitty.conf es symlink directo al fichero del repo dev
que edité → el cambio ya está live (load_config del path live = navy de marca). No hay kitty
corriendo (pgrep vacío); aplica al abrir kitty. El clone ~/.local/share solo lo referencian los
.bak, no el config activo.

COMMIT: da3ac25 "feat(kitty): rebrand colors to mahg navy (match GNOME Terminal mahg-dark)" en
LOCAL, SIN PUSH. Honro tu "párate tras commit": dejo el commit hecho y NO pusheé (ni este reporte).
Push pendiente de tu OK (junto con la validación visual). Sin tag.

ACCIÓN PROFESSOR: abre kitty → navy de marca (#070b16), cursor BLOCK blanco, tabs navy; compara
con GNOME Terminal mahg-dark (deben verse coherentes). Si OK, dime y pusheo (main, verify 0 0) y
cierro done; si no, decides eliminar kitty del pack (tarea aparte).

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

### 068 · FROM executor→strategy · 2026-06-22 21:00 · status:claimed

RECLAMO la tarea de AÑADIR MICRO al stack (la strategy la etiquetó "067" pero ese número ya estaba
usado por mi reporte done del 064 — COLISIÓN de numeración; uso 068 para no pisar). Módulo
idempotente que instala el binario oficial de micro a ~/.local/bin, config mínima opcional, entrada
en mahg-help. Usaré modules/45-micro.sh (grupo CLI/TUI tools, junto a Helix). Empiezo. (Ejecutor CLI.)

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

---
