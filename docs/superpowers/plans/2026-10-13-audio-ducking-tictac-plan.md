# Implementación de Audio Ducking (145%), Loop Inmediato y Cuenta Regresiva Tic-Tac (15s)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar en los plugins `timer` y `pomodoro` un sistema de alarma con loop inmediato sin silencios largos, audio ducking que eleva el volumen maestro al 145% y restaura el volumen original al detenerse, y sonido rítmico de tic-tac en los últimos 15 segundos.

**Architecture:** Módulo/función común para gestión segura de volumen maestro vía `wpctl` con persistencia de volumen previo en `/tmp/noctalia_audio_orig_vol`. Reproducción de alarma en bucle inmediato con corte limpio al recibir pausa/reseteo/parada.

**Tech Stack:** Luau, Shell script (`wpctl`, `pw-play`, `paplay`, `ffplay`), Noctalia Shell API.

## Global Constraints
- No dejar procesos huérfanos de reproducción en segundo plano.
- Siempre restaurar el volumen del sistema si se interrumpe la alarma.
- Mantener compatibilidad con la API de Noctalia.

---

### Task 1: Timer Sound - Audio Ducking y Loop Inmediato
**Files:**
- Modify: `timer/timer-sound/service.luau`

- [ ] **Paso 1: Implementar funciones seguras de volumen en service.luau**
  - Guardar volumen original en `/tmp/noctalia_timer_orig_vol` usando `wpctl get-volume @DEFAULT_AUDIO_SINK@`.
  - Aplicar `wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.45`.
  - Al ejecutar `stopSound()`, restaurar volumen original y limpiar `/tmp/noctalia_timer_orig_vol`.

- [ ] **Paso 2: Optimizar loop de alarma inmediata**
  - Usar loop continuo sin delay en subshell para `alarm.mp3`.

- [ ] **Paso 3: Verificar sintaxis y ejecución de comandos**
  - Ejecutar tests de simulación de comandos.

---

### Task 2: Timer Sound - Tic-Tac en los últimos 15 segundos
**Files:**
- Modify: `timer/timer-sound/service.luau`
- Copy resources: Copiar `tick1.wav` y `tock1.wav` a `timer/timer-sound/` desde pomodoro si es necesario.

- [ ] **Paso 1: Copiar o referenciar sonidos de tic-tac**
  - Incorporar recursos `tick.wav` / `tock.wav` en `timer/timer-sound/`.

- [ ] **Paso 2: Disparar tic-tac en update() cuando remaining <= 15**
  - Reproducir alternando tick y tock cuando `STATE == "RUNNING"` y `remaining <= 15 and remaining > 0`.

- [ ] **Paso 3: Commit cambios en timer**

---

### Task 3: Pomodoro - Audio Ducking, Loop Inmediato y Tic-Tac 15s
**Files:**
- Modify: `pomodoro/pomodoro/src/sounds.luau`
- Modify: `pomodoro/pomodoro/src/pomodoro.luau`

- [ ] **Paso 1: Integrar ducking al 145% y restauración en sounds.luau**
- [ ] **Paso 2: Activar tic-tac en los últimos 15 segundos de trabajo/descanso**
- [ ] **Paso 3: Commit cambios en pomodoro**
