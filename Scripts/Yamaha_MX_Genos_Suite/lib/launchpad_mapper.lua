-- @noindex
local reaper = reaper
local LP = {}

LP.scenes = {}

function LP.process(midi_msg, Driver, yamaha_output)
  if not midi_msg or #midi_msg < 3 then return end

  local status = midi_msg:byte(1)
  local pad = midi_msg:byte(2)
  local vel = midi_msg:byte(3)

  if (status & 0xF0) == 0x90 and vel > 0 then
    -- Row 1 (pads 0-7): registration scenes 1-8.
    if pad >= 0 and pad <= 7 then
      LP.recall_scene(pad + 1, Driver)

    -- Row 2 (pads 16-19): style sections (Intro A/B, Ending A/B).
    elseif pad == 16 then LP.trigger_section("INTRO A")
    elseif pad == 17 then LP.trigger_section("INTRO B")
    elseif pad == 18 then LP.trigger_section("ENDING A")
    elseif pad == 19 then LP.trigger_section("ENDING B")

    -- Row 3 (pads 32-35): main variations A-D.
    elseif pad == 32 then LP.set_variation(1, Driver, yamaha_output)
    elseif pad == 33 then LP.set_variation(2, Driver, yamaha_output)
    elseif pad == 34 then LP.set_variation(3, Driver, yamaha_output)
    elseif pad == 35 then LP.set_variation(4, Driver, yamaha_output)

    -- Row 4 (pads 48-49): Fill-In and Break.
    elseif pad == 48 then LP.trigger_section("FILL-IN")
    elseif pad == 49 then LP.trigger_section("BREAK")
    end
  end
end

function LP.set_variation(var_idx, Driver, yamaha_output)
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then return end

  local hw_out = reaper.GetMediaTrackInfo_Value(track, "I_MIDIHWOUT")
  local ch = (hw_out >= 0) and (math.floor(hw_out) & 0x1F) or 1
  if ch < 1 or ch > 16 then ch = 1 end
  local dev_id = yamaha_output or ((hw_out >= 0) and ((math.floor(hw_out) >> 5) & 0x1F) or nil)

  -- Select an arpeggio based on the variation.
  local arp_idx = var_idx * 10
  if Driver.arpeggios[arp_idx] then
    if dev_id ~= nil then
      Driver.send_full_state(dev_id, ch, nil, Driver.arpeggios[arp_idx], true, 40, 0, 64, 64)
    end
  end
end

function LP.trigger_section(section_name)
  reaper.ShowConsoleMsg("Genos 2 section activated: " .. section_name .. "\n")
end

function LP.recall_scene(scene_id, Driver)
  local sc = LP.scenes[scene_id]
  if sc then
    local track = reaper.GetSelectedTrack(0, 0)
    if track then
      Driver.send_full_state(sc.dev_id, sc.ch, sc.program, sc.arpeggio, sc.arp_sw, sc.rev, sc.cho, sc.cut, sc.res)
    end
  end
end

return LP