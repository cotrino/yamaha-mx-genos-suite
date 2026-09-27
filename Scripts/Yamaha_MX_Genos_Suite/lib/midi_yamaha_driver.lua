-- @noindex
local reaper = reaper
local Driver = {}

Driver.programs = {}
Driver.arpeggios = {}
Driver.arp_cache = {}

-- Load and parse the patch and arpeggio files.
function Driver.init(reabank_path, csv_path)
  -- Parse the ReaBank file.
  local f_bank = io.open(reabank_path, "r")
  if f_bank then
    local msb, lsb, bname = 0, 0, ""
    for line in f_bank:lines() do
      line = line:match("^%s*(.-)%s*$")
      if line ~= "" and not line:match("^//") then
        local m, l, name = line:match("^Bank%s+(%d+)%s+(%d+)%s+(.+)$")
        if m and l then
          msb, lsb, bname = tonumber(m), tonumber(l), name
        else
          local prg, _, pname = line:match("^(%d+)%s+(%d+)%s+(.+)$")
          if prg and pname then
            local cat = pname:match("^(%A+):") or "Misc"
            table.insert(Driver.programs, {
              msb = msb, lsb = lsb, prg = tonumber(prg),
              name = pname, category = cat, bank_name = bname,
              desc = string.format("[%03d:%03d:%03d] %s", msb, lsb, tonumber(prg), pname)
            })
          end
        end
      end
    end
    f_bank:close()
  end

  -- Parse the arpeggio CSV file.
  local f_csv = io.open(csv_path, "r")
  if f_csv then
    local header = true
    for line in f_csv:lines() do
      if header then
        header = false
      else
        local cat, nr, name, t_sig, len, tempo = line:match("^([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);?")
        if nr and name then
          table.insert(Driver.arpeggios, {
            category = cat or "Misc", nr = tonumber(nr) or 1, name = name,
            time_sig = t_sig or "4/4", length = tonumber(len) or 1,
            desc = string.format("#%03d [%s] %s", tonumber(nr) or 1, cat or "Misc", name)
          })
        end
      end
    end
    f_csv:close()
  end

  return #Driver.programs, #Driver.arpeggios
end

-- Send the complete state to the Yamaha MX synthesizer.
function Driver.send_full_state(dev_id, channel, program, arpeggio, arp_sw, rev, cho, cut, res)
  local c = (channel - 1) & 0x0F

  if program then
    reaper.StuffMIDIMessage(0, 0xB0 | c, 0, program.msb)
    reaper.StuffMIDIMessage(0, 0xB0 | c, 32, program.lsb)
    reaper.StuffMIDIMessage(0, 0xC0 | c, program.prg, 0)
  end

  reaper.StuffMIDIMessage(0, 0xB0 | c, 89, arp_sw and 127 or 0)
  reaper.StuffMIDIMessage(0, 0xB0 | c, 91, math.floor(rev or 40))
  reaper.StuffMIDIMessage(0, 0xB0 | c, 93, math.floor(cho or 0))
  reaper.StuffMIDIMessage(0, 0xB0 | c, 74, math.floor(cut or 64))
  reaper.StuffMIDIMessage(0, 0xB0 | c, 71, math.floor(res or 64))

  if arpeggio and arp_sw then
    local msb = (arpeggio.nr >> 7) & 0x7F
    local lsb = arpeggio.nr & 0x7F
    local sysex = string.char(0xF0, 0x43, 0x10, 0x7F, 0x1C, 0x36, c, 0x02, 0x01, msb, lsb, 0xF7)
    reaper.SendMIDIOutMessage(dev_id, sysex)
  end
end

-- Audition an extended Am chord (A2, E3, A3, C4, E4, G4, B4).
function Driver.audition_am_chord(dev_id, channel)
  local c = (channel - 1) & 0x0F
  local am_notes = { 45, 52, 57, 60, 64, 67, 71 }

  for _, note in ipairs(am_notes) do
    reaper.StuffMIDIMessage(0, 0x90 | c, note, 90)
  end

  local t_start = reaper.time_precise()
  local function release()
    if reaper.time_precise() - t_start > 1.2 then
      for _, note in ipairs(am_notes) do
        reaper.StuffMIDIMessage(0, 0x80 | c, note, 0)
      end
    else
      reaper.defer(release)
    end
  end
  reaper.defer(release)
end

return Driver