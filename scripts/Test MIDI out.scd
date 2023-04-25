~useJACK.value;
(
~connectMidiOut = {
    if (MIDIClient.initialized == false)
    {MIDIClient.init;}
    {MIDIClient.list;};

    try
    {~midiDevice = MIDIOut.newByName("2- Studio 68c MIDI Out", "2- Studio 68c MIDI Out");}
    {|err| err.postln};
}
)
~connectMidiOut.value;

(
~midiDevice.allNotesOff(0);
a = Routine({
    loop {
        var note = 60, velocity = 127;
        ~midiDevice.noteOn(0, note, velocity);
        0.5.yield;
        ~midiDevice.noteOff(0, note, velocity);
        0.5.yield;
    }
});
b = a.play;
)
b.stop;

~clock = TempoClock(1).permanent_(true);
(
Pdefn(\note, 60);
Pdefn(\vel, 64);
Pdefn(\dur, 1);
Pdefn(\sustain, 0.5);
Pdefn(\ccNum, 20);
Pdefn(\ccVal, 0);
a = Pbind(
    \type, \midi,
    \midiout, ~midiDevice,
    \chan, 0,
    \dur, Pdefn(\dur),
);
p = Pbind(
    \midicmd, \noteOn,

    \sustain, Pdefn(\sustain),
    \midinote, Pdefn(\note),
    \amp, Pdefn(\vel) / 127,
) <> a;
q = Pbind(
    \midicmd, \control,

    \ctlNum, Pdefn(\ccNum),
    \control, Pdefn(\ccVal)
) <> a;
)

(
~clock.beats_(-0.01);
b = p.play(~clock, quant: 1.0);
c = q.play(~clock, quant: 1.0);
)


(
var notes = [36,48] +.x Scale.minorPentatonic.degrees;
var shuffled = Pn(Pdup({rrand(1, 4)}, Pshuf(notes, {rrand(2, 4)})));
var transposePattern=Pseq([-12,-5,0,Prand([0, -7, 7])], inf);
Pdefn(\note, shuffled + transposePattern);
Pdefn(\dur, Pn(Pdup({rrand(1, 4)}, Pwrand([0.25, 0.5, 1, Rest(1)], [2,4,3,1].normalizeSum, inf))));
Pdefn(\sustain, Pexprand(0.02, 0.5, inf) * Pkey(\dur));
Pdefn(\ccVal, Pbeta(20, 110, 0.4, 0.2, inf));
)

b.stop;
c.stop;
~midiDevice.allNotesOff(0);


(
d = {
    var sig = SoundIn.ar(0);
    sig = Pan2.ar(sig, 0);
    Out.ar(0, sig);
}.play(addAction: 'addToTail');
)
d.free;
