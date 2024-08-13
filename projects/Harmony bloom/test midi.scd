(
s.waitForBoot {
    MIDIClient.init;
    ~midi = MIDIOut.newByName("loopMIDI Port", "loopMIDI Port");
    ~midiChannel = 0;

    ~hs = HarmonySequencer(s);
    ~hs.gui(30, true);
}
)

(
~midiNoteDuration = 0.1;
~hs.registerPointTriggerAction({ |pointIdx, note|
    fork {
        ~midi.noteOn(~midiChannel, note);
        (~midiNoteDuration).yield;
        ~midi.noteOff(~midiChannel, note);
    }
});
)


(
~midi.allNotesOff(~midiChannel);
~hs.free;
)