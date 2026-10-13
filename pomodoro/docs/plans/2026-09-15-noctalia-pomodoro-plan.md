# Implementation Plan: Noctalia Pomodoro Pro

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement an independent, custom Pomodoro plugin for Noctalia Shell (`codeloverkawai/pomodoro`) featuring automatic continuous session progression, an in-panel interactive session target selector, and live total remaining time breakdown.

**Architecture:** Luau/TOML plugin adhering to Noctalia Plugin API v22. Headless `pomodoro.luau` service maintains reactive state and continuous cycle transitions via `noctalia.state`. `panel.luau` provides interactive session increments/decrements and dual time display. `widget.luau` displays session count and time on the status bar.

**Tech Stack:** Luau, TOML, Noctalia Shell Plugin API v22, `pw-play` / native sound, Git.

## Global Constraints
- Plugin ID: `codeloverkawai/pomodoro`
- Plugin API version: `22`
- Author: `CodeLoverKawai`
- Working Directory: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro`
- Zero external build tooling required (native Noctalia Luau runtime)

---

### Task 1: Repository Scaffolding, Manifests, Resources and Translations

**Files:**
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/catalog.toml`
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/plugin.toml`
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/translations/en.json`
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/translations/es.json`
- Copy: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/resources/*` (fonts, audio clips)

**Interfaces:**
- Produces: `catalog.toml` with `id = "codeloverkawai/pomodoro"`, `pomodoro/plugin.toml` with `[[widget]]`, `[[panel]]`, `[[service]]`.
- Translations: Keys for `sessions`, `target-sessions`, `total-remaining`, `work`, `short-break`, `long-break`, notifications.

- [ ] **Step 1: Create catalog.toml**
Define `[[plugin]]` entry with ID `codeloverkawai/pomodoro`, version `1.0.0`, author `CodeLoverKawai`.

- [ ] **Step 2: Copy sound and font resources**
Copy `JetBrainsMono-Regular.ttf`, `alarm.mp3`, and audio ticks from the existing plugin resources to `pomodoro/resources/`.

- [ ] **Step 3: Create pomodoro/plugin.toml**
Declare `work-duration`, `short-break-duration`, `long-break-duration`, `default-sessions` (default 4), `auto-start-breaks` (default true), `auto-start-work` (default true), and entries for `widget`, `panel`, `service`.

- [ ] **Step 4: Create translation files**
Provide English and Spanish translations for all UI labels, button states, and completion alerts.

- [ ] **Step 5: Verify syntax and linting**
Run: `noctalia plugins lint /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro`
Expected: Passes with 0 errors.

- [ ] **Step 6: Commit**
```bash
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro add catalog.toml pomodoro/
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro commit -m "feat: scaffold pomodoro plugin manifests, resources and translations"
```

---

### Task 2: Continuous Flow Headless Service (`pomodoro/src/pomodoro.luau`)

**Files:**
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/src/sounds.luau`
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/src/pomodoro.luau`

**Interfaces:**
- Consumes: Noctalia runtime APIs (`noctalia.state`, `noctalia.getConfig`, `noctalia.notify`, `noctalia.setUpdateInterval`).
- Produces: Reactive state `pomodoro.state`:
  `{ isRunning: boolean, secondsLeft: number, sessionPtr: { session: number, stage: number }, totalSessions: number, totalSecondsLeft: number, stageTotalSeconds: number, isCompleted: boolean }`.
- Commands handled: `"toggle"`, `"skip"`, `"reset"`, `"resetAll"`, `"setSessions:<N>"`.

- [ ] **Step 1: Implement sounds.luau**
Adapt audio player helper supporting native alarms, ticks/tocks, and clean fallbacks.

- [ ] **Step 2: Implement dynamic session data & total time calculator in pomodoro.luau**
Write helper `buildSessionData(totalSessions)` and `computeTotalSecondsLeft(sessionPtr, secondsLeft, sessionData)`.

- [ ] **Step 3: Implement continuous auto-progression loop**
In `update()` and stage expiration handler:
- When work stage finishes: play alarm, notify, advance to break stage, keep `isRunning = true` if `autoStartBreaks = true`.
- When break stage finishes:
  - If `session < totalSessions`: advance to next work session, keep `isRunning = true` if `autoStartWork = true`.
  - If `session == totalSessions`: play completion alarm, notify completion, set `isRunning = false`, `isCompleted = true`.

- [ ] **Step 4: Implement command listener**
Handle `"toggle"`, `"skip"`, `"reset"`, `"resetAll"`, and `"setSessions:<N>"` to dynamically adjust session goal between 1 and 12.

- [ ] **Step 5: Run linter verification**
Run: `noctalia plugins lint /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro`
Expected: 0 errors, 0 warnings.

- [ ] **Step 6: Commit**
```bash
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro add pomodoro/src/sounds.luau pomodoro/src/pomodoro.luau
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro commit -m "feat(service): implement continuous session flow and dynamic session calculation"
```

---

### Task 3: Interactive Panel with Session Selector and Time Breakdown (`pomodoro/src/panel.luau`)

**Files:**
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/src/panel.luau`

**Interfaces:**
- Consumes: `pomodoro.state`, `pomodoro.sessionData` from `noctalia.state`.
- Produces: Noctalia declarative UI tree with session target buttons `[-]` / `[+]`, main timer, stage label, and total remaining time badge.

- [ ] **Step 1: Implement time formatting helper**
Format seconds into `MM:SS` for the current stage, and `Xh Ym` / `Ym Zs` for the total remaining time.

- [ ] **Step 2: Implement session adjuster buttons and callbacks**
Clicking `[-]` decrements sessions (min 1) via `pomodoro.nextCommand = "setSessions:" .. math.max(1, totalSessions - 1)`.
Clicking `[+]` increments sessions (max 12) via `pomodoro.nextCommand = "setSessions:" .. math.min(12, totalSessions + 1)`.

- [ ] **Step 3: Build the UI tree with time metrics**
Render header (`Pomodoro Pro`), session selector row, stage title, large timer label, sub-labels (`Fase actual: 25m` and `Tiempo total restante: 1h 45m`), and control buttons (Start/Pause, Skip, Reset, Reset All).

- [ ] **Step 4: Lint check**
Run: `noctalia plugins lint /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro`
Expected: 0 errors.

- [ ] **Step 5: Commit**
```bash
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro add pomodoro/src/panel.luau
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro commit -m "feat(panel): add session selector and total remaining time display"
```

---

### Task 4: Status Bar Widget (`pomodoro/src/widget.luau`)

**Files:**
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro/src/widget.luau`

**Interfaces:**
- Consumes: `pomodoro.state`.
- Produces: Status bar widget showing glyph (`brain`/`coffee`), session counter (`[2/4]`), and countdown timer (`24:18`). Toggles `"codeloverkawai/pomodoro:panel"` on click.

- [ ] **Step 1: Implement bar widget rendering**
Show stage glyph and formatted text: `string.format("[%d/%d] %s", currentSession, totalSessions, formattedTime)`.
Clicking opens `codeloverkawai/pomodoro:panel`.

- [ ] **Step 2: Lint check**
Run: `noctalia plugins lint /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/pomodoro`
Expected: 0 errors.

- [ ] **Step 3: Commit**
```bash
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro add pomodoro/src/widget.luau
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro commit -m "feat(widget): add bar widget displaying session progress and timer"
```

---

### Task 5: Documentation, Noctalia Registration & End-to-End Verification

**Files:**
- Create: `/home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro/README.md`
- Modify: `~/.local/state/noctalia/settings.toml`

- [ ] **Step 1: Write README.md**
Include feature overview, session flow explanation, settings, and license.

- [ ] **Step 2: Register local source in Noctalia**
Execute:
`noctalia msg plugins source add local-pomodoro path /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro`

- [ ] **Step 3: Disable old pomodoro and enable new pomodoro**
Execute:
`noctalia msg plugins disable thepunkoff/pomodoro`
`noctalia msg plugins enable codeloverkawai/pomodoro`

- [ ] **Step 4: Update status bar widget in settings.toml**
Replace `thepunkoff/pomodoro:widget` with `codeloverkawai/pomodoro:widget`.

- [ ] **Step 5: Live verification**
- Verify Noctalia loads the service and widgets without errors (`tail -n 25 ~/.cache/noctalia/noctalia.log`).
- Toggle the panel: `noctalia msg panel-toggle codeloverkawai/pomodoro:panel`.
- Test session increment/decrement and verify total remaining time recalculation.
- Close panel: `noctalia msg panel-close codeloverkawai/pomodoro:panel`.

- [ ] **Step 6: Final Commit**
```bash
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro add README.md
git -C /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro commit -m "docs: add comprehensive README and finalize plugin release"
```
