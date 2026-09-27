-- @description Yamaha MX Genos-Style Arranger Suite
-- @author Jose Cotrino
-- @version 1.0.0
-- @about Suite de arreglista estilo Genos 2 para Yamaha MX88, Launchpad Mini y NanoKey2.

local reaper = reaper

if not reaper.ImGui_CreateContext then
  reaper.ShowMessageBox("ReaImGui no está instalado.\nPor favor instálalo desde ReaPack.", "Error", 0)
  return
end

-- Configurar rutas de importación relativas
local pkg_path = debug.getinfo(1, 'S').source:match([[^@?(.*[\/])[^\/]-$]])
package.path = pkg_path .. "lib/?.lua;" .. package.path

-- Cargar módulos
local Driver = require("midi_yamaha_driver")
local Chords = require("chord_engine")
local LP     = require("launchpad_mapper")
local NK     = require("nanokey_mapper")
local GUI    = require("gui_inspector")

-- Inicializar driver de datos
local reabank_file = pkg_path .. "data/Yamaha_MX49.reabank"
local csv_file     = pkg_path .. "data/Yamaha_MX88_Arpeggios.csv"
Driver.init(reabank_file, csv_file)

-- Bucle principal del sistema
local function main_loop()
  -- 1. Procesar entradas de hardware físico
  NK.process(Driver)
  LP.process(Driver)

  -- 2. Procesar motor de acordes
  Chords.update()

  -- 3. Renderizar interfaz ReaImGui
  local open = GUI.render(Driver, Chords, LP)

  if open then
    reaper.defer(main_loop)
  end
end

reaper.defer(main_loop)