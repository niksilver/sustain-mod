--
-- require the `mods` module to gain access to hooks, menu, and other utility
-- functions.
--

local mod = require 'core/mods'

--
-- [optional] a mod is like any normal lua module. local variables can be used
-- to hold any state which needs to be accessible across hooks, the menu, and
-- any api provided by the mod itself.
--
-- here a single table is used to hold some x/y values
--

local state = {
  x = 0,
  y = 0,
  -- sustain = params.add_number("sustain_pedal", "sustain pedal", 0, 127. 4),
  offs = {}, -- Map from MIDI device id to  MIDI channel to notes-off table,
      -- which is a table from a MIDI note number to the data for the note off.
      -- We are in a sustain for a channel if its notes-off table is non-nil.
  original_norns_midi_event = nil,
  original_norns_midi_remove = nil,
}


--
-- [optional] hooks are essentially callbacks which can be used by multiple mods
-- at the same time. each function registered with a hook must also include a
-- name. registering a new function with the name of an existing function will
-- replace the existing function. using descriptive names (which include the
-- name of the mod itself) can help debugging because the name of a callback
-- function will be printed out by matron (making it visible in maiden) before
-- the callback function is called.
--
-- here we have dummy functionality to help confirm things are getting called
-- and test out access to mod level state via mod supplied fuctions.
--


-- Initialise the sustain mod by (i) assuming all notes are off, and
-- (ii) wrapping the core MIDI event function.
--
mod.hook.register("system_post_startup", "sustain mod post startup", function()
  print("sustain_mod: Enter init")
  state.ons = {}

  if state.original_norns_midi_event == nil then
    state.original_norns_midi_event = _norns.midi.event
    _norns.midi.event = wrapped_norns_midi_event
  end

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
-- TODO: Don't mix up sustains from different devices!
--
function wrapped_norns_midi_event(id, data)
  if state.offs[id] == nil then
    state.offs[id] = {}
  end
  local offs = state.offs[id]

  local msg = midi.to_msg(data)
  local notes_off = offs[msg.ch]

  if msg.type == 'cc' and msg.val == 0 and notes_off ~= nil then
    -- Release sustained notes on this channel
    print("sustain_mod: Releasing notes")
    for note, dta in pairs(notes_off) do
      print("sustain_mod: Releasing note " .. note)
      state.original_norns_midi_event(id, dta)
    end
    offs[msg.ch] = nil
  elseif msg.type == 'cc' and msg.val == 127 and notes_off == nil then
    -- Start capturing notes on this channel
    offs[msg.ch] = {}
    print("sustain_mod: Capturing on channel " .. msg.ch)
  elseif msg.type == 'note_off' and notes_off ~= nil then
    -- Hold the note off
    offs[msg.ch][msg.note] = data
    print("sustain_mod: Held note " .. msg.note)
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
  if n == 2 then state.x = state.x + d
  elseif n == 3 then state.y = state.y + d end
  -- tell the menu system to redraw, which in turn calls the mod's menu redraw
  -- function
  mod.menu.redraw()
end

m.redraw = function()
  screen.clear()
  screen.move(64,40)
  screen.text_center(state.x .. "/" .. state.y)
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
