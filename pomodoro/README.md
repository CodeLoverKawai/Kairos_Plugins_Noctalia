# Pomodoro Pro for Noctalia Shell 🧠🍅

A modern, highly customizable Pomodoro productivity plugin for **Noctalia Shell**, featuring continuous automatic stage flow, interactive session target configuration, live cumulative time calculations, sound alerts, and an orientation-aware status bar widget.

---

## ✨ Features

- **🔄 Continuous Automatic Flow**: Seamlessly transitions between focus intervals and rest periods (`work` ➔ `short break` ➔ `...` ➔ `long break`). Automatically stops and notifies you when your cycle target is reached.
- **🎯 Dynamic Session Target Selector**: Choose exactly how many sessions you plan to complete (1 to 12 sessions) directly from the dropdown panel with intuitive `[-]` and `[+]` controls. Recalculates remaining time dynamically.
- **⏳ Total Remaining Time Breakdown**: Always know how much time is left. The panel and widget tooltips display both current phase time and cumulative total time remaining for the entire session cycle (e.g. `1h 40m`).
- **📊 Adaptive Bar Widget**:
  - Automatically adapts to **horizontal** (`[X/N] MM:SS`) and **vertical** status bars (stacked `[X/N]\nMM\nSS`) to prevent layout overflows.
  - Contextual glyphs: `brain` for focus work, `coffee` for breaks, and customizable fallback icons.
  - State-reactive colors: `primary` when running, `on_surface` when paused/idle, and celebratory `secondary` upon cycle completion.
- **🔔 Audio Alerts & Soundscapes**:
  - Audio alarms when phases complete.
  - Optional focus ticking audio (powered by `ffplay`).
  - Bundled high-clarity alarm sound with option to bypass global sound mute.
- **🌐 Bilingual Localization**: Complete native support for English (`en`) and Spanish (`es`).

---

## 🏗️ Architecture & Session Flow

The Pomodoro cycle organizes your workflow into $N$ sessions:
- **Sessions $1$ to $N - 1$**: Focus Work period followed by a Short Break.
- **Session $N$**: Focus Work period followed by a Long Break.
- **Completion**: Once the long break finishes, the timer stops, marks the session cycle as completed, and sends a celebratory desktop notification.

```
Session 1: [ Work (25m) ] ➔ [ Short Break (5m) ]
Session 2: [ Work (25m) ] ➔ [ Short Break (5m) ]
   ...
Session N: [ Work (25m) ] ➔ [ Long Break (15m) ] ➔ [ 🎉 Cycle Completed! ]
```

---

## ⚙️ Configuration & Settings

Configurable via Noctalia Settings (`~/.local/state/noctalia/settings.toml` or the Settings UI):

| Setting Key | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `work-duration` | `int` | `25` | Duration of each focus work session (minutes) |
| `short-break-duration` | `int` | `5` | Duration of short breaks between work sessions (minutes) |
| `long-break-duration` | `int` | `15` | Duration of the final long break after $N$ sessions (minutes) |
| `default-sessions` | `int` | `4` | Initial target session count (1–12) |
| `auto-start-breaks` | `bool` | `true` | Automatically begin break when work timer ends |
| `auto-start-work` | `bool` | `true` | Automatically begin next work session when break ends |
| `enable-work-timer-sound`| `bool` | `false` | Enable subtle mechanical clock ticks during focus work |
| `use-bundled-alarm-sound`| `bool` | `false` | Use bundled alarm sound instead of system default |
| `bypass-noctalia-sound-globals` | `bool` | `false` | Bypass global mute for Pomodoro alarms |
| `widget-glyph-main` | `glyph`| `brain` | Icon shown when idle or cycle is finished |
| `widget-glyph-work` | `glyph`| `brain` | Icon shown during active work intervals |
| `widget-glyph-break` | `glyph`| `coffee` | Icon shown during break intervals |

---

## 🚀 Installation & Setup

### 1. Add Local Plugin Source
Register the repository directory as a local source in Noctalia:

```bash
noctalia msg plugins source add local-pomodoro path /home/kairos/Documents/GitHub/Universidad/Noctalia-pomodoro
```

### 2. Enable Pomodoro Pro
Enable the plugin (and disable any previous community pomodoro if installed):

```bash
noctalia msg plugins disable thepunkoff/pomodoro
noctalia msg plugins enable codeloverkawai/pomodoro
```

### 3. Add Widget to Status Bar
In your Noctalia settings file (`~/.local/state/noctalia/settings.toml`), assign the widget to your bar configuration:

```toml
[widget.widget]
type = "codeloverkawai/pomodoro:widget"
```

Then ensure `"widget"` is included in your bar section (`center`, `start`, or `end`).

### 4. Toggle Panel via CLI / Keybinds
You can toggle or close the panel control window at any time:

```bash
# Toggle panel
noctalia msg panel-toggle codeloverkawai/pomodoro:panel

# Close panel
noctalia msg panel-close codeloverkawai/pomodoro:panel
```

---

## 📂 Project Structure

```
Noctalia-pomodoro/
├── catalog.toml                  # Plugin catalog manifest
├── README.md                     # Documentation
├── LICENSE                       # MIT License
├── pomodoro/
│   ├── plugin.toml               # Manifest declaring service, panel, and bar widget
│   ├── resources/
│   │   ├── alarm.mp3             # Bundled alarm sound
│   │   └── tick*.wav / tock*.wav # Mechanical clock audio samples
│   ├── src/
│   │   ├── pomodoro.luau         # Headless service managing state & continuous cycles
│   │   ├── panel.luau            # Interactive panel UI with session target selector
│   │   ├── widget.luau           # Orientation-aware status bar widget
│   │   └── sounds.luau           # Audio playback logic
│   └── translations/
│       ├── en.json               # English localization
│       └── es.json               # Spanish localization
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) - see the [LICENSE](LICENSE) file for details.
