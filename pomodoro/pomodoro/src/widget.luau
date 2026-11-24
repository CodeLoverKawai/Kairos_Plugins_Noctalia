--!nonstrict
-- Pomodoro Pro status bar widget (codeloverkawai/pomodoro)
-- Displays session progress, countdown timer, and contextual stage glyph.

local function getGlyphMain(): string
    local val = noctalia.getConfig("widget-glyph-main")
    return if val and val ~= "" then val else "brain"
end

local function getGlyphWork(): string
    local val = noctalia.getConfig("widget-glyph-work")
    return if val and val ~= "" then val else "brain"
end

local function getGlyphBreak(): string
    local val = noctalia.getConfig("widget-glyph-break")
    return if val and val ~= "" then val else "coffee"
end

local function formatCountdown(seconds: number): (number, number, number)
    local s = math.max(0, seconds)
    local hours = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = s % 60
    return hours, mins, secs
end

local function formatTotalRemaining(totalSeconds: number): string
    local s = math.max(0, totalSeconds)
    if s == 0 then
        return "0m"
    end

    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60

    if h > 0 then
        if m > 0 then
            return string.format("%dh %dm", h, m)
        else
            return string.format("%dh", h)
        end
    elseif m > 0 then
        if sec > 0 then
            return string.format("%dm %ds", m, sec)
        else
            return string.format("%dm", m)
        end
    else
        return string.format("%ds", sec)
    end
end

function onClick()
    noctalia.togglePanel("codeloverkawai/pomodoro:panel")
end

function onRightClick()
    noctalia.state.set("pomodoro.nextCommand", "toggle")
end

function onMiddleClick()
    noctalia.state.set("pomodoro.nextCommand", "toggleMusicMute")
end

local function render()
    local state = noctalia.state.get("pomodoro.state")
    local sessionData = noctalia.state.get("pomodoro.sessionData")

    local isRunning = if state and state.isRunning ~= nil then state.isRunning else false
    local isCompleted = if state and state.isCompleted ~= nil then state.isCompleted else false
    local isDirty = if state and state.isDirty ~= nil then state.isDirty else false
    local sessionNumber = if state and state.sessionPtr then state.sessionPtr.session else 1
    local stageNumber = if state and state.sessionPtr then state.sessionPtr.stage else 1
    local totalSessions = if state and state.totalSessions then state.totalSessions else (if sessionData then #sessionData else 4)
    local secondsLeft = if state and state.secondsLeft ~= nil then state.secondsLeft else (25 * 60)
    local totalSecondsLeft = if state and state.totalSecondsLeft ~= nil then state.totalSecondsLeft else 0

    if totalSessions < 1 then totalSessions = 1 end
    if sessionNumber < 1 then sessionNumber = 1 end
    if sessionNumber > totalSessions then sessionNumber = totalSessions end

    local glyphName = if isCompleted then
        getGlyphMain()
    elseif not isDirty and not isRunning then
        getGlyphMain()
    elseif stageNumber == 1 then
        getGlyphWork()
    else
        getGlyphBreak()

    local color = if isCompleted then
        "secondary"
    elseif isRunning then
        "primary"
    else
        "on_surface"

    local hours, mins, secs = formatCountdown(secondsLeft)
    local isVertical = if barWidget and barWidget.isVertical then barWidget.isVertical() else false

    local textLabel: string
    if isVertical then
        if hours > 0 then
            textLabel = string.format("[%d/%d]\n%02d\n%02d\n%02d", sessionNumber, totalSessions, hours, mins, secs)
        else
            textLabel = string.format("[%d/%d]\n%02d\n%02d", sessionNumber, totalSessions, mins, secs)
        end
    else
        if hours > 0 then
            textLabel = string.format("[%d/%d] %d:%02d:%02d", sessionNumber, totalSessions, hours, mins, secs)
        else
            textLabel = string.format("[%d/%d] %02d:%02d", sessionNumber, totalSessions, mins, secs)
        end
    end

    local phaseName = if stageNumber == 1 then
        noctalia.tr("work")
    elseif sessionNumber < totalSessions then
        noctalia.tr("short-break")
    else
        noctalia.tr("long-break")

    local sessionWord = noctalia.tr("session")
    local remainingWord = noctalia.tr("remaining")
    local totalWord = noctalia.tr("total")

    local timeStr = if hours > 0 then
        string.format("%d:%02d:%02d", hours, mins, secs)
    else
        string.format("%02d:%02d", mins, secs)

    local totalStr = formatTotalRemaining(totalSecondsLeft)

    local tooltipText = if isCompleted then
        string.format("%s: %s", noctalia.tr("completed"), noctalia.tr("notification.all-complete"))
    else
        string.format(
            "%s %d/%d (%s) - %s: %s - %s: %s",
            sessionWord,
            sessionNumber,
            totalSessions,
            phaseName,
            remainingWord,
            timeStr,
            totalWord,
            totalStr
        )

    local container = if isVertical then ui.column else ui.row
    local content = {
        ui.glyph({
            name = glyphName,
            color = color,
        }),
        ui.label({
            text = textLabel,
            textAlign = "center",
            color = color,
        }),
    }

    if barWidget and barWidget.render then
        barWidget.render(container({ gap = 4, align = "center", justify = "center" }, content))
    end

    if barWidget and barWidget.setTooltip then
        barWidget.setTooltip(tooltipText)
    end
end

local function refresh()
    render()
end

noctalia.state.watch("pomodoro.state", function(_state)
    refresh()
end)

noctalia.state.watch("pomodoro.sessionData", function(_sessionData)
    refresh()
end)

refresh()

return {}
