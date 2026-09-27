-- @noindex
local reaper = reaper
local Chords = {}

Chords.current_root = "C"
Chords.current_type = "Maj"
Chords.active_notes = {}

local note_names = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

function Chords.process_note_event(status, note, vel)
  local is_note_on = (status & 0xF0) == 0x90 and vel > 0
  local is_note_off = (status & 0xF0) == 0x80 or ((status & 0xF0) == 0x90 and vel == 0)

  -- Filtrar zona Split mano izquierda (notas 36 C1 a 59 B2)
  if note >= 36 and note <= 59 then
    if is_note_on then
      Chords.active_notes[note] = true
    elseif is_note_off then
      Chords.active_notes[note] = nil
    end
    Chords.analyze()
  end
end

function Chords.analyze()
  local pitches = {}
  for n, _ in pairs(Chords.active_notes) do
    table.insert(pitches, n)
  end
  table.sort(pitches)

  if #pitches == 0 then return end

  local root_pitch = pitches[1]
  Chords.current_root = note_names[(root_pitch % 12) + 1]

  -- Detectar cualidad del acorde a partir de intervalos
  local intervals = {}
  for i = 2, #pitches do
    local diff = (pitches[i] - root_pitch) % 12
    intervals[diff] = true
  end

  if intervals[3] and intervals[7] then
    Chords.current_type = "m"
  elseif intervals[4] and intervals[7] then
    Chords.current_type = "Maj"
  elseif intervals[3] and intervals[6] then
    Chords.current_type = "dim"
  elseif intervals[4] and intervals[8] then
    Chords.current_type = "aug"
  elseif intervals[4] and intervals[10] then
    Chords.current_type = "7"
  else
    Chords.current_type = "5"
  end
end

function Chords.update()
  -- Escuchar evento MIDI más reciente desde REAPER
  local retval, midi_msg, _, _ = reaper.MIDI_GetRecentInputEvent(0)
  if retval > 0 and midi_msg and #midi_msg >= 3 then
    Chords.process_note_event(midi_msg:byte(1), midi_msg:byte(2), midi_msg:byte(3))
  end
end

return Chords