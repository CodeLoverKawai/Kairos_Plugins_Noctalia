--!nonstrict
-- Clarity Eye-Care floating panel (codeloverkawai/clarity)

local function formatMMSS(seconds: number): string
    local s = math.max(0, math.floor(seconds))
    local mins = math.floor(s / 60)
    local secs = s % 60
    return string.format("%02d:%02d", mins, secs)
end

function onSnooze2()
    noctalia.state.set("clarity.cmd", "snooze:120")
end

function onSnooze5()
    noctalia.state.set("clarity.cmd", "snooze:300")
end

function onNextExercise()
    noctalia.state.set("clarity.cmd", "nextExercise")
end

function onSkipBreak()
    noctalia.state.set("clarity.cmd", "skip")
end

function onTakeBreakNow()
    noctalia.state.set("clarity.cmd", "triggerBreak")
end

function onTogglePause()
    noctalia.state.set("clarity.cmd", "togglePause")
end

function onReset()
    noctalia.state.set("clarity.cmd", "reset")
end

local function render()
    local state = noctalia.state.get("clarity.state")
    local inBreak = state and state.inBreak == true
    local isLongBreak = state and state.isLongBreak == true
    local isPaused = state and state.isPaused == true
    local isSystemIdle = state and state.isSystemIdle == true
    local nextBreakSeconds = if state and state.nextBreakSeconds then state.nextBreakSeconds else (20 * 60)
    local breakRemaining = if state and state.breakRemaining then state.breakRemaining else 20
    local breakTotal = if state and state.breakTotal and state.breakTotal > 0 then state.breakTotal else 20
    local completedToday = if state and state.completedToday then state.completedToday else 0
    local shortBreaksSinceLong = if state and state.shortBreaksSinceLong then state.shortBreaksSinceLong else 0
    local longBreakInterval = if state and state.longBreakInterval then state.longBreakInterval else 4

    local exerciseGlyph = if state and state.exerciseGlyph then state.exerciseGlyph else "eye"
    local exerciseTitleKey = if state and state.exerciseTitleKey then state.exerciseTitleKey else "exercise.rule20.title"
    local exerciseDescKey = if state and state.exerciseDescKey then state.exerciseDescKey else "exercise.rule20.desc"

    local badgeText =
        if inBreak then
            (if isLongBreak then noctalia.tr("badge.long-break") else noctalia.tr("badge.short-break"))
        elseif isSystemIdle then
            noctalia.tr("badge.idle")
        elseif isPaused then
            noctalia.tr("badge.paused")
        else
            noctalia.tr("badge.active")

    local badgeFill = if inBreak then "primary/0.2" else "surface_variant/0.5"
    local todayBadge = string.format("👁 %d %s", completedToday, noctalia.tr("stats.today"))

    local bodyChildren = {}

    if inBreak then
        -- Guided Exercise View
        local progressRatio = math.max(0, math.min(1, (breakTotal - breakRemaining) / breakTotal))
        local filledBlocks = math.floor(progressRatio * 18)
        local progressStr = string.rep("━", filledBlocks) .. string.rep("─", 18 - filledBlocks)

        table.insert(bodyChildren, ui.column({
            align = "center",
            justify = "center",
            gap = 8,
            padding = 12,
            radius = 12,
            fill = "surface_variant/0.35",
        }, {
            ui.row({ align = "center", justify = "center", gap = 8 }, {
                ui.glyph({ name = exerciseGlyph, color = "primary" }),
                ui.label({
                    text = noctalia.tr(exerciseTitleKey),
                    fontSize = 16,
                    fontWeight = "bold",
                    color = "primary",
                }),
            }),
            ui.label({
                text = noctalia.tr(exerciseDescKey),
                fontSize = 13,
                color = "on_surface",
                textAlign = "center",
            }),
            ui.label({
                text = formatMMSS(breakRemaining),
                fontSize = 42,
                fontWeight = "bold",
                color = "primary",
            }),
            ui.label({
                text = progressStr,
                fontSize = 11,
                color = "primary",
            }),
        }))

        local actionRow = {}
        table.insert(actionRow, ui.button({
            text = noctalia.tr("button.snooze-2"),
            variant = "secondary",
            controlSize = "sm",
            onClick = "onSnooze2",
            flexGrow = 1,
            height = 30,
        }))
        table.insert(actionRow, ui.button({
            text = noctalia.tr("button.snooze-5"),
            variant = "secondary",
            controlSize = "sm",
            onClick = "onSnooze5",
            flexGrow = 1,
            height = 30,
        }))
        if not isLongBreak then
            table.insert(actionRow, ui.button({
                text = noctalia.tr("button.next-exercise"),
                glyph = "refresh",
                variant = "secondary",
                controlSize = "sm",
                onClick = "onNextExercise",
                flexGrow = 1,
                height = 30,
            }))
        end
        table.insert(actionRow, ui.button({
            text = noctalia.tr("button.skip"),
            glyph = "player-skip-forward",
            variant = "ghost",
            controlSize = "sm",
            onClick = "onSkipBreak",
            flexGrow = 1,
            height = 30,
        }))

        table.insert(bodyChildren, ui.row({ gap = 6 }, actionRow))
    else
        -- Dashboard / Standby View
        local cycleInfo = if longBreakInterval > 0
            then string.format("%s: %d/%d", noctalia.tr("stats.cycle-progress"), shortBreaksSinceLong, longBreakInterval)
            else ""

        table.insert(bodyChildren, ui.column({
            align = "center",
            justify = "center",
            gap = 6,
            padding = 14,
            radius = 12,
            fill = "surface_variant/0.35",
        }, {
            ui.label({
                text = noctalia.tr("stats.next-break"),
                fontSize = 13,
                color = "on_surface_variant",
            }),
            ui.label({
                text = formatMMSS(nextBreakSeconds),
                fontSize = 42,
                fontWeight = "bold",
                color = if isPaused then "secondary" else "primary",
            }),
            ui.label({
                text = string.format("%s • %s", noctalia.tr(exerciseTitleKey), cycleInfo),
                fontSize = 12,
                color = "on_surface_variant",
                textAlign = "center",
            }),
        }))

        table.insert(bodyChildren, ui.row({ gap = 8 }, {
            ui.button({
                text = noctalia.tr("button.take-break"),
                glyph = "sparkles",
                variant = "primary",
                onClick = "onTakeBreakNow",
                flexGrow = 1,
                height = 32,
            }),
        }))

        table.insert(bodyChildren, ui.row({ gap = 8 }, {
            ui.button({
                text = if isPaused then noctalia.tr("button.resume") else noctalia.tr("button.pause"),
                glyph = if isPaused then "player-play" else "player-pause",
                variant = "secondary",
                onClick = "onTogglePause",
                flexGrow = 1,
                height = 30,
            }),
            ui.button({
                text = noctalia.tr("button.reset"),
                glyph = "rotate",
                variant = "secondary",
                onClick = "onReset",
                flexGrow = 1,
                height = 30,
            }),
        }))
    end

    local rootChildren = {
        -- Header
        ui.row({ align = "center", justify = "space_between" }, {
            ui.row({ align = "center", gap = 8 }, {
                ui.glyph({ name = "eye", color = "primary" }),
                ui.label({
                    text = noctalia.tr("title"),
                    fontSize = 16,
                    fontWeight = "bold",
                    color = "on_surface",
                }),
            }),
            ui.row({ align = "center", gap = 6 }, {
                ui.row({
                    align = "center",
                    paddingH = 8,
                    paddingV = 2,
                    radius = 10,
                    fill = badgeFill,
                }, {
                    ui.label({
                        text = badgeText,
                        fontSize = 11,
                        fontWeight = "medium",
                        color = "primary",
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
                        text = todayBadge,
                        fontSize = 11,
                        fontWeight = "medium",
                        color = "on_surface",
                    }),
                }),
            }),
        }),
    }

    for _, child in bodyChildren do
        table.insert(rootChildren, child)
    end

    panel.render(ui.column({ flexGrow = 1, gap = 10, padding = 14 }, rootChildren))
end

function onOpen(_context)
    render()
end

noctalia.state.watch("clarity.state", function(_state)
    render()
end)

render()

return {}
