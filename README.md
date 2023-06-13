# sustain-mod

# The problem

You have a MIDI keyboard with a sustain pedal feeding into a norns script.
The keyboard sends sustain pedal MIDI info to the norns, but the norns
script isn't programmed to do anything with it, so it just ignores it.

# The solution

This norns mod intercepts incoming MIDI messages before they get to any script.
It withholds MIDI off messages while the sustain pedal is down, and sends them
on when the pedal is lifted.
