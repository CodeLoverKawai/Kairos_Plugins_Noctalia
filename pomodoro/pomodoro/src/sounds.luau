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

function M.init(opts: { bypassNoctaliaSoundGlobals: boolean?, useBundledAlarmSound: boolean?, enableWorkTimerSound: boolean? }?)
    local options = opts or {}
    bypassNoctaliaSoundGlobals = options.bypassNoctaliaSoundGlobals == true
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
        pluginDir = "/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro"
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
        if enableWorkTimerSound then
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

function M.playAlarm()
    playSound(alarmSound)
end

function M.stop()
    if noctalia and noctalia.runAsync then
        noctalia.runAsync("sh -c 'pkill -9 -f \"noctalia_pomodoro_sound\" 2>/dev/null || true' noctalia_pomodoro_killer &")
    end
    if noctalia and noctalia.sound and noctalia.sound.stop and alarmSound then
        pcall(function()
            noctalia.sound.stop(alarmSound.name)
        end)
    end
end

return M
