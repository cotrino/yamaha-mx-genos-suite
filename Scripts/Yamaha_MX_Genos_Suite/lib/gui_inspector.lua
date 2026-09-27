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

-- Buscar item MIDI de configuración en el cursor
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

-- Insertar o Reemplazar bloque MIDI
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

  reaper.Undo_EndBlock("Config MIDI Yamaha MX", -1)
  reaper.UpdateArrange()
end

function GUI.render(Driver, Chords, LP)
  local track = reaper.GetSelectedTrack(0, 0)
  local track_name = "Sin pista seleccionada"
  local ch, dev_id = 1, 0

  if track then
    local _, tname = reaper.GetTrackName(track)
    track_name = (tname ~= "") and tname or "Pista Activa"
    local hw = reaper.GetMediaTrackInfo_Value(track, "I_MIDIHWOUT")
    if hw >= 0 then
      dev_id = math.floor(hw) & 0x1F
      ch = ((math.floor(hw) >> 5) & 0x0F) + 1
    end
  end

  reaper.ImGui_SetNextWindowSize(ctx, 450, 620, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Yamaha MX Genos Inspector', true)

  if visible then
    -- Header & Acorde Detectado
    reaper.ImGui_TextColored(ctx, 0xFFA200FF, "YAMAHA MX GENOS INSPECTOR")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, 0x00E5FFFF, string.format("[%s: %s %s]", track_name, Chords.current_root, Chords.current_type))

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    -- Controles HW CC
    local s_chg, n_sw = reaper.ImGui_Checkbox(ctx, "Arpeggiator (CC89)", arp_sw)
    if s_chg then arp_sw = n_sw; Driver.audition_am_chord(dev_id, ch) end

    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Probar Acorde Am") then
      Driver.send_full_state(dev_id, ch, Driver.programs[selected_prg_idx], Driver.arpeggios[selected_arp_idx], arp_sw, rev_val, cho_val, cut_val, res_val)
      Driver.audition_am_chord(dev_id, ch)
    end

    -- Sliders CC
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

    -- Pestañas
    if reaper.ImGui_BeginTabBar(ctx, "Tabs") then
      -- Tab 1: Voces
      if reaper.ImGui_BeginTabItem(ctx, "Voces") then
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, search_prg = reaper.ImGui_InputTextWithHint(ctx, "##pfilt", "Buscar voz...", search_prg)
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

      -- Tab 2: Arpegios
      if reaper.ImGui_BeginTabItem(ctx, "Arpegios HW") then
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        _, search_arp = reaper.ImGui_InputTextWithHint(ctx, "##afilt", "Buscar arpegio...", search_arp)
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

    -- Botón de Acción Principal
    local existing, _ = find_config_item(track)
    local lbl = existing and "REEMPLAZAR BLOQUE CONFIG MIDI" or "INSERTAR BLOQUE CONFIG MIDI (EN CURSOR)"
    
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