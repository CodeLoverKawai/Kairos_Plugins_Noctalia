# Plan de Implementación: Persistencia de Estado de Temporizador y Pomodoro

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar guardado y restauración persistente de estado (progreso de conteo y sesiones) en archivos JSON locales para `timer` y `pomodoro`, recuperando sesiones en estado pausado tras reinicios.

**Architecture:** Módulo de persistencia JSON ligero en Luau que interactúa con el sistema de archivos (`noctalia.readFile` / `noctalia.writeFile`).

---

### Task 1: Implementar persistencia en `timer/timer-sound/service.luau`
**Files:**
- Modify: `timer/timer-sound/service.luau`

- [ ] **Paso 1: Funciones saveTimerState() y loadTimerState()**
- [ ] **Paso 2: Cargar estado al iniciar y guardar al pausar/actualizar/resetear**

---

### Task 2: Implementar persistencia en `pomodoro/pomodoro/src/pomodoro.luau`
**Files:**
- Modify: `pomodoro/pomodoro/src/pomodoro.luau`

- [ ] **Paso 1: Funciones savePomodoroState() y loadPomodoroState()**
- [ ] **Paso 2: Cargar sesión, etapa y tiempo restante al inicio; guardar en cada transición y tick periódico**

---

### Task 3: Verificación y Sincronización
**Files:**
- Sync: `timer/timer-sound/` y `pomodoro/pomodoro/` a directorio Universidad y recarga de Noctalia.

- [ ] **Paso 1: Probar persistencia con reinicio del proceso**
- [ ] **Paso 2: Commit y documentación**
