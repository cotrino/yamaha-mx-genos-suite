-- @description Yamaha MX Genos-Style Arranger Suite
-- @author José M. Cotrino
-- @version 1.0.2
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
local function main_loop()
  -- Process physical hardware input.
  NK.process(Driver)
  LP.process(Driver)

  -- Update the chord engine.
  Chords.update()

  -- Render the ReaImGui interface.
  local open = GUI.render(Driver, Chords, LP)

  if open then
    reaper.defer(main_loop)
  end
end

reaper.defer(main_loop)