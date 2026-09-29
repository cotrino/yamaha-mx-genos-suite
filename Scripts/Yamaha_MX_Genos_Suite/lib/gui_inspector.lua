-- @noindex
local reaper = reaper
local GUI = {}

local ctx = reaper.ImGui_CreateContext('Yamaha MX Genos Inspector')
local selected_prg_idx = 1
local selected_arp_idx = 1
local arp_sw = true
local rev_val = 40
local cho_val = 0
local cut_val = 64
local res_val = 64

local search_prg = ""
local search_arp = ""
local last_cursor_pos = -1
local settings_section = "Yamaha MX Genos Inspector"
local device_config = {
  yamaha_input_name = reaper.GetExtState(settings_section, "yamaha_input"),
  launchpad_input_name = reaper.GetExtState(settings_section, "launchpad_input"),
  nanokey_input_name = reaper.GetExtState(settings_section, "nanokey_input"),
  yamaha_output_name = reaper.GetExtState(settings_section, "yamaha_output")
}

local function enumerate_devices(count_fn, name_fn)
  local devices = {}
  for id = 0, count_fn() - 1 do
    local ok, name = name_fn(id, "")
    if ok and name and name ~= "" then
      devices[#devices + 1] = { id = id, name = name }
    end
  end
  return devices
end

local function contains(text, fragment)
  return text:lower():find(fragment, 1, true) ~= nil
end

local function resolve_device(devices, name, keywords)
  if name ~= "" then
    for _, device in ipairs(devices) do
      if device.name == name then return device end
    end
    return nil
  end

  for _, device in ipairs(devices) do
    local matches = true
    for _, keyword in ipairs(keywords) do
      if not contains(device.name, keyword) then
        matches = false
        break
      end
    end
    if matches then return device end
  end
  return nil
end

function GUI.get_device_config()
  local inputs = enumerate_devices(reaper.GetNumMIDIInputs, reaper.GetMIDIInputName)
  local outputs = enumerate_devices(reaper.GetNumMIDIOutputs, reaper.GetMIDIOutputName)
  local yamaha_input = resolve_device(inputs, device_config.yamaha_input_name, { "yamaha", "mx" })
  local launchpad_input = resolve_device(inputs, device_config.launchpad_input_name, { "launchpad" })
  local nanokey_input = resolve_device(inputs, device_config.nanokey_input_name, { "nanokey" })
  local yamaha_output = resolve_device(outputs, device_config.yamaha_output_name, { "yamaha", "mx" })

  local resolved_names = {
    yamaha_input = yamaha_input and yamaha_input.name,
    launchpad_input = launchpad_input and launchpad_input.name,
    nanokey_input = nanokey_input and nanokey_input.name,
    yamaha_output = yamaha_output and yamaha_output.name
  }
  for key, name in pairs(resolved_names) do
    if device_config[key .. "_name"] == "" and name then
      device_config[key .. "_name"] = name
      reaper.SetExtState(settings_section, key, name, true)
    end
  end

  device_config.yamaha_input = yamaha_input and yamaha_input.id or nil
  device_config.launchpad_input = launchpad_input and launchpad_input.id or nil
  device_config.nanokey_input = nanokey_input and nanokey_input.id or nil
  device_config.yamaha_output = yamaha_output and yamaha_output.id or nil
  device_config.yamaha_input_device = yamaha_input
  device_config.launchpad_input_device = launchpad_input
  device_config.nanokey_input_device = nanokey_input
  device_config.yamaha_output_device = yamaha_output
  device_config.inputs = inputs
  device_config.outputs = outputs
  device_config.missing = {
    yamaha_input = device_config.yamaha_input == nil,
    launchpad_input = device_config.launchpad_input == nil,
    nanokey_input = device_config.nanokey_input == nil,
    yamaha_output = device_config.yamaha_output == nil
  }
  return device_config
end

local function device_selector(label, devices, selected_name, key, selected_device)
  local preview = selected_device and selected_device.name or "Select device..."
  if reaper.ImGui_BeginCombo(ctx, label, preview) then
    for _, device in ipairs(devices) do
      local selected = device.name == selected_name
      if reaper.ImGui_Selectable(ctx, device.name, selected) then
        device_config[key .. "_name"] = device.name
        reaper.SetExtState(settings_section, key, device.name, true)
      end
      if selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
end

local rig_track_names = {
  "Ch 01 - AP: Concert Grand",
  "Ch 02 - EP: Tine Vintage",
  "Ch 03 - EP: Reed Classic",
  "Ch 04 - Organ: Tonewheel",
  "Ch 05 - Str: Full Orchestra",
  "Ch 06 - Brass: Ensemble",
  "Ch 07 - Syn: Lead",
  "Ch 08 - Syn: Pad / Choir",
  "Ch 09 - Gtr: Steel Acoustic",
  "Ch 10 - Drum: Stereo Kit",
  "Ch 11 - Bass: Electric",
  "Ch 12 - Clav / Mallet",
  "Ch 13 - Ethnic / World",
  "Ch 14 - Sound FX / Perc",
  "Ch 15 - User Part 1",
  "Ch 16 - Auxiliary (NanoKey2)"
}

local function create_rig(devices)
  if devices.missing.yamaha_input or devices.missing.yamaha_output then
    reaper.ShowMessageBox(
      "Select an available Yamaha MX MIDI input and output before creating the rig.",
      "MIDI devices not selected",
      0
    )
    return
  end

  for i = 0, reaper.CountTracks(0) - 1 do
    local _, name = reaper.GetTrackName(reaper.GetTrack(0, i))
    if name == "YAMAHA MX (MASTER RIG)" then
      reaper.ShowMessageBox("A Yamaha MX rig already exists in this project.", "Rig already exists", 0)
      return
    end
  end

  local master_index = reaper.CountTracks(0)
  reaper.Undo_BeginBlock()
  reaper.InsertTrackAtIndex(master_index, true)

  local master_track = reaper.GetTrack(0, master_index)
  reaper.GetSetMediaTrackInfo_String(master_track, "P_NAME", "YAMAHA MX (MASTER RIG)", true)
  reaper.SetMediaTrackInfo_Value(master_track, "I_FOLDERDEPTH", 1)

  for channel, name in ipairs(rig_track_names) do
    local track_index = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(track_index, true)

    local track = reaper.GetTrack(0, track_index)
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", channel == #rig_track_names and -1 or 0)
    reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1)
    local input_id = channel == 16 and devices.nanokey_input or devices.yamaha_input
    reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", 4096 + (input_id << 5))
    reaper.SetMediaTrackInfo_Value(track, "I_MIDI_INPUT_CHANMAP", channel)
    reaper.SetMediaTrackInfo_Value(track, "I_MIDIHWOUT", (devices.yamaha_output << 5) | channel)
  end

  reaper.SetOnlyTrackSelected(reaper.GetTrack(0, master_index + 1))
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Create Yamaha MX Genos Rig", -1)
end

-- Find the MIDI configuration item at the edit cursor.
local function find_config_item(track)
  if not track then return nil end
  local pos = reaper.GetCursorPosition()
  for i = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local ipos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local ilen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    if pos >= ipos and pos <= (ipos + ilen) then
      local take = reaper.GetActiveTake(item)
      if take and reaper.TakeIsMIDI(take) then return item, take end
    end
  end
  return nil
end

-- Insert or replace the MIDI configuration block.
local function insert_or_replace_midi(Driver, track, ch)
  if not track then return end

  reaper.Undo_BeginBlock()
  local pos = reaper.GetCursorPosition()
  local item, take = find_config_item(track)

  if item then
    reaper.MIDI_SetAllEvts(take, "")
  else
    item = reaper.CreateNewMIDIItemInProj(track, pos, pos + 2.0, false)
    take = reaper.GetActiveTake(item)
  end

  if not take then return end

  local c = (ch - 1) & 0x0F
  local prg = Driver.programs[selected_prg_idx]
  local arp = Driver.arpeggios[selected_arp_idx]

  if prg then
    reaper.MIDI_InsertCC(take, false, false, 0, 0xB0, c, 0, prg.msb)
    reaper.MIDI_InsertCC(take, false, false, 1, 0xB0, c, 32, prg.lsb)
    reaper.MIDI_InsertProgram(take, false, false, 2, c, prg.prg)
  end

  reaper.MIDI_InsertCC(take, false, false, 3, 0xB0, c, 89, arp_sw and 127 or 0)
  reaper.MIDI_InsertCC(take, false, false, 4, 0xB0, c, 91, rev_val)
  reaper.MIDI_InsertCC(take, false, false, 5, 0xB0, c, 93, cho_val)
  reaper.MIDI_InsertCC(take, false, false, 6, 0xB0, c, 74, cut_val)
  reaper.MIDI_InsertCC(take, false, false, 7, 0xB0, c, 71, res_val)

  if arp and arp_sw then
    local msb = (arp.nr >> 7) & 0x7F
    local lsb = arp.nr & 0x7F
    local sysex = string.char(0xF0, 0x43, 0x10, 0x7F, 0x1C, 0x36, c, 0x02, 0x01, msb, lsb, 0xF7)
    reaper.MIDI_InsertTextSysexEvt(take, false, false, 8, -1, sysex)
  end

  local iname = string.format("[MX Config] %s | Arp %s", prg and prg.name or "Voice", arp_sw and (arp and arp.name or "ON") or "OFF")
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", iname, true)

  reaper.Undo_EndBlock("Configure Yamaha MX MIDI", -1)
  reaper.UpdateArrange()
end

function GUI.render(Driver, Chords, LP, devices)
  local track = reaper.GetSelectedTrack(0, 0)
  local track_name = "No track selected"
  local ch, dev_id = 1, devices.yamaha_output
  local can_send = false

  if track then
    local _, tname = reaper.GetTrackName(track)
    track_name = (tname ~= "") and tname or "Active track"
    local hw = reaper.GetMediaTrackInfo_Value(track, "I_MIDIHWOUT")
    if hw >= 0 then
      local output_channel = math.floor(hw) & 0x1F
      if output_channel >= 1 and output_channel <= 16 and dev_id ~= nil then
        ch = output_channel
        can_send = true
      end
    end
  end

  reaper.ImGui_SetNextWindowSize(ctx, 760, 760, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Yamaha MX Genos Inspector', true)

  if visible then
    -- Header and detected chord.
    reaper.ImGui_TextColored(ctx, 0xFFA200FF, "YAMAHA MX GENOS INSPECTOR")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, 0x00E5FFFF, string.format("[%s: %s %s]", track_name, Chords.current_root, Chords.current_type))

    reaper.ImGui_Text(ctx, "Yamaha MX input")
    reaper.ImGui_SameLine(ctx)
    device_selector("##yamaha_input", devices.inputs, device_config.yamaha_input_name, "yamaha_input", devices.yamaha_input_device)
    reaper.ImGui_Text(ctx, "Yamaha MX output")
    reaper.ImGui_SameLine(ctx)
    device_selector("##yamaha_output", devices.outputs, device_config.yamaha_output_name, "yamaha_output", devices.yamaha_output_device)
    reaper.ImGui_Text(ctx, "Launchpad input")
    reaper.ImGui_SameLine(ctx)
    device_selector("##launchpad_input", devices.inputs, device_config.launchpad_input_name, "launchpad_input", devices.launchpad_input_device)
    reaper.ImGui_Text(ctx, "nanoKEY2 input")
    reaper.ImGui_SameLine(ctx)
    device_selector("##nanokey_input", devices.inputs, device_config.nanokey_input_name, "nanokey_input", devices.nanokey_input_device)
    if devices.missing.yamaha_input or devices.missing.yamaha_output then
      reaper.ImGui_TextColored(ctx, 0xFFAA00FF, "Select the Yamaha MX input and output to create the rig.")
    end

    if reaper.ImGui_Button(ctx, "Create Rig") then
      create_rig(devices)
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    if can_send then
      -- Hardware controls.
      local s_chg, n_sw = reaper.ImGui_Checkbox(ctx, "Arpeggiator (CC89)", arp_sw)
      if s_chg then arp_sw = n_sw; Driver.audition_am_chord(dev_id, ch) end

      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Audition Am Chord") then
        Driver.send_full_state(dev_id, ch, Driver.programs[selected_prg_idx], Driver.arpeggios[selected_arp_idx], arp_sw, rev_val, cho_val, cut_val, res_val)
        Driver.audition_am_chord(dev_id, ch)
      end

      -- CC sliders.
      reaper.ImGui_SetNextItemWidth(ctx, 180)
      local r_c, n_r = reaper.ImGui_SliderInt(ctx, "Reverb (CC91)", rev_val, 0, 127)
      if r_c then rev_val = n_r end

      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SetNextItemWidth(ctx, 180)
      local c_c, n_c = reaper.ImGui_SliderInt(ctx, "Chorus (CC93)", cho_val, 0, 127)
      if c_c then cho_val = n_c end

      reaper.ImGui_SetNextItemWidth(ctx, 180)
      local cut_c, n_cut = reaper.ImGui_SliderInt(ctx, "Cutoff (CC74)", cut_val, 0, 127)
      if cut_c then cut_val = n_cut end

      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_SetNextItemWidth(ctx, 180)
      local res_c, n_res = reaper.ImGui_SliderInt(ctx, "Resonance (CC71)", res_val, 0, 127)
      if res_c then res_val = n_res end

      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Separator(ctx)

      -- Tabs.
      if reaper.ImGui_BeginTabBar(ctx, "Tabs") then
        -- Voices tab.
        if reaper.ImGui_BeginTabItem(ctx, "Voices") then
          reaper.ImGui_SetNextItemWidth(ctx, -1)
          _, search_prg = reaper.ImGui_InputTextWithHint(ctx, "##pfilt", "Search voices...", search_prg)
          if reaper.ImGui_BeginListBox(ctx, "##plist", -1, 160) then
            for i, p in ipairs(Driver.programs) do
              if search_prg == "" or p.desc:lower():find(search_prg:lower(), 1, true) then
                if reaper.ImGui_Selectable(ctx, p.desc, selected_prg_idx == i) then
                  selected_prg_idx = i
                  Driver.send_full_state(dev_id, ch, p, Driver.arpeggios[selected_arp_idx], arp_sw, rev_val, cho_val, cut_val, res_val)
                  Driver.audition_am_chord(dev_id, ch)
                end
              end
            end
            reaper.ImGui_EndListBox(ctx)
          end
          reaper.ImGui_EndTabItem(ctx)
        end

        -- Hardware arpeggios tab.
        if reaper.ImGui_BeginTabItem(ctx, "Hardware Arpeggios") then
          reaper.ImGui_SetNextItemWidth(ctx, -1)
          _, search_arp = reaper.ImGui_InputTextWithHint(ctx, "##afilt", "Search arpeggios...", search_arp)
          if reaper.ImGui_BeginListBox(ctx, "##alist", -1, 160) then
            for i, a in ipairs(Driver.arpeggios) do
              if search_arp == "" or a.desc:lower():find(search_arp:lower(), 1, true) then
                if reaper.ImGui_Selectable(ctx, a.desc, selected_arp_idx == i) then
                  selected_arp_idx = i
                  Driver.send_full_state(dev_id, ch, Driver.programs[selected_prg_idx], a, arp_sw, rev_val, cho_val, cut_val, res_val)
                  Driver.audition_am_chord(dev_id, ch)
                end
              end
            end
            reaper.ImGui_EndListBox(ctx)
          end
          reaper.ImGui_EndTabItem(ctx)
        end

        reaper.ImGui_EndTabBar(ctx)
      end

      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Separator(ctx)
    else
      reaper.ImGui_TextDisabled(ctx, "Select a rig channel track with a Yamaha MIDI output to use voices and arpeggios.")
    end

    -- Main action button.
    local existing, _ = find_config_item(track)
    local lbl = existing and "REPLACE MIDI CONFIG BLOCK" or "INSERT MIDI CONFIG AT EDIT CURSOR"
    
    if existing then
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xCC8800FF)
    else
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x1E7E34FF)
    end

    if reaper.ImGui_Button(ctx, lbl, -1, 40) then
      insert_or_replace_midi(Driver, track, ch)
    end
    reaper.ImGui_PopStyleColor(ctx, 1)

    reaper.ImGui_End(ctx)
  end

  return open
end

return GUI