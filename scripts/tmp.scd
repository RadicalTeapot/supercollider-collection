~useJACK.value;
~midiDevice = ~connectMidiOut.("2- Studio 68c MIDI Out", "2- Studio 68c MIDI Out");
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

SynthDef(\DC, {
    var sig = Lag.kr(\val.kr(0.0), \lag.kr(0.1));
    sig = K2A.ar(sig.linlin(0,1,0,0.6));
    Out.ar(\out.kr(0), sig);
}).add;

Pdefn(\out1Val, 0);
Pdefn(\out1Dur, 1);
Pdefn(\out2Val, 0);
Pdefn(\out2Dur, 1);
~out1 = Pmono(
    \DC,
    \dur, Pdefn(\out1Dur),
    \val, Pdefn(\out1Val),
    \out, 2
);
~out2 = Pmono(
    \DC,
    \dur, Pdefn(\out2Dur),
    \val, Pdefn(\out2Val),
    \out, 3
);
)

(
~clock.beats_(-0.01);
b = p.play(~clock, quant: 1.0);
c = q.play(~clock, quant: 1.0);
d = ~out1.play(~clock, quant: 1.0);
e = ~out2.play(~clock, quant: 1.0);
)

(
Pdefn(\dur).quant = 4;
Pdefn(\note).quant = 4;
Pdef(\degrees).quant = 4;
// TODO This could be triggered by MIDI rather than using a random to control the sense of progression
Pdefn(\index, Pwrand([0, 1, 2, 3], [3, 2, 1, 1].normalizeSum, inf));

Pdefn(\dur, Pswitch([
    Pwrand([0.125, 0.25, 0.5, Prand([Rest(0.25), Rest(0.5), Rest(1)])], [2,4,3,1].normalizeSum, {rrand(8, 64)}),
    Pwrand([0.125, 0.25, 0.5, Prand([Rest(0.25), Rest(0.5), Rest(1)])], [4,2,3,1].normalizeSum, {rrand(8, 64)}),
    Pwrand([0.125, 0.25, 0.5, Prand([Rest(0.25), Rest(0.5), Rest(1)])], [2,1,4,3].normalizeSum, {rrand(8, 64)}),
    Pwrand([0.125, 0.25, 0.5, Prand([Rest(0.25), Rest(0.5), Rest(1)])], [3,2,1,4].normalizeSum, {rrand(8, 64)}),
], Pdefn(\index).collect({|index| // Avoid evaluating \index twice by collecting rather than calling Pdefn again for \degrees
    Pdefn(\degrees, Pswitch1([
        Pwrand([0, 3, 5], [0.75, 0.2, 0.05], inf),
        Pseq([0, 1, Pwrand([3, Pwhite(5,9,1)], [0.9, 0.1], 1)], inf),
        Pseq([0, 1, Pwrand([2, Pwhite(5,9,1)], [0.8, 0.2], 1), 3, Pwrand([5, Pwhite(10,14,1)], [0.7, 0.3], 1)], inf),
        Pwhite(0, 5, 5) + (Pdup(5, Pwhite(0, 2, 1)) * 5)], index));
    ("Using pattern " ++ index).postln;
    index;
})));

Pdefn(\note, PdegreeToKey(Pdef(\degrees), Scale.minorPentatonic.degrees) + 24, inf);

Pdefn(\sustain, Pexprand(0.02, 0.5, inf) * Pkey(\dur));

Pdefn(\ccVal).quant = nil;
Pdefn(\ccVal, Pbeta(20, 110, 0.4, 0.2, inf));
)

(
Pdefn(\out1Dur).quant = 4;
Pdefn(\out1Dur, Prand([0.25, 0.5, 1], inf) * 3);
Pdefn(\out1Val).quant = 4;
Pdefn(\out1Val, Pwhite(0.25, 0.75, inf));
Pdefn(\out2Dur).quant = 4;
Pdefn(\out2Dur, Prand([0.125, 0.25, 0.5], inf));
Pdefn(\out2Val).quant = 4;
Pdefn(\out2Val, Pwhite(0.25, 1, inf));
)