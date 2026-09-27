-- @noindex
local reaper = reaper
local NK = {}

function NK.process(Driver)
  local retval, midi_msg, _, _ = reaper.MIDI_GetRecentInputEvent(0)
  if retval == 0 or not midi_msg or #midi_msg < 3 then return end

  local status = midi_msg:byte(1)
  local note = midi_msg:byte(2)
  local vel = midi_msg:byte(3)

  if (status & 0xF0) == 0x90 and vel > 0 then
    -- C1-D#2 (notes 36-51): directly select MIDI channels 1-16.
    if note >= 36 and note <= 51 then
      local track_idx = note - 36
      local track = reaper.GetTrack(0, track_idx)
      if track then
        reaper.SetOnlyTrackSelected(track)
        reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 1)
      end

    -- E2 (note 52): mute the selected track.
    elseif note == 52 then
      local track = reaper.GetSelectedTrack(0, 0)
      if track then
        local cur_mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
        reaper.SetMediaTrackInfo_Value(track, "B_MUTE", cur_mute == 1 and 0 or 1)
      end

    -- F2 (note 53): solo the selected track.
    elseif note == 53 then
      local track = reaper.GetSelectedTrack(0, 0)
      if track then
        local cur_solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
        reaper.SetMediaTrackInfo_Value(track, "I_SOLO", cur_solo > 0 and 0 or 1)
      end

    -- F#2/G2 (notes 54/55): decrease/increase volume by 1 dB.
    elseif note == 54 or note == 55 then
      local track = reaper.GetSelectedTrack(0, 0)
      if track then
        local cur_vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
        local db = 20 * (math.log(cur_vol) / math.log(10))
        local new_db = (note == 55) and (db + 1.0) or (db - 1.0)
        reaper.SetMediaTrackInfo_Value(track, "D_VOL", 10 ^ (new_db / 20))
      end
    end
  end
end

return NK