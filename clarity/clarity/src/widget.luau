--!nonstrict
-- Clarity Eye-Care status bar widget (codeloverkawai/clarity)

local function formatMMSS(seconds: number): string
    local s = math.max(0, math.floor(seconds))
    local mins = math.floor(s / 60)
    local secs = s % 60
    return string.format("%02d:%02d", mins, secs)
end

function onClick()
    noctalia.togglePanel("codeloverkawai/clarity:panel")
end

function onRightClick()
    noctalia.state.set("clarity.cmd", "togglePause")
end

function onMiddleClick()
    noctalia.state.set("clarity.cmd", "triggerBreak")
end

local function render()
    local state = noctalia.state.get("clarity.state")
    local inBreak = state and state.inBreak == true
    local isPaused = state and state.isPaused == true
    local isSystemIdle = state and state.isSystemIdle == true
    local nextBreakSeconds = if state and state.nextBreakSeconds then state.nextBreakSeconds else (20 * 60)
    local breakRemaining = if state and state.breakRemaining then state.breakRemaining else 0
    local idleSeconds = if state and state.idleSeconds then state.idleSeconds else 0
    local completedToday = if state and state.completedToday then state.completedToday else 0
    local exerciseTitleKey = if state and state.exerciseTitleKey then state.exerciseTitleKey else "exercise.rule20.title"

    local isVertical = if barWidget and barWidget.isVertical then barWidget.isVertical() else false

    local glyphName = "eye"
    local color = "on_surface"
    local textLabel = formatMMSS(nextBreakSeconds)
    local tooltipText = ""

    if isSystemIdle then
        glyphName = "coffee"
        color = "on_surface_variant"
        textLabel = if isVertical then string.format("%ds", idleSeconds) else string.format("Idle %ds", idleSeconds)
        tooltipText = string.format(noctalia.tr("tooltip.idle"), idleSeconds)
    elseif inBreak then
        glyphName = "sparkles"
        color = "primary"
        textLabel = string.format("%ds", breakRemaining)
        tooltipText = string.format(noctalia.tr("tooltip.break"), noctalia.tr(exerciseTitleKey), breakRemaining)
    elseif isPaused then
        glyphName = "eye-off"
        color = "on_surface_variant"
        textLabel = if isVertical then "||" else formatMMSS(nextBreakSeconds)
        tooltipText = string.format(noctalia.tr("tooltip.paused"), completedToday)
    else
        glyphName = "eye"
        color = "primary"
        textLabel = formatMMSS(nextBreakSeconds)
        tooltipText = string.format(noctalia.tr("tooltip.active"), formatMMSS(nextBreakSeconds), completedToday)
    end

    local container = if isVertical then ui.column else ui.row
    if barWidget and barWidget.render then
        barWidget.render(container({ gap = 4, align = "center", justify = "center" }, {
            ui.glyph({ name = glyphName, color = color }),
            ui.label({ text = textLabel, color = color, textAlign = "center" }),
        }))
    end

    if barWidget and barWidget.setTooltip then
        barWidget.setTooltip(tooltipText)
    end
end

noctalia.state.watch("clarity.state", function(_state)
    render()
end)

render()

return {}
