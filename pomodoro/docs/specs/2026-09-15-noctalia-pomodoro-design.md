# Especificación de Diseño: Noctalia Pomodoro Pro (Ciclos Continuos y Selector de Sesiones)

**Fecha:** 2026-09-15  
**Autor:** CodeLoverKawai  
**Repositorio:** `CodeLoverKawai/Noctalia-pomodoro`  
**Ruta:** `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro`  
**Plugin ID:** `codeloverkawai/pomodoro`  
**Plugin API:** `22`  

---

## 1. Propósito y Alcance
Desarrollar un plugin independiente para **Noctalia Shell** que ofrezca un temporizador Pomodoro con:
1. **Flujo Continuo Automático**: Avanza de manera fluida y sin pausas entre sesiones de trabajo y descansos (emitiendo notificaciones y sonidos de alarma en cada fase) hasta completar exactamente el total de sesiones $N$ configurado, deteniéndose limpiamente al final.
2. **Selector de Sesiones en Panel**: Sección en el panel desplegable para introducir o ajustar la cantidad de sesiones objetivo ($N$, de 1 a 12).
3. **Métricas Claras de Tiempo**: Mostrar tanto la duración de la fase en curso como el **tiempo total restante acumulado** necesario para concluir todas las sesiones restantes.
4. **Independencia y Autoría**: Estructura 100% propia bajo la identidad `CodeLoverKawai`, compatible con la carga de fuentes locales (`path`) de Noctalia.

---

## 2. Arquitectura de Archivos

```
Noctalia-pomodoro/
├── catalog.toml                  # Catálogo de Noctalia declarando codeloverkawai/pomodoro
├── README.md                     # Documentación técnica y guía de instalación
├── docs/
│   ├── specs/2026-09-15-noctalia-pomodoro-design.md
│   └── plans/2026-09-15-noctalia-pomodoro-plan.md
└── pomodoro/
    ├── plugin.toml               # Manifiesto y settings del plugin
    ├── resources/
    │   ├── JetBrainsMono-Regular.ttf
    │   ├── alarm.mp3
    │   └── tick*.wav / tock*.wav
    ├── src/
    │   ├── pomodoro.luau         # Servicio headless con lógica de ciclos continuos
    │   ├── panel.luau            # Panel de control con selector de sesiones y desglose
    │   ├── widget.luau           # Widget para la barra de estado
    │   └── sounds.luau           # Reproducción de alarmas y ticks
    └── translations/
        ├── en.json
        └── es.json
```

---

## 3. Lógica del Servicio (`src/pomodoro.luau`)

### 3.1 Modelo de Datos y Construcción de Sesiones
Al inicializar o cambiar el total de sesiones $N$:
- **Sesiones $1$ a $N-1$**: `[workDuration * 60, shortBreakDuration * 60]`
- **Sesión $N$**: `[workDuration * 60, longBreakDuration * 60]`

### 3.2 Estado Reactivo (`noctalia.state`)
- `pomodoro.state`:
  - `isRunning`: booleano.
  - `secondsLeft`: segundos restantes de la fase actual.
  - `sessionPtr`: `{ session = s, stage = 1 | 2 }` (1 = trabajo, 2 = descanso).
  - `totalSessions`: número de sesiones totales ($N$).
  - `totalSecondsLeft`: suma total de segundos para terminar todas las sesiones restantes.
  - `stageTotalSeconds`: duración total de la fase actual en segundos.
  - `isCompleted`: booleano, verdadero al culminar la última fase de la sesión $N$.

### 3.3 Cálculo del Tiempo Total Restante
$$\text{totalSecondsLeft} = \text{secondsLeft} + [ \text{si stage} == 1 \Rightarrow \text{sessionData}[s][2] \text{ else } 0 ] + \sum_{i=s+1}^{N} (\text{sessionData}[i][1] + \text{sessionData}[i][2])$$

### 3.4 Transición Continua de Fases
Cuando `secondsLeft == 0`:
1. Reproducir alarma y enviar notificación (`notifyStageFinished`).
2. Si `stage == 1` (Fin de trabajo):
   - Cambiar a `stage = 2` (Descanso).
   - `secondsLeft = getStageTotalSeconds()`.
   - Si `autoStartBreaks == true` (predeterminado), mantener `isRunning = true`.
3. Si `stage == 2` (Fin de descanso):
   - Si `session < N`:
     - Incrementar `session += 1`, `stage = 1`.
     - `secondsLeft = getStageTotalSeconds()`.
     - Si `autoStartWork == true` (predeterminado), mantener `isRunning = true`.
   - Si `session == N`:
     - El ciclo completo ha finalizado.
     - `isRunning = false`.
     - `isCompleted = true`.
     - Notificación final: *"¡Objetivo Pomodoro completado! Has terminado tus N sesiones."*

### 3.5 Comandos Manejados (`pomodoro.nextCommand`)
- `toggle`: Inicia / Pausa.
- `skip`: Salta inmediatamente a la siguiente etapa.
- `reset`: Reinicia la etapa actual al tiempo total.
- `resetAll`: Reinicia a la sesión 1, etapa 1, `isRunning = false`, `isCompleted = false`.
- `setSessions <N>`: Reconfigura el total de sesiones a $N$ ($1 \le N \le 12$) y recalcula el plan de sesiones.

---

## 4. Interfaz de Usuario

### 4.1 Panel de Control (`src/panel.luau`)
- **Cabecera**: Título `Pomodoro Pro`, ícono dinámico y badge `Sesión X/N`.
- **Selector de Sesiones**:
  - Fila con botones `[-]`, etiqueta destacada con el número de sesiones (ej. `4 Sesiones`) y botón `[+]`.
  - Deshabilitado o bloqueado durante la ejecución activa para evitar inconsistencias (o editable en pausa/idle).
- **Reloj Central**:
  - Tipografía monoespaciada grande con el tiempo restante de la etapa (`MM:SS`).
  - Etiqueta de la fase actual (`Trabajo`, `Descanso Corto`, `Descanso Largo`).
- **Métricas de Tiempo**:
  - `Fase actual: X min`
  - `Tiempo total restante: H h MM m`
- **Botones de Control**:
  - Iniciar / Pausar / Reanudar.
  - Saltar fase (`Skip`).
  - Reiniciar fase (`Reset`).
  - Reiniciar todo el ciclo (`Reset All`).

### 4.2 Widget de Barra (`src/widget.luau`)
- Muestra el ícono contextual (`brain` para trabajo, `coffee` para descanso).
- Texto compacto: `[X/N] MM:SS`.
- Clic izquierdo para alternar el panel (`panel-toggle codeloverkawai/pomodoro:panel`).

---

## 5. Pruebas y Criterios de Aceptación
1. **Linter**: `noctalia plugins lint` pasa sin advertencias ni errores.
2. **Ciclo Automático**: Al expirar el tiempo de trabajo, transiciona inmediatamente a descanso sin detenerse; al expirar el descanso, pasa a la siguiente sesión de trabajo.
3. **Parada al Final**: Al terminar la sesión $N$, el temporizador se detiene limpiamente y emite la notificación final.
4. **Cálculo Exacto de Tiempo**: `totalSecondsLeft` refleja en todo momento la suma real de fases pendientes.
5. **Ajuste Dinámico**: Modificar las sesiones mediante los botones `[-]` y `[+]` actualiza de inmediato el total de sesiones y el tiempo restante.
