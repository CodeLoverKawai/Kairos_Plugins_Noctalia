--!nonstrict
-- Clarity Eye-Care exercise catalog (codeloverkawai/clarity)

local M = {}

M.SHORT_EXERCISES = {
    {
        id = "rule20",
        glyph = "eye",
        titleKey = "exercise.rule20.title",
        descKey = "exercise.rule20.desc",
    },
    {
        id = "blink",
        glyph = "sparkles",
        titleKey = "exercise.blink.title",
        descKey = "exercise.blink.desc",
    },
    {
        id = "near-far",
        glyph = "focus-2",
        titleKey = "exercise.near-far.title",
        descKey = "exercise.near-far.desc",
    },
    {
        id = "palming",
        glyph = "moon",
        titleKey = "exercise.palming.title",
        descKey = "exercise.palming.desc",
    },
    {
        id = "figure8",
        glyph = "infinity",
        titleKey = "exercise.figure8.title",
        descKey = "exercise.figure8.desc",
    },
    {
        id = "peripheral",
        glyph = "arrows-maximize",
        titleKey = "exercise.peripheral.title",
        descKey = "exercise.peripheral.desc",
    },
}

M.LONG_EXERCISE = {
    id = "long-posture",
    glyph = "coffee",
    titleKey = "exercise.long-posture.title",
    descKey = "exercise.long-posture.desc",
}

function M.getShort(index: number)
    local count = #M.SHORT_EXERCISES
    local idx = ((index - 1) % count) + 1
    return M.SHORT_EXERCISES[idx]
end

return M
