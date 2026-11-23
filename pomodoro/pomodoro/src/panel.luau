--!nonstrict
-- Pomodoro Pro panel (codeloverkawai/pomodoro)
-- Declarative UI panel with session selector, dual time display, and cycle controls.

local timeFontFamily = noctalia.loadFont("resources/JetBrainsMono-Regular.ttf")

local function formatCountdown(seconds: number, total: number): string
    local s = math.max(0, seconds)
    local showingHours = total >= 3600 or s >= 3600
    local hours = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = s % 60

    if showingHours then
        return string.format("%d:%02d:%02d", hours, mins, secs)
    else
        return string.format("%02d:%02d", mins, secs)
    end
end

local function formatDuration(seconds: number): string
    local s = math.max(0, seconds)
    local hours = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = s % 60

    if hours > 0 then
        if mins > 0 then
            return string.format("%dh %dm", hours, mins)
        else
            return string.format("%dh", hours)
        end
    elseif mins > 0 then
        if secs > 0 then
            return string.format("%dm %ds", mins, secs)
        else
            return string.format("%dm", mins)
        end
    else
        return string.format("%ds", secs)
    end
end

local function formatTotalRemaining(totalSeconds: number): string
    local s = math.max(0, totalSeconds)
    if s == 0 then
        return "0m"
    end

    local hours = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = s % 60

    if hours > 0 then
        if mins > 0 then
            return string.format("%dh %dm", hours, mins)
        else
            return string.format("%dh", hours)
        end
    elseif mins > 0 then
        if secs > 0 then
            return string.format("%dm %ds", mins, secs)
        else
            return string.format("%dm", mins)
        end
    else
        return string.format("%ds", secs)
    end
end

function onStartButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "toggle")
end

function onSkipButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "skip")
end

function onResetButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "reset")
end

function onResetAllButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "resetAll")
end

function onDecrementSessions()
    local state = noctalia.state.get("pomodoro.state")
    local total = if state and state.totalSessions then state.totalSessions else 4
    local target = math.max(1, total - 1)
    noctalia.state.set("pomodoro.nextCommand", "setSessions:" .. target)
end

function onIncrementSessions()
    local state = noctalia.state.get("pomodoro.state")
    local total = if state and state.totalSessions then state.totalSessions else 4
    local target = math.min(12, total + 1)
    noctalia.state.set("pomodoro.nextCommand", "setSessions:" .. target)
end

function onPresetClasico()
    noctalia.state.set("pomodoro.nextCommand", "setPreset:clasico")
end

function onPresetDeep()
    noctalia.state.set("pomodoro.nextCommand", "setPreset:deep")
end

function onPresetUltra()
    noctalia.state.set("pomodoro.nextCommand", "setPreset:ultra")
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
    local stageTotalSeconds = if state and state.stageTotalSeconds ~= nil then state.stageTotalSeconds else (25 * 60)
    local totalSecondsLeft = if state and state.totalSecondsLeft ~= nil then state.totalSecondsLeft else 0

    if totalSessions < 1 then totalSessions = 1 end
    if sessionNumber < 1 then sessionNumber = 1 end
    if sessionNumber > totalSessions then sessionNumber = totalSessions end

    local stageName =
        if isCompleted then
            noctalia.tr("completed")
        elseif stageNumber == 1 then
            noctalia.tr("work")
        elseif sessionNumber < totalSessions then
            noctalia.tr("short-break")
        else
            noctalia.tr("long-break")

    local stageIcon =
        if stageNumber == 1 then
            "brain"
        else
            "coffee"

    local startButtonText =
        if isRunning then
            noctalia.tr("button.pause")
        elseif isCompleted then
            noctalia.tr("button.start")
        elseif secondsLeft > 0 and secondsLeft < stageTotalSeconds then
            noctalia.tr("button.resume")
        else
            noctalia.tr("button.start")

    local startButtonGlyph = if isRunning then "player-pause" else "player-play"
    local startButtonVariant = if isRunning then "secondary" else "primary"

    local skipButtonEnabled = not isCompleted
    local resetButtonEnabled = isCompleted or isDirty or (secondsLeft < stageTotalSeconds) or isRunning
    local resetAllButtonEnabled = isCompleted or isDirty or isRunning or (sessionNumber > 1 or stageNumber > 1 or secondsLeft < stageTotalSeconds)

    local sessionBadgeText = string.format("%s %d/%d", noctalia.tr("session"), sessionNumber, totalSessions)
    local sessionGoalText = string.format("🎯 %d %s", totalSessions, noctalia.tr("sessions"))

    local currentPhaseText = string.format("%s: %s", noctalia.tr("current-phase"), formatDuration(stageTotalSeconds))
    local totalRemainingText = string.format("%s: %s", noctalia.tr("total-remaining"), formatTotalRemaining(totalSecondsLeft))

    local centerContent = {}

    if isCompleted then
        table.insert(centerContent, ui.row({
            align = "center",
            justify = "center",
            paddingH = 10,
            paddingV = 2,
            radius = 8,
            fill = "primary/0.15",
        }, {
            ui.label({
                text = string.format("🎉 %s 🎉", noctalia.tr("completed")),
                fontSize = 14,
                fontWeight = "bold",
                color = "primary",
            }),
        }))
        table.insert(centerContent, ui.label({
            text = "00:00",
            fontSize = 38,
            fontWeight = "bold",
            fontFamily = timeFontFamily,
            color = "primary",
        }))
        table.insert(centerContent, ui.label({
            text = noctalia.tr("notification.all-complete"),
            fontSize = 11,
            fontWeight = "medium",
            color = "on_surface_variant",
        }))
    else
        local isPausedMidSession = not isRunning and not isCompleted and secondsLeft > 0 and secondsLeft < stageTotalSeconds
        local displayStageName = if isPausedMidSession then string.format("%s • %s", stageName, noctalia.tr("paused")) else stageName
        table.insert(centerContent, ui.label({
            text = displayStageName,
            fontSize = 15,
            fontWeight = "medium",
            color = if isPausedMidSession then "secondary" else "primary",
        }))
        table.insert(centerContent, ui.label({
            text = formatCountdown(secondsLeft, stageTotalSeconds),
            fontSize = 38,
            fontWeight = "bold",
            fontFamily = timeFontFamily,
            color = "primary",
        }))
        table.insert(centerContent, ui.row({ align = "center", justify = "center", gap = 8 }, {
            ui.label({
                text = currentPhaseText,
                fontSize = 11,
                color = "on_surface_variant",
            }),
            ui.label({
                text = "•",
                fontSize = 11,
                color = "outline",
            }),
            ui.label({
                text = totalRemainingText,
                fontSize = 11,
                color = "on_surface_variant",
            }),
        }))
    end

    panel.render(
        ui.column({ flexGrow = 1, gap = 8, padding = 12 }, {
            -- 1. Header Row
            ui.row({ align = "center", justify = "space_between" }, {
                ui.row({ align = "center", gap = 8 }, {
                    ui.glyph({ name = stageIcon, color = "primary" }),
                    ui.label({
                        text = "Pomodoro Pro",
                        fontSize = 16,
                        fontWeight = "bold",
                        color = "on_surface",
                    }),
                }),
                ui.row({
                    align = "center",
                    paddingH = 8,
                    paddingV = 2,
                    radius = 10,
                    fill = "surface_variant/0.5",
                }, {
                    ui.label({
                        text = sessionBadgeText,
                        fontSize = 12,
                        fontWeight = "medium",
                        color = "primary",
                    }),
                }),
            }),

            -- 2. Session Configurator Row
            ui.row({ align = "center", justify = "center", gap = 10 }, {
                ui.button({
                    text = "-",
                    variant = "secondary",
                    controlSize = "sm",
                    onClick = "onDecrementSessions",
                    enabled = totalSessions > 1,
                    width = 30,
                    height = 24,
                }),
                ui.label({
                    text = sessionGoalText,
                    fontSize = 13,
                    fontWeight = "medium",
                    color = "on_surface",
                }),
                ui.button({
                    text = "+",
                    variant = "secondary",
                    controlSize = "sm",
                    onClick = "onIncrementSessions",
                    enabled = totalSessions < 12,
                    width = 30,
                    height = 24,
                }),
            }),

            -- 2b. Named Presets Row
            ui.row({ align = "center", justify = "center", gap = 8 }, {
                ui.button({
                    text = noctalia.tr("preset.clasico"),
                    variant = if (noctalia.state.get("pomodoro.config") or {}).workDuration == 25 then "primary" else "ghost",
                    controlSize = "sm",
                    onClick = "onPresetClasico",
                    height = 24,
                }),
                ui.button({
                    text = noctalia.tr("preset.deep"),
                    variant = if (noctalia.state.get("pomodoro.config") or {}).workDuration == 50 then "primary" else "ghost",
                    controlSize = "sm",
                    onClick = "onPresetDeep",
                    height = 24,
                }),
                ui.button({
                    text = noctalia.tr("preset.ultra"),
                    variant = if (noctalia.state.get("pomodoro.config") or {}).workDuration == 90 then "primary" else "ghost",
                    controlSize = "sm",
                    onClick = "onPresetUltra",
                    height = 24,
                }),
            }),

            -- 3. Stage & Large Time Display + Time Breakdown
            ui.column({ align = "center", justify = "center", gap = 2 }, centerContent),

            -- 4. Action Buttons
            ui.column({ gap = 6 }, {
                ui.row({ gap = 8 }, {
                    ui.button({
                        variant = startButtonVariant,
                        text = startButtonText,
                        glyph = startButtonGlyph,
                        onClick = "onStartButtonClick",
                        flexGrow = 1,
                        height = 30,
                    }),
                    ui.button({
                        variant = "secondary",
                        text = noctalia.tr("button.skip"),
                        glyph = "player-skip-forward",
                        onClick = "onSkipButtonClick",
                        enabled = skipButtonEnabled,
                        flexGrow = 1,
                        height = 30,
                    }),
                }),
                ui.row({ gap = 8 }, {
                    ui.button({
                        variant = "secondary",
                        text = noctalia.tr("button.reset"),
                        glyph = "refresh",
                        onClick = "onResetButtonClick",
                        enabled = resetButtonEnabled,
                        flexGrow = 1,
                        height = 30,
                    }),
                    ui.button({
                        variant = "secondary",
                        text = noctalia.tr("button.reset-all"),
                        glyph = "rotate",
                        onClick = "onResetAllButtonClick",
                        enabled = resetAllButtonEnabled,
                        flexGrow = 1,
                        height = 30,
                    }),
                }),
            }),
        })
    )
end

local function refresh()
    render()
end

function onOpen(_context)
    refresh()
end

noctalia.state.watch("pomodoro.state", function(_state)
    refresh()
end)

noctalia.state.watch("pomodoro.sessionData", function(_sessionData)
    refresh()
end)

function onIpc(event: string, payload: any)
    if event == "increment" then
        onIncrementSessions()
    elseif event == "decrement" then
        onDecrementSessions()
    elseif event == "toggle" then
        onStartButtonClick()
    elseif event == "skip" then
        onSkipButtonClick()
    elseif event == "reset" then
        onResetButtonClick()
    elseif event == "resetAll" then
        onResetAllButtonClick()
    elseif event == "command" and payload then
        noctalia.state.set("pomodoro.nextCommand", tostring(payload))
    elseif event and event ~= "" then
        noctalia.state.set("pomodoro.nextCommand", event)
    end
end

refresh()

return {}

