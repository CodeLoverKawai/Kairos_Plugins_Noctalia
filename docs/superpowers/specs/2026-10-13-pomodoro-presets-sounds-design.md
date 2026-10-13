# Especificación de Diseño: Presets con Nombre y Sonidos Independientes (Pomodoro Pro)

**Fecha:** 2026-10-13  
**Estado:** Aprobado  

## 1. Resumen
Incorporar en el panel de `Pomodoro Pro` (`codeloverkawai/pomodoro`):
1. **Fila de Presets con Nombre**:
   - `[ Clásico ]`: 25 min trabajo / 5 min descanso corto / 15 min descanso largo.
   - `[ Deep ]`: 50 min trabajo / 10 min descanso corto / 30 min descanso largo.
   - `[ Ultra ]`: 90 min trabajo / 20 min descanso corto / 45 min descanso largo.
   - Permite alternar la configuración con 1 click directamente desde el panel sin abrir settings.
2. **Sonidos Independientes por Transición**:
   - `work_complete_sound_path`: sonido reproducible al finalizar la fase de trabajo (Work ➔ Break).
   - `break_complete_sound_path`: sonido reproducible al finalizar el descanso (Break ➔ Work o All Complete).
   - Opciones declaradas en `plugin.toml` y conmutables/observables a través del estado de Noctalia.

## 2. Arquitectura de Componentes

### 2.1 Panel UI (`src/panel.luau`)
- Se añade fila de botones de variantes entre la fila de configuración de sesiones y el contador principal:
  - Botones con `variant = "ghost"` o `"secondary"`, indicando visualmente el preset activo.
  - Al hacer click, envía comando `setPreset:clasico`, `setPreset:deep`, `setPreset:ultra` al servicio.
- Incremento de altura del panel en `plugin.toml` (de 295 a 335) para mantener la armonía visual sin solapamientos.

### 2.2 Servicio Central (`src/pomodoro.luau`)
- Manejo de comandos IPC `setPreset:<tipo>`:
  - Actualiza `config.workDuration`, `config.shortBreakDuration`, `config.longBreakDuration`.
  - Reconstruye `sessionData` y actualiza el tiempo restante si el temporizador está inactivo o pausado.
  - Emite el nuevo estado para reflejo reactivo en el panel.

### 2.3 Módulo de Audio (`src/sounds.luau`)
- Soporte para reproducir:
  - `sounds.playWorkComplete()`: Usa `config.workCompleteSoundPath` (fallback al sonido por defecto).
  - `sounds.playBreakComplete()`: Usa `config.breakCompleteSoundPath` (fallback al sonido por defecto).
- Ambos aprovechan la parada atómica con `/home/kairos/.local/bin/noctalia-audio-stop.sh`.

## 3. Plan de Verificación
1. **Verificación de Presets**:
   - Pulsar `[ Clásico ]` -> verificar que el contador cambia a 25:00.
   - Pulsar `[ Deep ]` -> verificar que el contador cambia a 50:00.
   - Pulsar `[ Ultra ]` -> verificar que el contador cambia a 90:00 (1:30:00).
2. **Verificación de Sonidos**:
   - Poner un intervalo corto de trabajo (ej. 5 seg), dejar que venza -> suena alarma de fin de trabajo.
   - Dejar que termine el descanso -> suena alarma de fin de descanso.
   - Pulsar reset -> la alarma se detiene instantáneamente.
