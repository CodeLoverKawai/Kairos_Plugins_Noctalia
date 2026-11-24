type Sound = {
    name: string,
    path: string,
    loaded: boolean,
}

local M = {}

local alarmSound: Sound? = nil
local tickSounds: { Sound } = {}
local tockSounds: { Sound } = {}

local bypassNoctaliaSoundGlobals = false
local boostAlarmVolume = true

local function playExternal(path: string)
    if not path or path == "" then
        return
    end
    if noctalia and noctalia.fileExists and not noctalia.fileExists(path) then
        return
    end
    local safePath = path:gsub('"', '\\"')
    if noctalia and noctalia.runAsync then
        local cmd = `sh -c 'pw-play "$1" 2>/dev/null || paplay "$1" 2>/dev/null || ffplay -nodisp -autoexit -loglevel quiet "$1" 2>/dev/null || aplay "$1" 2>/dev/null' noctalia_pomodoro_sound "{safePath}" &`
        noctalia.runAsync(cmd)
    end
end

local function playAlarmExternal(path: string)
    if not path or path == "" then
        return
    end
    local safePath = path:gsub('"', '\\"')
    if noctalia and noctalia.runAsync then
        local killPrev = [[
            if [ -f /tmp/noctalia_pomodoro_alarm.pid ]; then
                OLD_PID=$(cat /tmp/noctalia_pomodoro_alarm.pid)
                rm -f /tmp/noctalia_pomodoro_alarm.pid
                kill -STOP "$OLD_PID" 2>/dev/null || true
                pkill -9 -P "$OLD_PID" 2>/dev/null || true
                kill -9 "$OLD_PID" 2>/dev/null || true
            fi
            echo $$ > /tmp/noctalia_pomodoro_alarm.pid
        ]]
        if boostAlarmVolume then
            local playCmd = string.format([[sh -c '
                %s
                restore_vol() {
                    if [ -f /tmp/noctalia_pomodoro_orig_vol ]; then
                        ORIG_VOL=$(cat /tmp/noctalia_pomodoro_orig_vol)
                        wpctl set-volume @DEFAULT_AUDIO_SINK@ "$ORIG_VOL" 2>/dev/null || true
                        rm -f /tmp/noctalia_pomodoro_orig_vol
                    fi
                }
                trap restore_vol EXIT INT TERM
                if [ ! -f /tmp/noctalia_pomodoro_orig_vol ]; then
                    CURR_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk "{print \$2}")
                    if [ -n "$CURR_VOL" ]; then
                        echo "$CURR_VOL" > /tmp/noctalia_pomodoro_orig_vol
                    fi
                fi
                wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 1.45 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.45 2>/dev/null || true
                if command -v pw-play >/dev/null 2>&1; then
                    pw-play "$1" 2>/dev/null || true
                elif command -v paplay >/dev/null 2>&1; then
                    paplay "$1" 2>/dev/null || true
                elif command -v ffplay >/dev/null 2>&1; then
                    ffplay -nodisp -autoexit -loglevel quiet "$1" 2>/dev/null || true
                fi
            ' noctalia_pomodoro_alarm_single "%s" &]], killPrev, safePath)
            noctalia.runAsync(playCmd)
        else
            local playCmd = string.format([[sh -c '
                %s
                if command -v pw-play >/dev/null 2>&1; then
                    pw-play "$1" 2>/dev/null || true
                elif command -v paplay >/dev/null 2>&1; then
                    paplay "$1" 2>/dev/null || true
                elif command -v ffplay >/dev/null 2>&1; then
                    ffplay -nodisp -autoexit -loglevel quiet "$1" 2>/dev/null || true
                fi
            ' noctalia_pomodoro_alarm_single "%s" &]], killPrev, safePath)
            noctalia.runAsync(playCmd)
        end
    end
end

local function playSound(sound: Sound?)
    if not sound then
        return
    end
    if noctalia and noctalia.runAsync then
        playExternal(sound.path)
    elseif sound.loaded and noctalia and noctalia.sound and noctalia.sound.play then
        noctalia.sound.play(sound.name)
    else
        playExternal(sound.path)
    end
end

local LOAD_BATCH_SIZE = 8

--- Loads sound entries through noctalia.sound.load in sequential batches.
local function loadSounds(entries: { Sound }, batchSize: number)
    if not (noctalia and noctalia.sound and noctalia.sound.load) then
        return
    end
    if batchSize < 1 then
        batchSize = 1
    end

    local function loadBatch(index: number)
        if index > #entries then
            return
        end

        local batchEnd = math.min(index + batchSize - 1, #entries)
        local pending = batchEnd - index + 1
        local completed = 0

        local function onBatchItemDone()
            completed += 1
            if completed >= pending then
                loadBatch(batchEnd + 1)
            end
        end

        for i = index, batchEnd do
            local sound = entries[i]
            local accepted = noctalia.sound.load(sound.name, sound.path, function(ok, err)
                sound.loaded = ok == true
                if not ok and noctalia.notifyError then
                    noctalia.notifyError("Couldn't load sound", sound.name .. ": " .. (err or ""))
                end
                onBatchItemDone()
            end)

            if not accepted then
                if noctalia.notifyError then
                    noctalia.notifyError("Couldn't queue sound", sound.name)
                end
                onBatchItemDone()
            end
        end
    end

    loadBatch(1)
end

function M.init(opts: { bypassNoctaliaSoundGlobals: boolean?, useBundledAlarmSound: boolean?, enableWorkTimerSound: boolean?, boostAlarmVolume: boolean? }?)
    local options = opts or {}
    bypassNoctaliaSoundGlobals = options.bypassNoctaliaSoundGlobals == true
    boostAlarmVolume = if options.boostAlarmVolume ~= nil then options.boostAlarmVolume == true else true
    local useBundledAlarmSound = options.useBundledAlarmSound == true
    local enableWorkTimerSound = options.enableWorkTimerSound == true

    local pluginDir = ""
    if noctalia then
        if type(noctalia.pluginDir) == "function" then
            pluginDir = noctalia.pluginDir() or ""
        elseif type(noctalia.pluginDir) == "string" then
            pluginDir = noctalia.pluginDir
        end
    end
    if not pluginDir or pluginDir == "" then
        local homeDir = (os and os.getenv and os.getenv("HOME")) or "/home/rousseau"
        pluginDir = homeDir .. "/Documents/GitHub/Kairos_Plugins_Noctalia/pomodoro/pomodoro"
    end

    local resourcesDir = pluginDir .. "/resources/"
    alarmSound = {
        name = "alarm",
        path = resourcesDir .. "alarm.mp3",
        loaded = false,
    }

    tickSounds = {}
    tockSounds = {}

    for i = 1, 9 do
        local tickPath = resourcesDir .. "tick" .. i .. ".wav"
        if noctalia.fileExists(tickPath) then
            table.insert(tickSounds, {
                name = "tick-" .. i,
                path = tickPath,
                loaded = false,
            })
        end

        local tockPath = resourcesDir .. "tock" .. i .. ".wav"
        if noctalia.fileExists(tockPath) then
            table.insert(tockSounds, {
                name = "tock-" .. i,
                path = tockPath,
                loaded = false,
            })
        end
    end

    if noctalia and noctalia.sound and noctalia.sound.load and not bypassNoctaliaSoundGlobals then
        local loadQueue: { Sound } = {}
        if useBundledAlarmSound and alarmSound then
            table.insert(loadQueue, alarmSound)
        end
        for _, sound in tickSounds do
            table.insert(loadQueue, sound)
        end
        for _, sound in tockSounds do
            table.insert(loadQueue, sound)
        end
        if #loadQueue > 0 then
            loadSounds(loadQueue, LOAD_BATCH_SIZE)
        end
    end
end

function M.playTick()
    if #tickSounds == 0 then
        return
    end
    playSound(tickSounds[math.random(#tickSounds)])
end

function M.playTock()
    if #tockSounds == 0 then
        return
    end
    playSound(tockSounds[math.random(#tockSounds)])
end

function M.playWorkAlarm(customPath: string?)
    local targetPath = if customPath and customPath ~= "" then customPath else if alarmSound then alarmSound.path else ""
    if targetPath ~= "" then
        playAlarmExternal(targetPath)
    end
end

function M.playBreakAlarm(customPath: string?)
    local targetPath = if customPath and customPath ~= "" then customPath else if alarmSound then alarmSound.path else ""
    if targetPath ~= "" then
        playAlarmExternal(targetPath)
    end
end

function M.playAlarm()
    M.playWorkAlarm(nil)
end

local currentMusicKey: string? = nil
local isMusicPaused = false

function M.pauseMusic()
    if not currentMusicKey or isMusicPaused then
        return
    end
    isMusicPaused = true
    if noctalia and noctalia.runAsync then
        noctalia.runAsync([[sh -c '
            if [ -f /tmp/noctalia_pomodoro_music.pid ]; then
                PID=$(cat /tmp/noctalia_pomodoro_music.pid)
                kill -STOP "$PID" 2>/dev/null || true
                pkill -STOP -P "$PID" 2>/dev/null || true
            fi
        ']])
    end
end

function M.resumeMusic()
    if not currentMusicKey or not isMusicPaused then
        return
    end
    isMusicPaused = false
    if noctalia and noctalia.runAsync then
        noctalia.runAsync([[sh -c '
            if [ -f /tmp/noctalia_pomodoro_music.pid ]; then
                PID=$(cat /tmp/noctalia_pomodoro_music.pid)
                pkill -CONT -P "$PID" 2>/dev/null || true
                kill -CONT "$PID" 2>/dev/null || true
            fi
        ']])
    end
end

function M.startMusic(path: string?, mode: string?)
    if not path or path == "" then
        M.stopMusic()
        return
    end
    local effectiveMode = if mode == "shuffle" then "shuffle" else "single"
    local musicKey = effectiveMode .. "|" .. path
    if currentMusicKey == musicKey then
        if isMusicPaused then
            M.resumeMusic()
        end
        return
    end
    currentMusicKey = musicKey
    isMusicPaused = false
    local safePath = path:gsub('"', '\\"')
    if noctalia and noctalia.runAsync then
        local cmd = string.format([[sh -c '
            if [ -f /tmp/noctalia_pomodoro_music.pid ]; then
                OLD_PID=$(cat /tmp/noctalia_pomodoro_music.pid)
                rm -f /tmp/noctalia_pomodoro_music.pid
                kill -STOP "$OLD_PID" 2>/dev/null || true
                pkill -9 -P "$OLD_PID" 2>/dev/null || true
                kill -9 "$OLD_PID" 2>/dev/null || true
            fi
            echo $$ > /tmp/noctalia_pomodoro_music.pid

            play_track() {
                if command -v pw-play >/dev/null 2>&1; then
                    pw-play "$1" 2>/dev/null
                elif command -v paplay >/dev/null 2>&1; then
                    paplay "$1" 2>/dev/null
                elif command -v ffplay >/dev/null 2>&1; then
                    ffplay -nodisp -autoexit -loglevel quiet "$1" 2>/dev/null
                else
                    return 1
                fi
            }

            MODE="$2"
            TARGET="$1"
            if [ "$MODE" = "shuffle" ] || [ -d "$TARGET" ]; then
                if [ -d "$TARGET" ]; then
                    DIR="$TARGET"
                else
                    DIR=$(dirname "$TARGET")
                fi
                while true; do
                    find "$DIR" -maxdepth 2 -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.opus" -o -iname "*.wav" -o -iname "*.m4a" -o -iname "*.aac" \) 2>/dev/null | shuf > /tmp/noctalia_pomodoro_playlist.txt
                    [ ! -s /tmp/noctalia_pomodoro_playlist.txt ] && break
                    while IFS= read -r TRACK; do
                        [ -n "$TRACK" ] && play_track "$TRACK"
                    done < /tmp/noctalia_pomodoro_playlist.txt
                done
            else
                while true; do
                    play_track "$TARGET" || break
                done
            fi
        ' noctalia_pomodoro_music "%s" "%s" &]], safePath, effectiveMode)
        noctalia.runAsync(cmd)
    end
end

function M.stopMusic()
    currentMusicKey = nil
    isMusicPaused = false
    if noctalia and noctalia.runAsync then
        noctalia.runAsync([[sh -c '
            if [ -f /tmp/noctalia_pomodoro_music.pid ]; then
                PID=$(cat /tmp/noctalia_pomodoro_music.pid)
                rm -f /tmp/noctalia_pomodoro_music.pid
                kill -STOP "$PID" 2>/dev/null || true
                pkill -9 -P "$PID" 2>/dev/null || true
                kill -9 "$PID" 2>/dev/null || true
            fi
            pkill -9 -f "[n]octalia_pomodoro_music" 2>/dev/null || true
        ']])
    end
end

function M.stop()
    if noctalia and noctalia.runAsync then
        noctalia.runAsync([[sh -c '
            if [ -f /tmp/noctalia_pomodoro_alarm.pid ]; then
                PID=$(cat /tmp/noctalia_pomodoro_alarm.pid)
                rm -f /tmp/noctalia_pomodoro_alarm.pid
                kill -STOP "$PID" 2>/dev/null || true
                pkill -9 -P "$PID" 2>/dev/null || true
                kill -9 "$PID" 2>/dev/null || true
            fi
            pkill -9 -f "[n]octalia_pomodoro_alarm_" 2>/dev/null || true
            if [ -f /tmp/noctalia_pomodoro_orig_vol ]; then
                ORIG_VOL=$(cat /tmp/noctalia_pomodoro_orig_vol)
                wpctl set-volume @DEFAULT_AUDIO_SINK@ "$ORIG_VOL" 2>/dev/null || true
                rm -f /tmp/noctalia_pomodoro_orig_vol
            fi
        ']])
    end
    if noctalia and noctalia.sound and noctalia.sound.stop and alarmSound then
        pcall(function()
            noctalia.sound.stop(alarmSound.name)
        end)
    end
end

return M
