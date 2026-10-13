# Especificación de Diseño: Mejoras de Audio y Cuenta Regresiva (Timer & Pomodoro)

**Fecha:** 2026-10-13  
**Estado:** Aprobado para Planificación  

## 1. Resumen
Mejorar la experiencia auditiva de los plugins de Noctalia (`timer` y `pomodoro`) en `Kairos_Plugins_Noctalia`:
1. **Loop de alarma continuo e inmediato**: Eliminar pausas largas entre repeticiones de la alarma.
2. **Audio Ducking y Volumen 145%**: Al sonar la alarma, capturar el volumen original del sistema con `wpctl`, elevar la salida a 145% (`1.45`), y restaurar el volumen original exacto al detener o reiniciar.
3. **Cuenta regresiva Tic-Tac (últimos 15 segundos)**: Reproducir un sonido de tic-tac rítmico cada segundo durante los últimos 15 segundos previos al vencimiento.

## 2. Arquitectura de Audio

### 2.1 Módulo / Script Helper de Audio
- Almacenamiento seguro de volumen previo en `/tmp/noctalia_audio_orig_vol`.
- Reproducción inmediata de alarma mediante loop sin delay (`ffplay` o subshell optimizado).
- Al detener la alarma (`stopSound`), restaurar el volumen con `wpctl set-volume @DEFAULT_AUDIO_SINK@ <orig>` y eliminar el archivo temporal.

### 2.2 Cuenta Regresiva Tic-Tac
- En `update()`: cuando el tiempo restante esté entre 1 y 15 segundos, disparar tick/tock por segundo usando los recursos `.wav`.

## 3. Verificación
- Pruebas sintácticas y de ejecución de comandos de volumen.
- Prueba de audio en segundo plano con simulación de cuenta regresiva y restauración.
