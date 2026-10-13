# Especificación de Diseño: Persistencia de Estado de Temporizador y Pomodoro

**Fecha:** 2026-10-13  
**Estado:** Aprobado  

## 1. Resumen
Preservar de forma transparente el progreso de las sesiones tanto en `codeloverkawai/timer-sound` como en `codeloverkawai/pomodoro` ante reinicios de Noctalia, suspensiones o apagado de la máquina:
- Guardado atómico de estado en archivo JSON local (`~/.local/state/noctalia/plugins/data/...` o `$HOME/.local/state/noctalia/...`).
- Al iniciar el plugin, restaurar el progreso exacto en modo **PAUSADO**, evitando pérdida de datos.
- Al resetear o terminar el ciclo, limpiar o reiniciar el estado guardado a IDLE.

## 2. Arquitectura de Persistencia

### 2.1 Archivos de Estado
1. **Timer**:
   - Ruta: `~/.local/state/noctalia/plugins/data/codeloverkawai/timer_state.json`
   - Esquema:
     ```json
     {
       "state": "PAUSED",
       "remaining": 1420,
       "duration": 1500
     }
     ```
2. **Pomodoro Pro**:
   - Ruta: `~/.local/state/noctalia/plugins/data/codeloverkawai/pomodoro_state.json`
   - Esquema:
     ```json
     {
       "session": 3,
       "stage": 1,
       "secondsLeft": 840,
       "totalSessions": 6,
       "isDirty": true
     }
     ```

### 2.2 Ciclo de Vida y Guardado
- **Periodicidad / Trigger**:
  - Al cambiar de estado (`START`, `PAUSE`, `RESET`, `SKIP`, o cada ~5 segundos durante `RUNNING`).
  - Al completar el ciclo o presionar `RESET ALL`: el archivo refleja estado inicial limpio.
- **Carga al Iniciar (`init`)**:
  - Lee el archivo JSON. Si el estado anterior era `RUNNING`, se convierte a `PAUSED` con el `remaining` intacto.

## 3. Verificación
1. Iniciar un Timer a 5 minutos, dejarlo correr 30 segundos, reiniciar Noctalia -> verificar que arranca en 4:30 pausado.
2. Iniciar un Pomodoro en la sesión 2 de 4, avanzar un minuto, reiniciar Noctalia -> verificar que sigue en sesión 2 de 4 pausado con el tiempo restante exacto.
