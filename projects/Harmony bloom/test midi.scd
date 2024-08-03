(
s.waitForBoot {
    MIDIClient.init;
    ~midi = MIDIOut.newByName("loopMIDI Port", "loopMIDI Port");
    ~midiChannel = 0;

    ~hs = HarmonySequencer.new(s);
    ~hs.gui(30, true);
}
)

(
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
