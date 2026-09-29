-- @description Yamaha MX Genos-Style Arranger Suite
-- @author José M. Cotrino
-- @version 1.0.4
-- @about Genos-style arranger suite for Yamaha MX88, Launchpad Mini, and NanoKey2.
-- @provides
--   [main] .
--   lib/*.lua
--   data/*.reabank
--   data/*.csv
--   ../../Effects/Yamaha/*.jsfx > ../Effects/Yamaha/
--   ../../TrackTemplates/*.RTrackTemplate > ../TrackTemplates/

local reaper = reaper

if not reaper.ImGui_CreateContext then
  reaper.ShowMessageBox("ReaImGui is not installed.\nInstall it through ReaPack, then restart REAPER.", "Missing dependency", 0)
  return
end

-- Configure relative module import paths.
local pkg_path = debug.getinfo(1, 'S').source:match([[^@?(.*[\/])[^\/]-$]])
package.path = pkg_path .. "lib/?.lua;" .. package.path

-- Load modules.
local Driver = require("midi_yamaha_driver")
local Chords = require("chord_engine")
local LP     = require("launchpad_mapper")
local NK     = require("nanokey_mapper")
local GUI    = require("gui_inspector")

-- Initialize the data driver.
local reabank_file = pkg_path .. "data/Yamaha_MX49.reabank"
local csv_file     = pkg_path .. "data/Yamaha_MX88_Arpeggios.csv"
local program_count, arpeggio_count = Driver.init(reabank_file, csv_file)

if program_count == 0 or arpeggio_count == 0 then
  reaper.ShowMessageBox(string.format(
    "The suite data files could not be loaded.\n\nExpected files:\n%s\n%s\n\nReinstall the Yamaha MX Genos Suite package with ReaPack.",
    reabank_file,
    csv_file
  ), "Missing suite data", 0)
  return
end

-- Main loop.
local last_midi_event = nil

local function dispatch_midi_event(midi_msg, device_flags, devices)
  local input_id = device_flags & 0xFFFF
  if not midi_msg or #midi_msg < 3 then return end

  if input_id == devices.nanokey_input then
    NK.process(midi_msg, Driver)
  elseif input_id == devices.launchpad_input then
    LP.process(midi_msg, Driver, devices.yamaha_output)
  elseif input_id == devices.yamaha_input then
    Chords.process_note_event(midi_msg:byte(1), midi_msg:byte(2), midi_msg:byte(3))
  end
end

local function main_loop()
  local devices = GUI.get_device_config()
  local new_events = {}
  local newest_event_id = nil
  local event_index = 0
  while event_index < 128 do
    local event_id, midi_msg, _, device_flags = reaper.MIDI_GetRecentInputEvent(event_index)
    if not event_id or event_id == 0 then break end
    if event_index == 0 then newest_event_id = event_id end
    if event_id == last_midi_event then break end
    new_events[#new_events + 1] = { midi_msg = midi_msg, device_flags = device_flags }
    event_index = event_index + 1
  end

  if newest_event_id and last_midi_event then
    for index = #new_events, 1, -1 do
      local event = new_events[index]
      dispatch_midi_event(event.midi_msg, event.device_flags, devices)
    end
  end
  last_midi_event = newest_event_id or last_midi_event

  -- Render the ReaImGui interface.
  local open = GUI.render(Driver, Chords, LP, devices)

  if open then
    reaper.defer(main_loop)
  end
end

reaper.defer(main_loop)