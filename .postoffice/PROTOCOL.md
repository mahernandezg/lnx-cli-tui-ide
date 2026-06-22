# Postoffice — canal STRATEGY-AGENT ⇄ EXECUTOR-AGENT

Canal asíncrono de coordinación operativa entre el agente de estrategia y el agente
ejecutor de este repo. NO es gobernanza: no reemplaza decisiones formales. Solo
coordinación día a día: handoffs, estado, preguntas, instrucciones.

## Ficheros
- `thread.md` — log append-only. Ambos agentes lo leen ENTERO al empezar y AÑADEN su
  mensaje al final. Newest abajo.

## Reglas
1. APPEND-ONLY. Nunca edites ni borres una entrada previa. Solo se añade al final.
2. Cada entrada lleva esta cabecera exacta:
   `### NNN · FROM <strategy→executor|executor→strategy> · <YYYY-MM-DD HH:MM> · status:<open|claimed|done|blocked|fyi>`
   NNN es correlativo de 3 dígitos.
3. status:open = espera respuesta del otro lado. claimed = un ejecutor la está trabajando.
   done = cerrado. blocked = parado, necesita al humano. fyi = informativo, no requiere respuesta.
4. El humano dispara cada run del ejecutor y revisa; ambos agentes escriben directamente
   en thread.md, sin relevo manual.
5. Ámbito: solo este repo.

## EXCLUSIÓN MUTUA — un solo ejecutor por tarea a la vez (CRÍTICO)
Para que dos ejecutores NO se pisen sobre el mismo repo:
1. Antes de trabajar una entrada `status:open` dirigida `strategy→executor`, el ejecutor
   PRIMERO añade una entrada de RECLAMO al final del thread:
   `### NNN · FROM executor→strategy · <fecha hora> · status:claimed` con el texto
   "RECLAMO la tarea <00X>. Empiezo a trabajarla." y la commitea+pushea INMEDIATAMENTE
   (commit pequeño solo del thread) ANTES de tocar código.
2. Al INICIO de cada run, tras leer el thread: si la tarea que ibas a tomar ya tiene un
   RECLAMO `status:claimed` SIN su correspondiente reporte `done` posterior, NO la tomes —
   está en manos de otro ejecutor. Pasa a la siguiente `open` no reclamada, o si no hay,
   reporta "sin tareas libres" y para.
3. Al terminar, añade tu reporte `executor→strategy` con `status:done` (o el que aplique).
   Eso libera la tarea.
4. Si encuentras una tarea ya `done` o `claimed` por otro: NO la repitas. Si quieres, verifica
   de forma independiente y reporta, pero NUNCA dupliques commits.

Regla simple: RECLAMA-y-pushea antes de trabajar; respeta los reclamos ajenos.

## Para el EXECUTOR-AGENT (standing instruction)
Al INICIO de cada run: lee `.postoffice/thread.md` entero. Toma SOLO la primera entrada
`status:open` dirigida `strategy→executor` que NO esté ya reclamada (ver EXCLUSIÓN MUTUA).
Recláma­la (push inmediato), trabájala, y al FINAL añade tu reporte `executor→strategy` con
su status.

## ARCHIVADO — thread.md solo VIVO; cerradas → archive.md
El thread crece sin límite. Para que cada lectura sea ligera, las tareas CERRADAS se mueven a
`.postoffice/archive.md`; `thread.md` queda solo con lo VIVO.

- **Se MANTIENE en thread.md (vivo):** `status:open` no cumplidas (pendientes), `status:claimed`
  sin su `done`, y `status:fyi` (referencia vigente — nunca se archiva).
- **Se ARCHIVA (a archive.md, íntegro y en orden cronológico):** cada ciclo de tarea CERRADO —
  la tarea + su(s) claim(s) + su reporte `status:done`. Una tarea está "cerrada" cuando un reporte
  `status:done` la completa.
- **Herramienta:** `bin/postoffice-archive` (idempotente). `--dry-run` muestra el plan sin tocar
  nada; sin flag aplica (hace BACKUP `thread.md.bak.<ts>` antes de reescribir). Verifica SIN
  PÉRDIDA (el conjunto de bloques thread+archive es invariante; aborta si no cuadra). Es
  CONSERVADOR: ante duda NO archiva (mejor una entrada de más en thread que perder/malclasificar).
  Por eso un ciclo "hecho en código" pero sin reporte `done` formal se mantiene hasta que se cierre.
- **Cuándo correrlo:** bajo demanda cuando el thread crezca, y/o tras cerrar tareas (`done`). En
  este repo el orden es cronológico ASCENDENTE (lo nuevo al final); el script lo respeta.
