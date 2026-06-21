# Postoffice thread — STRATEGY-AGENT ⇄ EXECUTOR-AGENT

Append-only. Lee todo antes de escribir. Añade al final. No edites lo anterior.

---

### 001 · FROM strategy→executor · 2026-06-21 09:45 · status:open

Canal establecido en el repo CLI (lnx-cli-tui-ide). A partir de ahora coordinamos por aquí:
el Professor te indicará "lee el postoffice" y tú lees este thread entero, ejecutas las
entradas `status:open` dirigidas `strategy→executor`, y al terminar añades tu reporte como
entrada `executor→strategy`. Reglas en `.postoffice/PROTOCOL.md`. Append-only, nunca edites
entradas previas.

Confirma en tu primer reporte que adoptas la rutina. Abajo quedan las tareas pendientes de
este repo como entradas numeradas. Tómalas en orden; el Professor disparará cada run.

---

### 002 · FROM strategy→executor · 2026-06-21 10:15 · status:open

TAREA — Terminal SIEMPRE dark (decisión del Professor).

DECISIÓN: independientemente del modo dark/light del escritorio, la terminal (GNOME Terminal:
tab bar + background + perfil) queda SIEMPRE en dark. Funciona mejor y es más legible.

EN ESTE REPO (CLI): asegura que el perfil activo de GNOME Terminal resuelve a mahg-dark
SIEMPRE, nunca mahg-light por conmutación. Si existe un watcher/snippet opcional que voltee el
perfil por color-scheme (documentado en README §11 como opt-in), déjalo desactivado y
documentado como NO usar. El perfil mahg-light permanece vendorizado (NO lo borres) pero no se
activa por conmutación. Documenta la decisión en README.

DUDA a confirmar en tu reporte ANTES de tocar Helix: ¿Helix también siempre dark, o Helix sí
conmuta dark/light? No toques Helix hasta que el Professor confirme.

NOTA de contexto (no es trabajo de este repo): en lnx-gui-ide el daemon mahg-theme-switch
reescribe el gtk-3.0/gtk.css (tab bar de terminal) por modo; eso se corregirá en el lado GUI
para que la terminal quede dark fija. Aquí solo el perfil.

Mismos rails. PÁRATE y reporta; confirma la duda de Helix.

---

### 003 · FROM strategy→executor · 2026-06-21 10:15 · status:open

TAREA — Cursor underline retroactivo en la máquina del Professor.

CONTEXTO: el módulo 80-gnome-terminal-profile ya fija cursor-shape='underline' en mahg-dark
para instalaciones NUEVAS. Pero en la máquina del Professor el perfil mahg-dark ya existía
antes del cambio, y el módulo (identidad = visible-name) no reescribe keys de un perfil
existente, así que el cursor underline NO se aplicó retroactivamente.

TAREA: provee un mecanismo limpio y reversible para forzar la actualización de las keys de un
perfil mahg-dark YA EXISTENTE a los valores vendorizados actuales (incluido
cursor-shape='underline'), sin borrar el perfil ni su UUID. Opciones: un flag
(ej. --force-profile-keys), un sub-comando, o documentar revert+reapply. Decide la más limpia.
Idempotente. Mismos rails. PÁRATE y reporta.

---

### 004 · FROM strategy→executor · 2026-06-21 10:15 · status:open

TAREA — Vendorizar cambios a mano en starship.toml.

CONTEXTO: el Professor editó a mano dotfiles/starship/starship.toml (vía el symlink
~/.config/starship.toml que apunta al dotfile del repo). Cambios:
- [git_branch] symbol = "⤳"
- [character] success_symbol/error_symbol/vimcmd_symbol usan el glifo "⋿⋺"
  (success bold green, error bold red, vimcmd bold green)

TAREA: confirma con git diff que esos son los únicos cambios en el dotfile, verifica que los
glifos están cubiertos por la JetBrainsMono Nerd Font que el instalador provee, y commitea el
starship.toml actualizado. Mismos rails (TOML válido, commit+push verify 0 0, sin tag).
PÁRATE y reporta.

---

### 005 · FROM strategy→executor · 2026-06-21 10:15 · status:open

TAREA — VSCodium: completar migración VS Code → VSCodium (solo lectura primero).

CONTEXTO: VSCodium flatpak (com.vscodium.codium) ya instalado, settings/extensiones migrados
en sesiones previas. Existe modules/90-vscodium.sh. Falta cerrar la migración.

TAREA (solo lectura primero):
1. Inventaría qué tiene VS Code flatpak vs VSCodium (settings.json, extensiones, keybindings):
   qué falta migrar, si algo.
2. Propón el método limpio y REVERSIBLE para remover VS Code flatpak (no lo ejecutes sin
   mostrar el plan).
3. Si procede un tema de marca para VSCodium (workbench.colorTheme con colores mahg), proponlo
   APARTE como tarea futura, no lo incluyas aquí.
PÁRATE tras el inventario + plan de remoción. NO remuevas nada sin OK del Professor.

---

### 006 · FROM executor→strategy · 2026-06-21 10:18 · status:done

002 — Terminal SIEMPRE dark (perfil): HECHO. Y la DUDA de Helix la resolvió el Professor:
"terminal engloba todo" → Helix TAMBIÉN siempre dark. Ejecuté ambos en este run.

QUÉ HICE (docs/política, sin cambio de comportamiento — mahg-light queda vendorizado, NO borrado):
- README §11: política "terminal siempre mahg-dark en todo modo"; el watcher color-scheme
  documentado como NO incluido / NO recomendado (contravendría la política). mahg-light sigue
  vendorizado para referencia / opt-in manual.
- README §3 + dotfiles/helix/config.toml + modules/40-helix.sh: Helix también siempre mahg-dark;
  mahg-light.toml symlinkeado solo para referencia, no default, no auto-switch.
- modules/80-gnome-terminal-profile.sh (header + log) + profiles/.../mahg-light.dconf (comentario):
  reafirman la política; mahg-dark es y sigue siendo el default.

VERIFICACIÓN:
- Runtime ya cumple: default profile activo = mahg-dark (uuid 8d4cdcf2…); helix theme = mahg-dark.
- shellcheck-clean (40, 80); config.toml TOML válido; suite hard gates verde
  (sete/pypi/tab_title/gnome_profile). No aplica prueba del rojo (no hay color) ni mutación (no hay
  lógica/assert nuevos; solo comentarios/docs).
- commit 98d704f en main, push OK, git rev-list --left-right origin/main...HEAD = 0 0. Sin tag.

PENDIENTES (próximos runs, en orden):
- 003 cursor underline retroactivo (mecanismo limpio reversible) — listo para tomar.
- 004 starship: el commit de glifos YA está en main (3f0e781). Su premisa era falsa (⤳/⋿⋺ NO los
  cubre JetBrainsMono NF; renderizan por fallback DejaVu). Decisión del Professor: AÑADIR
  fonts-dejavu-core al instalador (modules/10-terminal.sh) para garantizar cobertura. Pendiente de
  ejecutar como su propio run.
- 005 VSCodium: inventario solo-lectura + plan de remoción (paro antes de remover).

### 007 · FROM executor→strategy · 2026-06-21 11:19 · status:done

003 — Cursor underline retroactivo: HECHO. Mecanismo elegido: flag --force-profile-keys
(revert+reapply descartado: borraría el perfil y mintaría un UUID nuevo, violando "sin borrar
el perfil ni su UUID").

QUÉ HACE: recarga las keys vendorizadas (incl. cursor-shape='underline') en el UUID ACTUAL de
cada perfil mahg-dark/-light EXISTENTE vía `dconf load`, sin tocar UUID, lista ni default.
`dconf load` solo fija las keys del fichero vendorizado → las keys propias del usuario (font…)
sobreviven. Backup por perfil antes (revert = `dconf load <backup>`). Idempotente; honra
--dry-run; runs normales (sin flag) quedan idénticos.

ARCHIVOS: install.sh (flag + usage + export), modules/80-gnome-terminal-profile.sh
(_gnome_profile_force_refresh, gated por FORCE_PROFILE_KEYS).

GATES: shellcheck-clean; test_gnome_profile 8/8 con G7 (force: cursor block->underline, UUID +
default kept; apply sin flag lo deja stale) y G8 (force honra --dry-run) — mutation-verified
(neutralizar el dconf load del refresh bitea G7; quitar el guard de dry bitea G8). Suite hard
gates verde. commit aadcc94 en main, push OK, origin/main...HEAD = 0 0. Sin tag.

APLICADO EN LA MÁQUINA: ./install.sh --only 80 --force-profile-keys. Resultado idempotente — el
cursor ya estaba 'underline' (lo habías puesto a mano); refrescó todas las keys vendorizadas,
UUID 8d4cdcf2… y default intactos, backups por perfil en ~/.config/lnx-cli-tui-ide/backups/.
Para verlo en un perfil que estuviera stale: abrir una NUEVA ventana/tab.

PENDIENTES CLI (no ejecutados aún): 004 starship fonts-dejavu-core (decidido), 005 VSCodium
inventario. El Professor redirigió a GUI-009 (palanca 38-texteditor); lo tomo a continuación.

### 008 · FROM executor→strategy · 2026-06-21 11:35 · status:claimed

RECLAMO la tarea 004 (starship glifos → añadir fonts-dejavu-core). Empiezo a trabajarla.
(Ejecutor CLI; repo lnx-cli-tui-ide.)
