--
-- require the `mods` module to gain access to hooks, menu, and other utility
-- functions.
--

local mod = require 'core/mods'

-- This is the usual MIDI CC value for sustain, but you can change it if you wish.
--
local SUSTAIN_CC = 64

--
-- [optional] a mod is like any normal lua module. local variables can be used
-- to hold any state which needs to be accessible across hooks, the menu, and
-- any api provided by the mod itself.
--
-- here a single table is used to hold some x/y values
--

local state = {
  offs = {}, -- Map from MIDI device id to  MIDI channel to notes-off table,
      -- which is a table from a MIDI note number to the data for the note off.
      -- We are in a sustain for a channel if its notes-off table is non-nil.
  original_norns_midi_event = nil,
  original_norns_midi_remove = nil,
}


-- Initialise the sustain mod.
--
mod.hook.register("system_post_startup", "sustain mod post startup", function()
  -- Assume no note-off data

  state.offs = {}

  -- Wrap MIDI event capture

  if state.original_norns_midi_event == nil then
    state.original_norns_midi_event = _norns.midi.event
    _norns.midi.event = wrapped_norns_midi_event
  end

  -- Wrap MIDI device removal

  if state.original_norns_midi_remove == nil then
    state.original_norns_midi_remove = _norns.midi.remove
    _norns.midi.remove = wrapped_norns_midi_remove
  end
end)

mod.hook.register("script_pre_init", "sustain mod pre-init", function()
  -- tweak global environment here ahead of the script `init()` function being called
  -- Nothing to tweak here
end)


-- Our wrapper around incoming MIDI events.
-- Control then passes back to whatever was the previous route.
-- We are wrapping
-- https://github.com/monome/norns/blob/main/lua/core/midi.lua#L426
--
function wrapped_norns_midi_event(id, data)
  if state.offs[id] == nil then
    state.offs[id] = {}
  end
  local offs = state.offs[id]

  local msg = midi.to_msg(data)
  local notes_off = offs[msg.ch]
  local sustain_cc = msg.type == 'cc' and msg.cc == SUSTAIN_CC

  if sustain_cc and msg.val == 0 and notes_off ~= nil then
    -- Release sustained notes on this channel
    for note, dta in pairs(notes_off) do
      state.original_norns_midi_event(id, dta)
    end
    offs[msg.ch] = nil
  elseif sustain_cc and msg.val == 127 and notes_off == nil then
    -- Start capturing notes on this channel
    offs[msg.ch] = {}
  elseif msg.type == 'note_off' and notes_off ~= nil then
    -- Hold the note off
    offs[msg.ch][msg.note] = data
    return
  end

  -- Continue to the original event handler

  state.original_norns_midi_event(id, data)
end

-- Our wrapper around a MIDI device removal. We just tidy up our offs table.
--
function wrapped_norns_midi_remove(id)
    state.offs[id] = nil
    state.original_norns_midi_remove(id)
end

--
-- [optional] menu: extending the menu system is done by creating a table with
-- all the required menu functions defined.
--

local m = {}

m.key = function(n, z)
  if n == 2 and z == 1 then
    -- return to the mod selection menu
    mod.menu.exit()
  end
end

m.enc = function(n, d)
  -- Nothing to do for encoders
end

m.redraw = function()
  screen.clear()
  screen.move(64, 32)
  screen.text_center('Value of sustain CC is ' .. SUSTAIN_CC .. '.')
  screen.move(64, 48)
  screen.text_center('To change this, please')
  screen.move(64, 56)
  screen.text_center('edit the mod directly.')
  screen.update()
end

m.init = function() end -- on menu entry, ie, if you wanted to start timers
m.deinit = function() end -- on menu exit

-- register the mod menu
--
-- NOTE: `mod.this_name` is a convienence variable which will be set to the name
-- of the mod which is being loaded. in order for the menu to work it must be
-- registered with a name which matches the name of the mod in the dust folder.
--
mod.menu.register(mod.this_name, m)


--
-- [optional] returning a value from the module allows the mod to provide
-- library functionality to scripts via the normal lua `require` function.
--
-- NOTE: it is important for scripts to use `require` to load mod functionality
-- instead of the norns specific `include` function. using `require` ensures
-- that only one copy of the mod is loaded. if a script were to use `include`
-- new copies of the menu, hook functions, and state would be loaded replacing
-- the previous registered functions/menu each time a script was run.
--
-- here we provide a single function which allows a script to get the mod's
-- state table. using this in a script would look like:
--
-- local mod = require 'name_of_mod/lib/mod'
-- local the_state = mod.get_state()
--
local api = {}

api.get_state = function()
  return state
end

return api
