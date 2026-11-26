--!nonstrict
-- Clarity Eye-Care headless service (codeloverkawai/clarity)

local exercises = require("./src/exercises.luau")

local homeDir = (os and os.getenv and os.getenv("HOME")) or "/home/rousseau"
local STATS_FILE = homeDir .. "/.local/state/noctalia/plugins/data/codeloverkawai/clarity_stats.json"

local function getBoolConfig(key: string, default: boolean): boolean
    local val = noctalia.getConfig(key)
    if val == nil then
        return default
    end
    return val == true
end

local function getNumConfig(key: string, default: number, minVal: number?): number
    local val = noctalia.getConfig(key)
    if val == nil then
        return default
    end
    local num = tonumber(val)
    if not num then
        return default
    end
    if minVal ~= nil and num < minVal then
        return default
    end
    return num
end

local function loadConfig()
    return {
        activeDurationMinutes = getNumConfig("active-duration-minutes", 20, 1),
        breakDurationSeconds = getNumConfig("break-duration-seconds", 20, 10),
        longBreakInterval = getNumConfig("long-break-interval", 4, 0),
        longBreakDurationSeconds = getNumConfig("long-break-duration-seconds", 120, 30),
        autoOpenPanel = getBoolConfig("auto-open-panel", true),
        autoClosePanel = getBoolConfig("auto-close-panel", true),
        enableSound = getBoolConfig("enable-sound", true),
        enableNotifications = getBoolConfig("enable-notifications", true),
    }
end

local config = loadConfig()

local function getTodayKey(): string
    if os and os.date then
        return tostring(os.date("%Y-%m-%d"))
    end
    return "today"
end

local todayKey = getTodayKey()
local completedToday = 0
local shortBreaksSinceLong = 0
local exerciseIndex = 1

local isPaused = false
local isSystemIdle = false
local wasSystemIdle = false
local lastLineWasActiveChanged = false

local inBreak = false
local isLongBreak = false
local activeSeconds = 0
local idleSeconds = 0
local breakRemaining = 0
local breakTotal = 20
local snoozeRemaining = 0

local currentExercise = exercises.getShort(exerciseIndex)

local function saveStats()
    if not (noctalia and noctalia.writeFile) then
        return
    end
    local payload = string.format(
        '{"date":"%s","completedToday":%d,"exerciseIndex":%d}',
        todayKey,
        completedToday,
        exerciseIndex
    )
    pcall(function()
        noctalia.writeFile(STATS_FILE, payload)
    end)
end

local function loadStats()
    if not (noctalia and noctalia.readFile) then
        return
    end
    local ok, content = pcall(function()
        return noctalia.readFile(STATS_FILE)
    end)
    if not ok or not content or content == "" then
        return
    end
    local savedDate = content:match('"date"%s*:%s*"([^"]+)"')
    local savedCount = tonumber(content:match('"completedToday"%s*:%s*(%d+)'))
    local savedIdx = tonumber(content:match('"exerciseIndex"%s*:%s*(%d+)'))
    if savedDate == todayKey and savedCount then
        completedToday = savedCount
    end
    if savedIdx and savedIdx >= 1 then
        exerciseIndex = savedIdx
        currentExercise = exercises.getShort(exerciseIndex)
    end
end

loadStats()

local function playChime(soundName: string)
    if not config.enableSound or not (noctalia and noctalia.runAsync) then
        return
    end
    local path = "/usr/share/sounds/freedesktop/stereo/" .. soundName .. ".oga"
    local cmd = string.format(
        [[sh -c 'if [ -f "$1" ]; then pw-play --volume=0.65 "$1" 2>/dev/null || paplay "$1" 2>/dev/null || true; fi' clarity_chime "%s" &]],
        path
    )
    noctalia.runAsync(cmd)
end

local function openPanel()
    if config.autoOpenPanel and noctalia and noctalia.runAsync then
        noctalia.runAsync("noctalia msg panel-open codeloverkawai/clarity:panel 2>/dev/null || true")
    end
end

local function closePanel()
    if config.autoClosePanel and noctalia and noctalia.runAsync then
        noctalia.runAsync("noctalia msg panel-close codeloverkawai/clarity:panel 2>/dev/null || true")
    end
end

local function getActiveLimitSeconds(): number
    if snoozeRemaining > 0 then
        return snoozeRemaining
    end
    return config.activeDurationMinutes * 60
end

local function getStateSnapshot()
    local activeLimit = getActiveLimitSeconds()
    local nextBreakSeconds = math.max(0, activeLimit - activeSeconds)
    return {
        inBreak = inBreak,
        isLongBreak = isLongBreak,
        isPaused = isPaused,
        isSystemIdle = isSystemIdle,
        activeSeconds = activeSeconds,
        activeLimit = activeLimit,
        nextBreakSeconds = nextBreakSeconds,
        idleSeconds = idleSeconds,
        breakRemaining = breakRemaining,
        breakTotal = breakTotal,
        completedToday = completedToday,
        shortBreaksSinceLong = shortBreaksSinceLong,
        longBreakInterval = config.longBreakInterval,
        exerciseId = currentExercise.id,
        exerciseGlyph = currentExercise.glyph,
        exerciseTitleKey = currentExercise.titleKey,
        exerciseDescKey = currentExercise.descKey,
    }
end

local function broadcast()
    noctalia.state.set("clarity.state", getStateSnapshot())
end

local function startBreak(forceLong: boolean?)
    local dueForLong = forceLong == true
        or (config.longBreakInterval > 0 and shortBreaksSinceLong >= config.longBreakInterval)

    inBreak = true
    isLongBreak = dueForLong
    isPaused = false
    activeSeconds = 0
    snoozeRemaining = 0

    if isLongBreak then
        currentExercise = exercises.LONG_EXERCISE
        breakTotal = config.longBreakDurationSeconds
        breakRemaining = breakTotal
    else
        currentExercise = exercises.getShort(exerciseIndex)
        breakTotal = config.breakDurationSeconds
        breakRemaining = breakTotal
    end

    playChime("message")

    if config.enableNotifications then
        local title = if isLongBreak
            then noctalia.tr("notification.long-break-title")
            else noctalia.tr("notification.break-title")
        noctalia.notify(title, noctalia.tr(currentExercise.titleKey))
    end

    broadcast()
    openPanel()
end

local function finishBreak(counted: boolean)
    local wasLong = isLongBreak
    inBreak = false
    isLongBreak = false
    breakRemaining = 0
    activeSeconds = 0
    snoozeRemaining = 0

    if counted then
        local nowDate = getTodayKey()
        if nowDate ~= todayKey then
            todayKey = nowDate
            completedToday = 0
        end
        completedToday += 1
        if wasLong then
            shortBreaksSinceLong = 0
        else
            shortBreaksSinceLong += 1
            exerciseIndex = (exerciseIndex % #exercises.SHORT_EXERCISES) + 1
            currentExercise = exercises.getShort(exerciseIndex)
        end
        saveStats()

        playChime("complete")
        if config.enableNotifications then
            noctalia.notify(
                noctalia.tr("notification.break-finished-title"),
                noctalia.tr("notification.break-finished-body")
            )
        end
    end

    broadcast()
    closePanel()
end

local function snoozeBreak(seconds: number)
    inBreak = false
    isLongBreak = false
    breakRemaining = 0
    activeSeconds = 0
    snoozeRemaining = seconds
    isPaused = false
    broadcast()
    closePanel()
end

noctalia.state.watch("clarity.cmd", function(cmd)
    if not cmd or type(cmd) ~= "string" or cmd == "" then
        return
    end

    if cmd == "triggerBreak" then
        startBreak(false)
    elseif cmd == "triggerLongBreak" then
        startBreak(true)
    elseif cmd == "skip" then
        if inBreak then
            exerciseIndex = (exerciseIndex % #exercises.SHORT_EXERCISES) + 1
            currentExercise = exercises.getShort(exerciseIndex)
            saveStats()
            finishBreak(false)
        end
    elseif cmd == "nextExercise" then
        if inBreak and not isLongBreak then
            exerciseIndex = (exerciseIndex % #exercises.SHORT_EXERCISES) + 1
            currentExercise = exercises.getShort(exerciseIndex)
            saveStats()
            broadcast()
        end
    elseif cmd == "togglePause" then
        if not inBreak then
            isPaused = not isPaused
            broadcast()
        end
    elseif cmd == "reset" then
        inBreak = false
        isLongBreak = false
        breakRemaining = 0
        activeSeconds = 0
        snoozeRemaining = 0
        isPaused = false
        broadcast()
    else
        local snoozeSecs = tonumber(cmd:match("^snooze:(%d+)$"))
        if snoozeSecs and snoozeSecs > 0 then
            snoozeBreak(snoozeSecs)
        end
    end

    noctalia.state.set("clarity.cmd", "")
end)

function onSettingChanged(_key: string, _value: any)
    config = loadConfig()
    broadcast()
end

function onConfigChanged()
    config = loadConfig()
    broadcast()
end

function onIpc(event: string, payload: any)
    if event == "idled" then
        isSystemIdle = true
        broadcast()
    elseif event == "active" then
        isSystemIdle = false
        broadcast()
    elseif event == "command" and payload then
        noctalia.state.set("clarity.cmd", tostring(payload))
    elseif event and event ~= "" then
        noctalia.state.set("clarity.cmd", event)
    end
end

noctalia.setUpdateInterval(1000)
function update()
    local nowDate = getTodayKey()
    if nowDate ~= todayKey then
        todayKey = nowDate
        completedToday = 0
        saveStats()
    end

    local transitionedToActive = (wasSystemIdle and not isSystemIdle)
    wasSystemIdle = isSystemIdle

    if inBreak then
        if transitionedToActive then
            local elapsed = breakTotal - breakRemaining
            finishBreak(elapsed >= math.min(10, breakTotal))
            return
        end

        if breakRemaining > 1 then
            breakRemaining -= 1
            broadcast()
        else
            finishBreak(true)
        end
        return
    end

    if isPaused then
        return
    end

    if isSystemIdle then
        idleSeconds += 1
        if idleSeconds >= config.breakDurationSeconds then
            activeSeconds = 0
            snoozeRemaining = 0
        end
        broadcast()
    else
        idleSeconds = 0
        activeSeconds += 1
        local limit = getActiveLimitSeconds()
        if activeSeconds >= limit then
            startBreak(false)
        else
            broadcast()
        end
    end
end

-- Automatic idle / lock detection via DBus (same reliable hook as eyecare)
if noctalia.commandExists and noctalia.commandExists("dbus-monitor") and noctalia.runStream then
    local sessionLoop = 'P=$PPID; while kill -0 "$P" 2>/dev/null; do dbus-monitor --session "interface=\'org.freedesktop.ScreenSaver\'" 2>/dev/null; sleep 3; done'
    noctalia.runStream(sessionLoop, function(line)
        if string.find(line, "ActiveChanged") then
            lastLineWasActiveChanged = true
        elseif lastLineWasActiveChanged then
            lastLineWasActiveChanged = false
            if string.find(line, "true") then
                isSystemIdle = true
                broadcast()
            elseif string.find(line, "false") then
                isSystemIdle = false
                broadcast()
            end
        end
    end)

    local systemLoop = 'P=$PPID; while kill -0 "$P" 2>/dev/null; do dbus-monitor --system "interface=\'org.freedesktop.login1.Session\'" 2>/dev/null; sleep 3; done'
    noctalia.runStream(systemLoop, function(line)
        if string.find(line, "member=Lock") then
            isSystemIdle = true
            broadcast()
        elseif string.find(line, "member=Unlock") then
            isSystemIdle = false
            broadcast()
        end
    end)
end

broadcast()

return {}
