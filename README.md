# Yamaha MX Genos-Style Arranger Suite

**Yamaha MX Genos-Style Arranger Suite** turns a **Yamaha MX88 / MX61 / MX49** into a real-time arranger-style workstation inspired by the **Yamaha Genos 2 / Tyros**, with support for a **Novation Launchpad Mini** and **Korg NanoKey2**.

---

## 🚀 Features

- **REAPER Inspector:** A ReaImGui control panel that follows the selected track.
- **Voice and arpeggio preview:** Picking a voice or arpeggio writes a MIDI config item at the edit cursor, sized to the arpeggio's bar count and holding the voice, arpeggio, and controller messages plus optional trigger notes, then plays it so the MX responds. Picking again replaces that item.
- **Category buttons:** Small buttons above the Voices and Arpeggios lists (for example `A.Gtr`, `ApKb`) jump to the first entry of that category.
- **MIDI arrangement blocks:** Read the MIDI configuration at the edit cursor. **Insert / Replace MIDI Config** writes bank, program, arpeggiator (CC89 and SysEx), and effect messages, plus the preview notes when enabled.
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

### Maintain the ReaPack index

The repository includes a Python 3 index generator that uses only the standard library and Git. After committing a release with its updated `@version`, run `python tools/reapack_index.py --scan` to regenerate `index.xml`, then `python tools/reapack_index.py --check` to verify it. The checker compares the index with all versioned manifests in Git history.

## ▶️ Run the Inspector and Create the Rig

1. Open `Actions > Show action list...`.
2. Search for `Yamaha MX Genos Inspector`, select it, and click **Run**.
3. In the Inspector, select the Yamaha MX MIDI input and output. Launchpad and nanoKEY2 inputs are optional; device choices are remembered by name and re-resolved if indexes change.
4. Click **Create Rig** to add the 16 MIDI channel tracks. Channels 1-15 record from the Yamaha MX, channel 16 uses the nanoKEY2 when selected or the Yamaha MX otherwise, and each track sends its corresponding channel to the selected Yamaha MX output. Tracks are not armed; each one arms when you select it. The Inspector prevents adding a duplicate master rig.
5. Select a channel track before using the voice, arpeggio, or MIDI configuration controls. Previews play from the edit cursor and only replace items named `[MX Config]`. Optionally use **Add...** in the Action List to assign a shortcut or toolbar button.

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

1. **Yamaha MX88 / MX61 / MX49:** Connect it to the computer over USB. Choose `Utility > Job > Quick Setup > Arp Rec` when you need the keyboard to send generated arpeggio notes back to REAPER; `DAW Rec` turns Arpeggio MIDI Out off.
2. **Yamaha MX88 / MX61 / MX49, Novation Launchpad Mini, and Korg NanoKey2:** Connect the hardware over USB. In REAPER, open `Preferences > Audio > MIDI Devices`, enable all three devices as MIDI inputs, and enable the Yamaha MX as a MIDI output. Then choose the corresponding devices in the Inspector.

---

## 📄 License

Developed by **José Cotrino** under the MIT License.
