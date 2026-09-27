# Yamaha MX Genos-Style Arranger Suite

**Yamaha MX Genos-Style Arranger Suite** turns a **Yamaha MX88 / MX61 / MX49** into a real-time arranger-style workstation inspired by the **Yamaha Genos 2 / Tyros**, with support for a **Novation Launchpad Mini** and **Korg NanoKey2**.

---

## 🚀 Features

- **REAPER Inspector:** A ReaImGui control panel that follows the selected track.
- **Live Am chord audition:** Voice, arpeggio, and CC changes can audition an extended Am chord ($A2, E3, A3, C4, E4, G4, B4$) on the hardware synthesizer.
- **MIDI arrangement blocks:** Read the MIDI configuration at the edit cursor. **Insert / Replace MIDI Config** writes bank, program, arpeggiator (CC89), and effect messages without adding notes.
- **Launchpad Mini style controls:**
  - Row 1: Registration memories (*Scenes 1-8*).
  - Row 2: Style sections (`Intro A/B`, `Ending A/B`).
  - Row 3: Main variations (`Main A`, `Main B`, `Main C`, `Main D`).
  - Row 4: Transitions (`Fill-In`, `Break`).
- **Korg NanoKey2 track and mixer controls:**
  - C1-D#2: Select MIDI channels 1-16.
  - E2 / F2: Mute / Solo the active track.
  - F#2 / G2: Adjust track volume by -1 / +1 dB.
- **JSFX tools:**
  - `Yamaha_MX_Control.jsfx`: MIDI and SysEx control for Yamaha MX hardware.
  - `Yamaha_MX_Chord_Detector.jsfx`: Real-time chord analysis for the left hand.
- **Studio tools:** Freeze tracks to render external hardware and show CC automation lanes.

---

## 📦 Requirements and Installation

You need REAPER, [ReaPack](https://reapack.com/), and **ReaImGui**. ReaImGui supplies the GUI API used by the Inspector and is installed separately.

### Install ReaImGui

1. In REAPER, open `Extensions > ReaPack > Browse packages...`.
2. Search for `ReaImGui: ReaScript binding for Dear ImGui`, select it for installation, then click **Apply**.
3. If it is missing, check that **ReaTeam Extensions** is enabled under `Extensions > ReaPack > Manage repositories...`. If needed, import `https://github.com/ReaTeam/Extensions/raw/master/index.xml`, synchronize ReaPack, and search again.
4. Restart REAPER if the Inspector still reports that ReaImGui is missing.

If ReaPack reports `Timeout was reached` while downloading from `codeberg.org`, the download stalled; it is not a suite error. Retry later. The `demo.lua` example is not required by this suite. On Windows x64, you can instead download the official `reaper_imgui-x64.dll` from [ReaImGui Releases](https://codeberg.org/cfillion/reaimgui/releases), open `Options > Show REAPER resource path in explorer/finder...`, copy the DLL into `UserPlugins`, and restart REAPER. Use only the official release and the binary matching your REAPER architecture.

### Install the Suite

1. Open `Extensions > ReaPack > Import repositories...` and import this index: `https://raw.githubusercontent.com/cotrino/yamaha-mx-genos-suite/master/index.xml`.
2. Run `Extensions > ReaPack > Synchronize packages...` and wait for it to finish.
3. In `Extensions > ReaPack > Browse packages...`, search for `Yamaha MX Genos Inspector`, select the latest version, and click **Apply**.

The ReaPack package includes the Lua modules, both JSFX, the track template, the Yamaha MX49 ReaBank, and the Yamaha MX88 arpeggio CSV. The bank and arpeggio files are loaded automatically from the package's `data` folder. If either file is missing or unreadable, the Inspector displays the expected file paths instead of opening with empty lists.

## ▶️ Run the Inspector and Create the Rig

1. Open `Actions > Show action list...`.
2. Search for `Yamaha MX Genos Inspector`, select it, and click **Run**.
3. Click **Create Rig** in the Inspector to add the 16 MIDI channel tracks and their hardware outputs to the current project. It creates the layout from the included **Yamaha MX Genos Full Rig** template and prevents adding a duplicate master rig.
4. Select a channel track before using the voice, arpeggio, or MIDI configuration controls. Optionally use **Add...** in the Action List to assign a shortcut or toolbar button.

The installed template is also available from `Insert > Track from template > Yamaha MX Genos Full Rig`.

## 🎛️ Add the JSFX

The JSFX files are installed with the suite. In REAPER's **FX Browser**, search for an effect and drag it onto the relevant MIDI track's FX chain, or open that track's **FX** window:

- **Yamaha MX Hardware Controller:** Sends bank, program, controller, and arpeggio messages to the synthesizer. This version sends on MIDI channel 1.
- **Yamaha MX Real-Time Chord Detector:** Analyzes MIDI notes in its configured split range and passes MIDI through. Put it on the MIDI path receiving left-hand notes.

If the effects do not appear, synchronize ReaPack and refresh the FX list.

## 🗂️ Dock the Inspector

The Inspector opens as a ReaImGui window. Drag its title bar to a REAPER Docker and release when the docking indicator appears. ReaImGui docking is enabled by default in current releases; depending on the REAPER/ReaImGui version, the window's context menu may also offer a **Move to Docker** command.

---

## 🎹 Hardware Setup

1. **Yamaha MX88 / MX61 / MX49:** On the keyboard, choose `Utility > Job > Quick Setup > DAW Record`, then connect it to the computer over USB.
2. **Novation Launchpad Mini and Korg NanoKey2:** Connect both controllers over USB. In REAPER, open `Preferences > Audio > MIDI Devices` and enable each controller for input and control messages.

---

## 📄 License

Developed by **José Cotrino** under the MIT License.
