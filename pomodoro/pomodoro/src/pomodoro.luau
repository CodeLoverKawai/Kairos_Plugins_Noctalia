type SessionPtr = {
    session: number,
    stage: number, -- 1: work, 2: break
}

type Config = {
    workDuration: number,
    shortBreakDuration: number,
    longBreakDuration: number,
    defaultSessions: number,
    autoStartBreaks: boolean,
    autoStartWork: boolean,
    enableWorkTimerSound: boolean,
    useBundledAlarmSound: boolean,
    bypassNoctaliaSoundGlobals: boolean,
    boostAlarmVolume: boolean,
    workCompleteSoundPath: string,
    breakCompleteSoundPath: string,
}

local function getBoolConfig(key: string, default: boolean): boolean
    local val = noctalia.getConfig(key)
    if val == nil then
        return default
    end
    return val == true
end

local function getNumConfig(key: string, default: number): number
    local val = noctalia.getConfig(key)
    if val == nil then
        return default
    end
    local num = tonumber(val)
    return if num and num > 0 then num else default
end

local function getStringConfig(key: string, default: string): string
    local val = noctalia.getConfig(key)
    if val == nil or type(val) ~= "string" then
        return default
    end
    return val
end

local function loadConfig(): Config
    return {
        workDuration = getNumConfig("work-duration", 25),
        shortBreakDuration = getNumConfig("short-break-duration", 5),
        longBreakDuration = getNumConfig("long-break-duration", 15),
        defaultSessions = getNumConfig("default-sessions", 4),
        autoStartBreaks = getBoolConfig("auto-start-breaks", true),
        autoStartWork = getBoolConfig("auto-start-work", true),
        enableWorkTimerSound = getBoolConfig("enable-work-timer-sound", false),
        useBundledAlarmSound = getBoolConfig("use-bundled-alarm-sound", true),
        bypassNoctaliaSoundGlobals = getBoolConfig("bypass-noctalia-sound-globals", true),
        boostAlarmVolume = getBoolConfig("boost-alarm-volume", true),
        workCompleteSoundPath = getStringConfig("work-complete-sound-path", ""),
        breakCompleteSoundPath = getStringConfig("break-complete-sound-path", ""),
    }
end

local config = loadConfig()
noctalia.state.set("pomodoro.config", config)

local totalSessions = math.max(1, math.min(12, config.defaultSessions or 4))

local function buildSessionData(n: number): { { number } }
    local sessions = {}
    for i = 1, n do
        local breakSecs = if i < n then config.shortBreakDuration * 60 else config.longBreakDuration * 60
        table.insert(sessions, { config.workDuration * 60, breakSecs })
    end
    return sessions
end

local sessionData = buildSessionData(totalSessions)
noctalia.state.set("pomodoro.sessionData", sessionData)

local sounds = require("./src/sounds.luau")
sounds.init({
    bypassNoctaliaSoundGlobals = config.bypassNoctaliaSoundGlobals,
    useBundledAlarmSound = config.useBundledAlarmSound,
    enableWorkTimerSound = config.enableWorkTimerSound,
    boostAlarmVolume = config.boostAlarmVolume,
})

local isRunning = false
local sessionPtr: SessionPtr = { session = 1, stage = 1 }
local isDirty = false
local isCompleted = false
local secondsLeft = 0
local tickAnchorSecond = nil
local lastProcessedSecond = nil

local function resetTickClock()
    tickAnchorSecond = nil
    lastProcessedSecond = nil
end

local function getStageTotalSeconds(): number
    local s = sessionPtr.session
    local stage = sessionPtr.stage
    if sessionData[s] and sessionData[s][stage] then
        return sessionData[s][stage]
    end
    return config.workDuration * 60
end

local function computeTotalSecondsLeft(): number
    if isCompleted then
        return 0
    end
    local s = sessionPtr.session
    local stage = sessionPtr.stage
    if s < 1 or s > #sessionData then
        return 0
    end

    local total = secondsLeft
    if stage == 1 then
        total += sessionData[s][2]
    end

    for i = s + 1, #sessionData do
        total += (sessionData[i][1] + sessionData[i][2])
    end

    return total
end

local function getStateSnapshot()
    local stageTotal = getStageTotalSeconds()
    return {
        isRunning = isRunning,
        secondsLeft = secondsLeft,
        sessionPtr = { session = sessionPtr.session, stage = sessionPtr.stage },
        totalSessions = totalSessions,
        totalSecondsLeft = computeTotalSecondsLeft(),
        stageTotalSeconds = stageTotal,
        isCompleted = isCompleted,
        isDirty = isDirty,
    }
end

local homeDir = (os and os.getenv and os.getenv("HOME")) or "/home/rousseau"
local STATE_FILE = homeDir .. "/.local/state/noctalia/plugins/data/codeloverkawai/pomodoro_state.json"

local function savePomodoroState()
    if not (noctalia and noctalia.writeFile) then
        return
    end
    local payload = string.format('{"session":%d,"stage":%d,"secondsLeft":%d,"totalSessions":%d,"isDirty":%s,"isCompleted":%s}',
        sessionPtr.session,
        sessionPtr.stage,
        secondsLeft,
        totalSessions,
        if isDirty then "true" else "false",
        if isCompleted then "true" else "false"
    )
    pcall(function()
        noctalia.writeFile(STATE_FILE, payload)
    end)
end

local function loadPomodoroState()
    if not (noctalia and noctalia.readFile) then
        return nil
    end
    local ok, content = pcall(function()
        return noctalia.readFile(STATE_FILE)
    end)
    if not ok or not content or content == "" then
        return nil
    end
    local session = tonumber(content:match('"session"%s*:%s*(%d+)'))
    local stage = tonumber(content:match('"stage"%s*:%s*(%d+)'))
    local sLeft = tonumber(content:match('"secondsLeft"%s*:%s*(%d+)'))
    local tSessions = tonumber(content:match('"totalSessions"%s*:%s*(%d+)'))
    local dirty = content:match('"isDirty"%s*:%s*(true)') ~= nil
    local completed = content:match('"isCompleted"%s*:%s*(true)') ~= nil

    if session and stage and sLeft then
        return {
            session = session,
            stage = stage,
            secondsLeft = sLeft,
            totalSessions = tSessions or 4,
            isDirty = dirty,
            isCompleted = completed,
        }
    end
    return nil
end

local savedPomodoro = loadPomodoroState()
if savedPomodoro then
    totalSessions = math.max(1, math.min(12, savedPomodoro.totalSessions))
    sessionData = buildSessionData(totalSessions)
    noctalia.state.set("pomodoro.sessionData", sessionData)
    local restoredSession = math.max(1, math.min(totalSessions, savedPomodoro.session))
    local restoredStage = if savedPomodoro.stage == 2 then 2 else 1
    sessionPtr = { session = restoredSession, stage = restoredStage }
    local maxStageSecs = getStageTotalSeconds()
    secondsLeft = math.max(0, math.min(maxStageSecs, savedPomodoro.secondsLeft))
    isDirty = savedPomodoro.isDirty
    isCompleted = savedPomodoro.isCompleted
    isRunning = false -- Always restore in PAUSED state
else
    secondsLeft = getStageTotalSeconds()
end

local function handleStageFinished()
    if sessionPtr.stage == 1 then
        -- Work finished -> transition to break
        if config.useBundledAlarmSound then
            sounds.playWorkAlarm(config.workCompleteSoundPath)
        end
        noctalia.notify("Pomodoro", noctalia.tr("notification.work-complete"))

        sessionPtr.stage = 2
        secondsLeft = getStageTotalSeconds()
        resetTickClock()
        if not config.autoStartBreaks then
            isRunning = false
        end
    else
        -- Break finished -> transition to work or complete
        if sessionPtr.session < totalSessions then
            if config.useBundledAlarmSound then
                sounds.playBreakAlarm(config.breakCompleteSoundPath)
            end
            noctalia.notify("Pomodoro", noctalia.tr("notification.short-break-complete"))

            sessionPtr.session += 1
            sessionPtr.stage = 1
            secondsLeft = getStageTotalSeconds()
            resetTickClock()
            if not config.autoStartWork then
                isRunning = false
            end
        else
            -- Final session long break finished: complete cycle!
            if config.useBundledAlarmSound then
                sounds.playBreakAlarm(config.breakCompleteSoundPath)
            end
            noctalia.notify("Pomodoro", noctalia.tr("notification.all-complete"))

            isRunning = false
            isCompleted = true
            secondsLeft = 0
            resetTickClock()
        end
    end
    savePomodoroState()
end

noctalia.state.watch("pomodoro.nextCommand", function(command)
    if not command or type(command) ~= "string" or command == "" then
        return
    end

    if command == "toggle" then
        sounds.stop()
        if isCompleted then
            isCompleted = false
            sessionPtr = { session = 1, stage = 1 }
            secondsLeft = getStageTotalSeconds()
            isRunning = true
            isDirty = true
            resetTickClock()
        else
            isRunning = not isRunning
            isDirty = true
            resetTickClock()
        end
    elseif command == "skip" then
        isRunning = false
        resetTickClock()
        sounds.stop()
        if not isCompleted then
            if sessionPtr.stage == 1 then
                sessionPtr.stage = 2
                secondsLeft = getStageTotalSeconds()
                isDirty = true
            else
                if sessionPtr.session < totalSessions then
                    sessionPtr.session += 1
                    sessionPtr.stage = 1
                    secondsLeft = getStageTotalSeconds()
                    isDirty = true
                else
                    isCompleted = true
                    secondsLeft = 0
                    isDirty = true
                end
            end
        end
    elseif command == "reset" then
        isRunning = false
        resetTickClock()
        sounds.stop()
        if isCompleted then
            isCompleted = false
        end
        secondsLeft = getStageTotalSeconds()
    elseif command == "resetAll" then
        isRunning = false
        resetTickClock()
        sounds.stop()
        isCompleted = false
        sessionPtr = { session = 1, stage = 1 }
        secondsLeft = getStageTotalSeconds()
        isDirty = false
    elseif command == "increment" then
        local n = math.min(12, totalSessions + 1)
        totalSessions = n
        sessionData = buildSessionData(totalSessions)
        noctalia.state.set("pomodoro.sessionData", sessionData)
        if sessionPtr.session > totalSessions then sessionPtr.session = totalSessions end
        local maxSecs = getStageTotalSeconds()
        if secondsLeft > maxSecs then secondsLeft = maxSecs elseif not isRunning and not isDirty then secondsLeft = maxSecs end
        if isCompleted and sessionPtr.session < totalSessions then isCompleted = false end
    elseif command == "decrement" then
        local n = math.max(1, totalSessions - 1)
        totalSessions = n
        sessionData = buildSessionData(totalSessions)
        noctalia.state.set("pomodoro.sessionData", sessionData)
        if sessionPtr.session > totalSessions then sessionPtr.session = totalSessions end
        local maxSecs = getStageTotalSeconds()
        if secondsLeft > maxSecs then secondsLeft = maxSecs elseif not isRunning and not isDirty then secondsLeft = maxSecs end
        if isCompleted and sessionPtr.session < totalSessions then isCompleted = false end
    elseif command:sub(1, 10) == "setPreset:" then
        local preset = command:sub(11)
        if preset == "clasico" then
            config.workDuration = 25
            config.shortBreakDuration = 5
            config.longBreakDuration = 15
        elseif preset == "deep" then
            config.workDuration = 50
            config.shortBreakDuration = 10
            config.longBreakDuration = 30
        elseif preset == "ultra" then
            config.workDuration = 90
            config.shortBreakDuration = 20
            config.longBreakDuration = 45
        end

        sessionData = buildSessionData(totalSessions)
        noctalia.state.set("pomodoro.sessionData", sessionData)
        noctalia.state.set("pomodoro.config", config)

        if not isRunning then
            isCompleted = false
            secondsLeft = getStageTotalSeconds()
        end
    else
        local nStr = command:match("^setSessions[:%s]*(%d+)$")
        if nStr then
            local n = tonumber(nStr)
            if n then
                totalSessions = math.max(1, math.min(12, n))
                sessionData = buildSessionData(totalSessions)
                noctalia.state.set("pomodoro.sessionData", sessionData)

                if sessionPtr.session > totalSessions then
                    sessionPtr.session = totalSessions
                end

                local maxSecs = getStageTotalSeconds()
                if secondsLeft > maxSecs then
                    secondsLeft = maxSecs
                elseif not isRunning and not isDirty then
                    secondsLeft = maxSecs
                end

                if isCompleted and sessionPtr.session < totalSessions then
                    isCompleted = false
                end
            end
        end
    end

    savePomodoroState()
    noctalia.state.set("pomodoro.state", getStateSnapshot())
    -- Clear command so subsequent identical commands (e.g. toggle -> toggle) always fire watchers
    noctalia.state.set("pomodoro.nextCommand", "")
end)

noctalia.state.watch("pomodoro.config", function(newConfig)
    if not newConfig or type(newConfig) ~= "table" then
        return
    end
    if newConfig.workDuration ~= nil then config.workDuration = newConfig.workDuration end
    if newConfig.shortBreakDuration ~= nil then config.shortBreakDuration = newConfig.shortBreakDuration end
    if newConfig.longBreakDuration ~= nil then config.longBreakDuration = newConfig.longBreakDuration end
    if newConfig.defaultSessions ~= nil then config.defaultSessions = newConfig.defaultSessions end
    if newConfig.autoStartBreaks ~= nil then config.autoStartBreaks = newConfig.autoStartBreaks end
    if newConfig.autoStartWork ~= nil then config.autoStartWork = newConfig.autoStartWork end
    if newConfig.enableWorkTimerSound ~= nil then config.enableWorkTimerSound = newConfig.enableWorkTimerSound end
    if newConfig.useBundledAlarmSound ~= nil then config.useBundledAlarmSound = newConfig.useBundledAlarmSound end
    if newConfig.bypassNoctaliaSoundGlobals ~= nil then config.bypassNoctaliaSoundGlobals = newConfig.bypassNoctaliaSoundGlobals end

    sessionData = buildSessionData(totalSessions)
    noctalia.state.set("pomodoro.sessionData", sessionData)
    if not isRunning and not isDirty then
        secondsLeft = getStageTotalSeconds()
    end
    noctalia.state.set("pomodoro.state", getStateSnapshot())
end)

function onSettingChanged(_key: string, _value: any)
    config = loadConfig()
    if not isRunning and not isDirty then
        totalSessions = math.max(1, math.min(12, config.defaultSessions or 4))
    end
    sessionData = buildSessionData(totalSessions)
    noctalia.state.set("pomodoro.sessionData", sessionData)
    noctalia.state.set("pomodoro.config", config)
    sounds.init({
        bypassNoctaliaSoundGlobals = config.bypassNoctaliaSoundGlobals,
        useBundledAlarmSound = config.useBundledAlarmSound,
        enableWorkTimerSound = config.enableWorkTimerSound,
        boostAlarmVolume = config.boostAlarmVolume,
    })
    if not isRunning and not isDirty then
        secondsLeft = getStageTotalSeconds()
    end
    noctalia.state.set("pomodoro.state", getStateSnapshot())
end

-- Initial state broadcast
noctalia.state.set("pomodoro.state", getStateSnapshot())

noctalia.setUpdateInterval(250)
function update()
    if not isRunning then
        return
    end

    local second = math.floor(noctalia.nowMs() / 1000)
    if tickAnchorSecond == nil then
        tickAnchorSecond = second
        lastProcessedSecond = second
        return
    end

    if second <= lastProcessedSecond then
        return
    end

    local stateChanged = false
    for s = lastProcessedSecond + 1, second do
        if s > tickAnchorSecond and secondsLeft > 0 then
            secondsLeft -= 1
            stateChanged = true

            local offset = s - tickAnchorSecond
            if offset > 0 then
                if config.enableWorkTimerSound and sessionPtr.stage == 1 then
                    if offset % 2 == 1 then
                        sounds.playTick()
                    else
                        sounds.playTock()
                    end
                elseif secondsLeft <= 15 and secondsLeft > 0 then
                    -- 15-second countdown tick-tock
                    if secondsLeft % 2 == 0 then
                        sounds.playTock()
                    else
                        sounds.playTick()
                    end
                end
            end

            if secondsLeft == 0 then
                handleStageFinished()
                noctalia.state.set("pomodoro.state", getStateSnapshot())
                return
            end
        end
    end
    lastProcessedSecond = second

    if stateChanged then
        if secondsLeft % 5 == 0 or secondsLeft <= 15 then
            savePomodoroState()
        end
        noctalia.state.set("pomodoro.state", getStateSnapshot())
    end
end

function onIpc(event: string, payload: any)
    if event == "command" and payload then
        noctalia.state.set("pomodoro.nextCommand", tostring(payload))
    elseif event and event ~= "" then
        noctalia.state.set("pomodoro.nextCommand", event)
    end
end

return {}
