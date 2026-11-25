--!nonstrict
-- Countdown timer service - the headless [[service]] entry.
--
-- The service owns the timer state and handles the countdown logic.
-- It publishes state changes to other entries via noctalia.state,
-- and listens for commands (START, PAUSE, RESET) from panel and bar.
--
--   noctalia.setUpdateInterval(ms)     set tick rate for countdown
--   noctalia.state.set(key, value)     publish state to other entries
--   noctalia.state.watch(key, fn)      react to commands from UI entries
--   noctalia.notify(title, body)       alert user when timer completes

noctalia.setUpdateInterval(1000)

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  if m >= 60 then
    return `{m // 60}:{string.format("%02d", m % 60)}:{string.format("%02d", s)}`
  end
  return `{m}:{string.format("%02d", s)}`
end

local homeDir = (os and os.getenv and os.getenv("HOME")) or "/home/rousseau"
local STATE_FILE = homeDir .. "/.local/state/noctalia/plugins/data/codeloverkawai/timer_state.json"

local function saveTimerState(state, remaining, duration)
  if not (noctalia and noctalia.writeFile) then
    return
  end
  local payload = string.format('{"state":"%s","remaining":%d,"duration":%d}', state, remaining or 0, duration or 0)
  pcall(function()
    noctalia.writeFile(STATE_FILE, payload)
  end)
end

local function loadTimerState()
  if not (noctalia and noctalia.readFile) then
    return nil
  end
  local ok, content = pcall(function()
    return noctalia.readFile(STATE_FILE)
  end)
  if not ok or not content or content == "" then
    return nil
  end
  local state = content:match('"state"%s*:%s*"([^"]+)"')
  local remaining = tonumber(content:match('"remaining"%s*:%s*(%d+)'))
  local duration = tonumber(content:match('"duration"%s*:%s*(%d+)'))
  if remaining and remaining > 0 then
    return {
      state = if state == "RUNNING" then "PAUSED" else (state or "PAUSED"),
      remaining = remaining,
      duration = duration or remaining,
    }
  end
  return nil
end

local initialSaved = loadTimerState()
local initRemaining = if initialSaved then initialSaved.remaining else 0
local initDuration = if initialSaved then initialSaved.duration else 0
local initState = if initialSaved then initialSaved.state else "IDLE"

---- Initialize state
noctalia.state.set("timer.state", initState) -- IDLE, NOTIFY, RUNNING, PAUSED
noctalia.state.set("timer.remaining", initRemaining)
noctalia.state.set("timer.formattedTime", formatTime(initRemaining))
noctalia.state.set("timer.duration", initDuration)

noctalia.state.watch("timer.remaining", function (value)
  noctalia.state.set("timer.formattedTime", formatTime(value))
end)

local function stopSound()
  if noctalia.runAsync then
    noctalia.runAsync([[sh -c '
      if [ -f /tmp/noctalia_timer_alarm.pid ]; then
        PID=$(cat /tmp/noctalia_timer_alarm.pid)
        rm -f /tmp/noctalia_timer_alarm.pid
        kill -STOP "$PID" 2>/dev/null || true
        pkill -9 -P "$PID" 2>/dev/null || true
        kill -9 "$PID" 2>/dev/null || true
      fi
      pkill -9 -f "[n]octalia_alarm_" 2>/dev/null || true
      if [ -f /tmp/noctalia_timer_orig_vol ]; then
        ORIG_VOL=$(cat /tmp/noctalia_timer_orig_vol)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "$ORIG_VOL" 2>/dev/null || true
        rm -f /tmp/noctalia_timer_orig_vol
      fi
    ']])
  end
  if noctalia.sound and noctalia.sound.stop then
    pcall(function()
      noctalia.sound.stop("alarm")
    end)
  end
end

local function playTickSound(isTock)
  local soundEnabled = noctalia.getConfig("sound_enabled")
  if soundEnabled == nil then
    soundEnabled = true
  end
  if not soundEnabled then
    return
  end

  local dir = ""
  if type(noctalia.pluginDir) == "function" then
    dir = noctalia.pluginDir() or ""
  elseif type(noctalia.pluginDir) == "string" then
    dir = noctalia.pluginDir
  end
  if dir == "" then
    dir = homeDir .. "/Documents/GitHub/Kairos_Plugins_Noctalia/timer/timer-sound"
  end

  local soundFile = if isTock then `{dir}/tock.wav` else `{dir}/tick.wav`
  local safePath = soundFile:gsub('"', '\\"')
  if noctalia.runAsync then
    local cmd = `sh -c 'pw-play "$1" 2>/dev/null || paplay "$1" 2>/dev/null || aplay "$1" 2>/dev/null' noctalia_tictac "{safePath}" &`
    noctalia.runAsync(cmd)
  end
end

local function playAlarmSound()
  local soundEnabled = noctalia.getConfig("sound_enabled")
  if soundEnabled == nil then
    soundEnabled = true
  end

  if not soundEnabled then
    return
  end

  local dir = ""
  if type(noctalia.pluginDir) == "function" then
    dir = noctalia.pluginDir() or ""
  elseif type(noctalia.pluginDir) == "string" then
    dir = noctalia.pluginDir
  end
  if dir == "" then
    dir = homeDir .. "/Documents/GitHub/Kairos_Plugins_Noctalia/timer/timer-sound"
  end
  local bundledAlarm = `{dir}/alarm.mp3`

  local customPath = noctalia.state.get("timer.custom_sound_path")
  if not customPath or customPath == "" then
    customPath = noctalia.getConfig("custom_sound_path")
  end

  local audioTarget = bundledAlarm
  if customPath and customPath ~= "" then
    if not (noctalia.fileExists) or noctalia.fileExists(customPath) then
      audioTarget = customPath
    end
  end

  local repeatAlarm = noctalia.getConfig("repeat_alarm")
  if repeatAlarm == nil then
    repeatAlarm = true
  end

  local boostAlarmVolume = noctalia.getConfig("boost_alarm_volume")
  if boostAlarmVolume == nil then
    boostAlarmVolume = true
  end

  local safePath = audioTarget:gsub('"', '\\"')

  if noctalia.runAsync then
    local killPrev = [[
      if [ -f /tmp/noctalia_timer_alarm.pid ]; then
        OLD_PID=$(cat /tmp/noctalia_timer_alarm.pid)
        rm -f /tmp/noctalia_timer_alarm.pid
        kill -STOP "$OLD_PID" 2>/dev/null || true
        pkill -9 -P "$OLD_PID" 2>/dev/null || true
        kill -9 "$OLD_PID" 2>/dev/null || true
      fi
      echo $$ > /tmp/noctalia_timer_alarm.pid
    ]]

    local volHeader = if boostAlarmVolume then [[
        restore_vol() {
          if [ -f /tmp/noctalia_timer_orig_vol ]; then
            ORIG_VOL=$(cat /tmp/noctalia_timer_orig_vol)
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "$ORIG_VOL" 2>/dev/null || true
            rm -f /tmp/noctalia_timer_orig_vol
          fi
        }
        trap restore_vol EXIT INT TERM
        if [ ! -f /tmp/noctalia_timer_orig_vol ]; then
          CURR_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk "{print \$2}")
          if [ -n "$CURR_VOL" ]; then
            echo "$CURR_VOL" > /tmp/noctalia_timer_orig_vol
          fi
        fi
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 1.45 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.45 2>/dev/null || true
    ]] else ""

    local playOne = [[
      case "$1" in
        *.m4a|*.M4A|*.aac|*.AAC|*.mp4|*.MP4)
          if command -v mpv >/dev/null 2>&1; then
            mpv --no-video --really-quiet "$1" 2>/dev/null
          elif command -v ffplay >/dev/null 2>&1; then
            ffplay -nodisp -autoexit -loglevel quiet "$1" 2>/dev/null
          else
            false
          fi
          ;;
        *)
          if command -v pw-play >/dev/null 2>&1; then
            pw-play "$1" 2>/dev/null
          elif command -v mpv >/dev/null 2>&1; then
            mpv --no-video --really-quiet "$1" 2>/dev/null
          elif command -v paplay >/dev/null 2>&1; then
            paplay "$1" 2>/dev/null
          elif command -v ffplay >/dev/null 2>&1; then
            ffplay -nodisp -autoexit -loglevel quiet "$1" 2>/dev/null
          else
            false
          fi
          ;;
      esac
    ]]

    if repeatAlarm then
      local loopCmd = string.format([[sh -c '
        %s
        %s
        while true; do
          %s || break
        done
      ' noctalia_alarm_loop "%s" &]], killPrev, volHeader, playOne, safePath)
      noctalia.runAsync(loopCmd)
    else
      local singleCmd = string.format([[sh -c '
        %s
        %s
        %s || true
      ' noctalia_alarm_single "%s" &]], killPrev, volHeader, playOne, safePath)
      noctalia.runAsync(singleCmd)
    end
  elseif noctalia.sound and noctalia.sound.play then
    noctalia.sound.play("alarm")
  end
end

-- send notification and sound when timer finishes
local function notifyUser()
  noctalia.notify(noctalia.tr("ui.notify_title"), noctalia.tr("ui.notify_body"))
  playAlarmSound()
end

noctalia.state.watch("timer.cmd", function(cmd)
  if not cmd or cmd == "" then
    return
  end

  local actions = {
    PAUSE = function()
      stopSound()
      noctalia.state.set("timer.state", "PAUSED")
      saveTimerState("PAUSED", noctalia.state.get("timer.remaining"), noctalia.state.get("timer.duration"))
    end,
    START = function ()
      stopSound()
      local remaining = noctalia.state.get("timer.remaining")
      local STATE = noctalia.state.get("timer.state")

      if (STATE == "IDLE" or STATE == "PAUSED") and (remaining or 0) > 0 then
        -- Capture the total on a fresh start so progress bars have a baseline;
        -- leave it untouched when resuming from PAUSED.
        if STATE == "IDLE" then
          noctalia.state.set("timer.duration", remaining)
        end
        noctalia.state.set("timer.state", "RUNNING")
        saveTimerState("RUNNING", remaining, noctalia.state.get("timer.duration"))
      end
    end,
    STOP = function ()
      stopSound()
      noctalia.state.set("timer.remaining", 0)
      noctalia.state.set("timer.duration", 0)
      noctalia.state.set("timer.state", "IDLE")
      saveTimerState("IDLE", 0, 0)
    end,
    RESET = function ()
      stopSound()
      noctalia.state.set("timer.remaining", 0)
      noctalia.state.set("timer.duration", 0)
      noctalia.state.set("timer.state", "IDLE")
      saveTimerState("IDLE", 0, 0)
    end
  }

  local action = actions[cmd]
  if action then
    action()
  else
    noctalia.log(`Unknown command: {cmd}`)
  end

  -- Clear command so subsequent identical commands always fire state watchers
  noctalia.state.set("timer.cmd", "")
end)

-- Stop any lingering processes on initialization
stopSound()

pcall(function()
  if noctalia.sound and noctalia.sound.load then
    noctalia.sound.load("alarm", "alarm.mp3", function(ok, err)
      if not ok and err then
        noctalia.log(`Failed to preload alarm sound: {err}`)
      end
    end)
  end
end)

function update()
  local STATE = noctalia.state.get("timer.state") or "IDLE"
  local remaining = noctalia.state.get("timer.remaining") or 0

  if STATE == "RUNNING" then
    if remaining > 0 then
      local nextRemaining = remaining - 1
      noctalia.state.set("timer.remaining", nextRemaining)
      -- Save state periodically or when low
      if nextRemaining % 5 == 0 or nextRemaining <= 15 then
        saveTimerState("RUNNING", nextRemaining, noctalia.state.get("timer.duration"))
      end
      -- Play tick-tock countdown in the last 15 seconds
      if nextRemaining > 0 and nextRemaining <= 15 then
        local isTock = (nextRemaining % 2 == 0)
        playTickSound(isTock)
      end
    else
      noctalia.state.set("timer.state", "NOTIFY")
      saveTimerState("NOTIFY", 0, noctalia.state.get("timer.duration"))
      notifyUser()
    end
  end
end
