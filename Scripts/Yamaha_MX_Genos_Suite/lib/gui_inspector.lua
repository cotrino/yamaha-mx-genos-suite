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
local preview_notes = true
local preview_stop_time = nil

local search_prg = ""
local search_arp = ""
local last_config_track = nil
local last_config_channel = nil
local last_config_hash = nil
local last_config_time = nil
local settings_section = "Yamaha MX Genos Inspector"
local window_size_key = "window_size_v1_0_8"
local resize_window_on_start = reaper.GetExtState(settings_section, window_size_key) ~= "1"
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

local rig_master_name = "YAMAHA MX (MASTER RIG)"
local armed_for_selection = nil

-- Arms only the selected rig channel track; runs when the selection changes.
local function sync_rig_arming(selected)
  if selected == armed_for_selection then return end
  armed_for_selection = selected
  for index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, index)
    local parent = reaper.GetParentTrack(track)
    if parent then
      local _, parent_name = reaper.GetTrackName(parent)
      if parent_name == rig_master_name then
        local arm = track == selected and 1 or 0
        if reaper.GetMediaTrackInfo_Value(track, "I_RECARM") ~= arm then
          reaper.SetMediaTrackInfo_Value(track, "I_RECARM", arm)
        end
      end
    end
  end
end

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
    if name == rig_master_name then
      reaper.ShowMessageBox("A Yamaha MX rig already exists in this project.", "Rig already exists", 0)
      return
    end
  end

  local master_index = reaper.CountTracks(0)
  reaper.Undo_BeginBlock()
  reaper.InsertTrackAtIndex(master_index, true)

  local master_track = reaper.GetTrack(0, master_index)
  reaper.GetSetMediaTrackInfo_String(master_track, "P_NAME", rig_master_name, true)
  reaper.SetMediaTrackInfo_Value(master_track, "I_FOLDERDEPTH", 1)

  for channel, name in ipairs(rig_track_names) do
    local track_index = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(track_index, true)

    local track = reaper.GetTrack(0, track_index)
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
    reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", channel == #rig_track_names and -1 or 0)
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
      if take and reaper.TakeIsMIDI(take) then
        local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if take_name:find("^%[MX Config%]") then return item, take end
      end
    end
  end
  return nil
end

local function find_program_index(Driver, msb, lsb, program_number)
  if msb == nil or lsb == nil or program_number == nil then return nil end
  for i, program in ipairs(Driver.programs) do
    if program.msb == msb and program.lsb == lsb and program.prg == program_number then
      return i
    end
  end
  return nil
end

local function find_arpeggio_index(Driver, arpeggio_number)
  if arpeggio_number == nil then return nil end
  for i, arpeggio in ipairs(Driver.arpeggios) do
    if arpeggio.nr == arpeggio_number then return i end
  end
  return nil
end

-- Config events sit a few ticks after the item start, where the cursor usually is.
local config_event_slack = 0.05

local function sync_selection_from_config(Driver, track, channel)
  if not track or not channel then return end
  local cursor_time = reaper.GetCursorPosition()
  local _, hash = reaper.MIDI_GetTrackHash(track, false)
  if track == last_config_track and channel == last_config_channel and
      cursor_time == last_config_time and hash == last_config_hash then
    return
  end
  last_config_track = track
  last_config_channel = channel
  last_config_hash = hash
  last_config_time = cursor_time

  local target_channel = (channel - 1) & 0x0F
  local events = {}
  local event_order = 0
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local _, _, cc_count, text_count = reaper.MIDI_CountEvts(take)
      for event_index = 0, cc_count - 1 do
        local ok, _, _, ppqpos, chanmsg, event_channel, msg2, msg3 = reaper.MIDI_GetCC(take, event_index)
        local event_time = ok and reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
        if ok and event_channel == target_channel and event_time <= cursor_time + config_event_slack then
          event_order = event_order + 1
          events[#events + 1] = {
            time = event_time, order = event_order, kind = "cc",
            chanmsg = chanmsg, msg2 = msg2, msg3 = msg3
          }
        end
      end
      for event_index = 0, text_count - 1 do
        local ok, _, _, ppqpos, event_type, message = reaper.MIDI_GetTextSysexEvt(take, event_index)
        local event_time = ok and reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
        if ok and event_type == -1 and event_time <= cursor_time + config_event_slack and #message >= 8 and
            message:byte(1) == 0x43 and message:byte(2) == 0x10 and
            message:byte(3) == 0x7F and message:byte(4) == 0x17 and
            message:byte(6) == target_channel then
          event_order = event_order + 1
          events[#events + 1] = {
            time = event_time, order = event_order, kind = "sysex",
            address = message:byte(5), offset = message:byte(7), message = message
          }
        end
      end
    end
  end

  table.sort(events, function(a, b)
    if a.time ~= b.time then return a.time < b.time end
    return a.order < b.order
  end)

  selected_prg_idx = 1
  selected_arp_idx = 1
  arp_sw = true
  local bank_msb, bank_lsb
  for _, event in ipairs(events) do
    if event.kind == "cc" then
      if event.chanmsg == 0xB0 and event.msg2 == 0 then
        bank_msb = event.msg3
      elseif event.chanmsg == 0xB0 and event.msg2 == 32 then
        bank_lsb = event.msg3
      elseif event.chanmsg == 0xC0 then
        local program_index = find_program_index(Driver, bank_msb, bank_lsb, event.msg2)
        if program_index then selected_prg_idx = program_index end
      elseif event.chanmsg == 0xB0 and event.msg2 == 89 then
        arp_sw = event.msg3 >= 64
      end
    elseif event.kind == "sysex" then
      if event.address == 0x38 and event.offset == 0x3C and #event.message >= 9 then
        local msb, lsb = event.message:byte(8, 9)
        local arpeggio_index = find_arpeggio_index(Driver, (msb << 7) | lsb)
        if arpeggio_index then selected_arp_idx = arpeggio_index end
      elseif event.address == 0x38 and event.offset == 0x00 then
        arp_sw = event.message:byte(8) == 0x01
      end
    end
  end
end

-- Length in seconds of `bars` project measures starting at `start_time`.
local function bars_to_seconds(start_time, bars)
  local _, measure = reaper.TimeMap2_timeToBeats(0, start_time)
  local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
  local total_qn = 0
  for index = measure, measure + bars - 1 do
    local _, qn_start, qn_end = reaper.TimeMap_GetMeasureInfo(0, index)
    total_qn = total_qn + (qn_end - qn_start)
  end
  return reaper.TimeMap2_QNToTime(0, start_qn + total_qn) - start_time
end

local function remember_config(track, ch)
  last_config_track = track
  last_config_channel = ch
  last_config_time = reaper.GetCursorPosition()
  local _, hash = reaper.MIDI_GetTrackHash(track, false)
  last_config_hash = hash
end

-- Insert or replace the MIDI configuration block; its length follows the arpeggio's bars.
local function insert_or_replace_midi(Driver, track, ch)
  if not track then return end

  local arp = Driver.arpeggios[selected_arp_idx]
  local prg = Driver.programs[selected_prg_idx]
  local bars = (arp_sw and arp and arp.length) or 1
  local c = (ch - 1) & 0x0F

  reaper.Undo_BeginBlock()
  local pos = reaper.GetCursorPosition()
  local old_item = find_config_item(track)
  if old_item then
    pos = reaper.GetMediaItemInfo_Value(old_item, "D_POSITION")
    reaper.DeleteTrackMediaItem(track, old_item)
  end

  local item = reaper.CreateNewMIDIItemInProj(track, pos, pos + bars_to_seconds(pos, bars), false)
  local take = reaper.GetActiveTake(item)

  if prg then
    reaper.MIDI_InsertCC(take, false, false, 0, 0xB0, c, 0, prg.msb)
    reaper.MIDI_InsertCC(take, false, false, 1, 0xB0, c, 32, prg.lsb)
    reaper.MIDI_InsertCC(take, false, false, 2, 0xC0, c, prg.prg, 0)
  end

  reaper.MIDI_InsertCC(take, false, false, 3, 0xB0, c, 89, arp_sw and 127 or 0)
  reaper.MIDI_InsertCC(take, false, false, 4, 0xB0, c, 91, rev_val)
  reaper.MIDI_InsertCC(take, false, false, 5, 0xB0, c, 93, cho_val)
  reaper.MIDI_InsertCC(take, false, false, 6, 0xB0, c, 74, cut_val)
  reaper.MIDI_InsertCC(take, false, false, 7, 0xB0, c, 71, res_val)

  for index, body in ipairs(Driver.arp_messages(ch, arp, arp_sw)) do
    reaper.MIDI_InsertTextSysexEvt(take, false, false, 7 + index, -1, body)
  end

  if preview_notes then
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    if item_len > 0.05 then
      -- Leave the MX time to apply the voice and arpeggio before the trigger notes.
      local start_time = item_pos + math.min(0.1, item_len * 0.1)
      local end_time = item_pos + item_len - math.min(0.05, item_len * 0.1)
      local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, start_time)
      local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, end_time)
      for _, pitch in ipairs({ 48, 51, 56 }) do
        reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, c, pitch, 96)
      end
    end
  end

  local iname = string.format("[MX Config] %s | Arp %s", prg and prg.name or "Voice", arp_sw and (arp and arp.name or "ON") or "OFF")
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", iname, true)

  reaper.Undo_EndBlock("Configure Yamaha MX MIDI", -1)
  reaper.UpdateArrange()
  return item
end

local function stop_preview()
  if preview_stop_time then
    reaper.CSurf_OnStop()
    preview_stop_time = nil
  end
end

-- Write the config item, then play it so the MX receives every message in it.
local function preview_config(Driver, track, ch)
  stop_preview()
  local item = insert_or_replace_midi(Driver, track, ch)
  if not item then return end
  reaper.SetEditCurPos(reaper.GetMediaItemInfo_Value(item, "D_POSITION"), false, false)
  reaper.CSurf_OnPlay()
  preview_stop_time = reaper.time_precise() + reaper.GetMediaItemInfo_Value(item, "D_LENGTH") + 0.25
  remember_config(track, ch)
end

-- Draws wrapping category buttons; returns the category clicked this frame.
local function category_buttons(id, categories)
  local clicked
  local avail = reaper.ImGui_GetContentRegionAvail(ctx)
  local pad_x = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local spacing_x = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
  local used = 0
  for _, category in ipairs(categories) do
    local width = reaper.ImGui_CalcTextSize(ctx, category) + pad_x * 2
    if used > 0 then
      if used + spacing_x + width <= avail then
        reaper.ImGui_SameLine(ctx)
        used = used + spacing_x
      else
        used = 0
      end
    end
    if reaper.ImGui_SmallButton(ctx, category .. "##" .. id .. category) then clicked = category end
    used = used + width
  end
  return clicked
end

function GUI.render(Driver, Chords, LP, devices)
  if preview_stop_time and reaper.time_precise() >= preview_stop_time then stop_preview() end

  local track = reaper.GetSelectedTrack(0, 0)
  sync_rig_arming(track)
  local track_name = "No track selected"
  local ch, dev_id = 1, devices.yamaha_output
  local can_send = false
  local valid_hardware_channel = false

  if track then
    local _, tname = reaper.GetTrackName(track)
    track_name = (tname ~= "") and tname or "Active track"
    local hw = reaper.GetMediaTrackInfo_Value(track, "I_MIDIHWOUT")
    if hw >= 0 then
      local output_channel = math.floor(hw) & 0x1F
      if output_channel >= 1 and output_channel <= 16 then
        ch = output_channel
        valid_hardware_channel = true
        can_send = dev_id ~= nil
      end
    end
  end
  sync_selection_from_config(Driver, track, valid_hardware_channel and ch or nil)

  local size_condition = resize_window_on_start and reaper.ImGui_Cond_Always() or reaper.ImGui_Cond_FirstUseEver()
  reaper.ImGui_SetNextWindowSize(ctx, 760, 1000, size_condition)
  if resize_window_on_start then
    reaper.SetExtState(settings_section, window_size_key, "1", true)
    resize_window_on_start = false
  end
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
      reaper.ImGui_TextWrapped(ctx, "To send arp notes back to REAPER, set Utility > Job > Quick Setup > Arp Rec on the MX88.")
      local s_chg, n_sw = reaper.ImGui_Checkbox(ctx, "Arpeggiator", arp_sw)
      if s_chg then
        arp_sw = n_sw
        preview_config(Driver, track, ch)
      end

      reaper.ImGui_SameLine(ctx)
      local n_chg, n_notes = reaper.ImGui_Checkbox(ctx, "Preview notes", preview_notes)
      if n_chg then preview_notes = n_notes end

      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Preview") then
        preview_config(Driver, track, ch)
      end

      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Stop") then
        stop_preview()
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

      if reaper.ImGui_BeginTable(ctx, "##selectors", 2, reaper.ImGui_TableFlags_SizingStretchSame()) then
        reaper.ImGui_TableNextRow(ctx)
        reaper.ImGui_TableSetColumnIndex(ctx, 0)
        reaper.ImGui_Text(ctx, "Voices")
        local jump_prg = category_buttons("v", Driver.voice_categories)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, search_prg = reaper.ImGui_InputTextWithHint(ctx, "##pfilt", "Search voices...", search_prg)
        if reaper.ImGui_BeginListBox(ctx, "##plist", -1, 320) then
          for i, p in ipairs(Driver.programs) do
            if search_prg == "" or p.desc:lower():find(search_prg:lower(), 1, true) then
              local jumped = jump_prg ~= nil and p.category == jump_prg
              if jumped then
                jump_prg = nil
                selected_prg_idx = i
              end
              local picked = reaper.ImGui_Selectable(ctx, p.desc, selected_prg_idx == i)
              if jumped then reaper.ImGui_SetScrollHereY(ctx, 0.0) end
              if picked or jumped then
                selected_prg_idx = i
                preview_config(Driver, track, ch)
              end
            end
          end
          reaper.ImGui_EndListBox(ctx)
        end

        reaper.ImGui_TableSetColumnIndex(ctx, 1)
        reaper.ImGui_Text(ctx, "Arpeggios")
        local jump_arp = category_buttons("a", Driver.arp_categories)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, search_arp = reaper.ImGui_InputTextWithHint(ctx, "##afilt", "Search arpeggios...", search_arp)
        if reaper.ImGui_BeginListBox(ctx, "##alist", -1, 320) then
          for i, a in ipairs(Driver.arpeggios) do
            if search_arp == "" or a.desc:lower():find(search_arp:lower(), 1, true) then
              local jumped = jump_arp ~= nil and a.category == jump_arp
              if jumped then
                jump_arp = nil
                selected_arp_idx = i
              end
              local picked = reaper.ImGui_Selectable(ctx, a.desc, selected_arp_idx == i)
              if jumped then reaper.ImGui_SetScrollHereY(ctx, 0.0) end
              if picked or jumped then
                selected_arp_idx = i
                preview_config(Driver, track, ch)
              end
            end
          end
          reaper.ImGui_EndListBox(ctx)
        end

        reaper.ImGui_EndTable(ctx)
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
      remember_config(track, ch)
    end
    reaper.ImGui_PopStyleColor(ctx, 1)

    reaper.ImGui_End(ctx)
  end

  return open
end

return GUI