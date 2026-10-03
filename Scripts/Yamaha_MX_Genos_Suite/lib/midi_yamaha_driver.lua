-- @noindex
local reaper = reaper
local Driver = {}

Driver.programs = {}
Driver.arpeggios = {}
Driver.arp_cache = {}
Driver.voice_categories = {}
Driver.arp_categories = {}

-- "Piano: Name" -> "Piano"; "Hit 055 New Stab 63 : Orc Hit" -> "Hit".
local function voice_category(name)
  local prefix = name:match("^([^:]+):")
  if not prefix then return "Misc" end
  prefix = prefix:match("^%s*(.-)%s*$")
  if prefix:find("%d") then prefix = prefix:match("^%S+") or prefix end
  return prefix ~= "" and prefix or "Misc"
end

-- Distinct categories in order of first appearance.
local function build_categories(items)
  local categories, seen = {}, {}
  for _, item in ipairs(items) do
    if not seen[item.category] then
      seen[item.category] = true
      categories[#categories + 1] = item.category
    end
  end
  return categories
end

-- Arp SysEx bodies (no F0/F7), model 7F 17 as captured from a Yamaha MX88.
function Driver.arp_messages(channel, arpeggio, arp_sw)
  local part = (channel - 1) & 0x0F
  local messages = {}
  if arpeggio then
    messages[#messages + 1] = string.char(0x43, 0x10, 0x7F, 0x17, 0x38, part, 0x3C,
      (arpeggio.nr >> 7) & 0x7F, arpeggio.nr & 0x7F)
  end
  messages[#messages + 1] = string.char(0x43, 0x10, 0x7F, 0x17, 0x38, part, 0x00, arp_sw and 0x01 or 0x00)
  return messages
end

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
            table.insert(Driver.programs, {
              msb = msb, lsb = lsb, prg = tonumber(prg),
              name = pname, category = voice_category(pname), bank_name = bname,
              desc = string.format("[%03d:%03d:%03d] %s", msb, lsb, tonumber(prg), pname)
            })
          end
        end
      end
    end
    f_bank:close()
  end

  table.sort(Driver.programs, function(a, b)
    local a_name = a.name:lower()
    local b_name = b.name:lower()
    if a_name ~= b_name then return a_name < b_name end
    if a.msb ~= b.msb then return a.msb < b.msb end
    if a.lsb ~= b.lsb then return a.lsb < b.lsb end
    return a.prg < b.prg
  end)

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

  Driver.voice_categories = build_categories(Driver.programs)
  Driver.arp_categories = build_categories(Driver.arpeggios)

  return #Driver.programs, #Driver.arpeggios
end

-- Send the complete state to the Yamaha MX synthesizer.
function Driver.send_full_state(dev_id, channel, program, arpeggio, arp_sw, rev, cho, cut, res)
  if dev_id == nil then return end
  local c = (channel - 1) & 0x0F
  local output_mode = 16 + dev_id

  if program then
    reaper.StuffMIDIMessage(output_mode, 0xB0 | c, 0, program.msb)
    reaper.StuffMIDIMessage(output_mode, 0xB0 | c, 32, program.lsb)
    reaper.StuffMIDIMessage(output_mode, 0xC0 | c, program.prg, 0)
  end

  reaper.StuffMIDIMessage(output_mode, 0xB0 | c, 89, arp_sw and 127 or 0)
  reaper.StuffMIDIMessage(output_mode, 0xB0 | c, 91, math.floor(rev or 40))
  reaper.StuffMIDIMessage(output_mode, 0xB0 | c, 93, math.floor(cho or 0))
  reaper.StuffMIDIMessage(output_mode, 0xB0 | c, 74, math.floor(cut or 64))
  reaper.StuffMIDIMessage(output_mode, 0xB0 | c, 71, math.floor(res or 64))

  for _, body in ipairs(Driver.arp_messages(channel, arpeggio, arp_sw)) do
    local sysex = "\xF0" .. body .. "\xF7"
    reaper.SendMIDIMessageToHardware(dev_id, sysex, #sysex)
  end
end

return Driver