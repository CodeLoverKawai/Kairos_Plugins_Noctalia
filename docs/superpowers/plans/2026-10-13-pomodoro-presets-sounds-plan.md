# Plan de Implementación: Presets Rápidos y Sonidos Independientes (Pomodoro Pro)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar en `codeloverkawai/pomodoro` 3 botones de preset con nombre (`Clásico`, `Deep`, `Ultra`) en el panel para cambio inmediato de duraciones, y soporte para sonidos de alarma diferenciados al terminar la fase de trabajo y la de descanso.

**Architecture:** Luau, Noctalia State IPC y plugin.toml. Los botones emiten comandos al servicio `pomodoro.luau`, que recalcula duraciones sobre la marcha y emite sonidos independientes según la transición.

---

### Task 1: Declarar ajustes y altura del panel en plugin.toml y traducciones
**Files:**
- Modify: `pomodoro/pomodoro/plugin.toml`
- Modify: `pomodoro/pomodoro/translations/es.json`
- Modify: `pomodoro/pomodoro/translations/en.json`

- [ ] **Paso 1: Añadir ajustes de rutas de sonido en plugin.toml y aumentar altura a 335**
- [ ] **Paso 2: Añadir traducciones para los nombres de presets y ajustes**

---

### Task 2: Implementar selección de sonidos independientes en sounds.luau y pomodoro.luau
**Files:**
- Modify: `pomodoro/pomodoro/src/sounds.luau`
- Modify: `pomodoro/pomodoro/src/pomodoro.luau`

- [ ] **Paso 1: Soportar paths personalizados para fin de trabajo y fin de descanso en sounds.luau**
- [ ] **Paso 2: Invocar el sonido correspondiente en handleStageFinished() en pomodoro.luau**
- [ ] **Paso 3: Soportar comandos setPreset:clasico, setPreset:deep, setPreset:ultra en pomodoro.luau**

---

### Task 3: Añadir la fila de botones de presets con nombre en panel.luau
**Files:**
- Modify: `pomodoro/pomodoro/src/panel.luau`

- [ ] **Paso 1: Crear handlers onPresetClasico, onPresetDeep, onPresetUltra**
- [ ] **Paso 2: Renderizar la fila de botones [Clásico], [Deep], [Ultra] con resaltado del preset activo**
- [ ] **Paso 3: Sincronizar y recargar en Noctalia**
