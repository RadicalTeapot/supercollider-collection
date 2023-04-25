~useJACK.value;
~midiDevice = ~connectMidiOut.("2- Studio 68c MIDI Out", "2- Studio 68c MIDI Out");

(
SynthDef(\revDelay, {|dur= 1, feedback = 0.5, amp = 1, in=0|
    var buf = LocalBuf.new(dur * s.sampleRate, 1).clear;
    var endOfBufTrigger = Impulse.ar(dur.reciprocal);
    var direction = Demand.ar(endOfBufTrigger, 0, Dwrand([-1, 1], [0.4, 0.6], inf)).lag(dur * 0.25);
    var writePhasor = Phasor.ar(0, BufRateScale.ir(buf), 0, BufFrames.ir(buf));
    var readPhasor = Phasor.ar(0, BufRateScale.ir(buf) * direction, 1, BufFrames.ir(buf));
    var soundIn = SoundIn.ar(in);
    var gate = SetResetFF.ar(PulseCount.ar(endOfBufTrigger) - 1);  // Delay by one buffer read cycle
    var env = Env.perc(releaseTime: dur * ((1-feedback).reciprocal), curve: -2).kr(2, gate);
    var prev, out;

    // prev = BufRd.ar(1, buf, writePhasor, 4) * env;
    // BufWr.ar(Select.ar(gate, [soundIn, prev]), buf, writePhasor);
    BufWr.ar(soundIn, buf, writePhasor * (1-gate), 0);
    out = BufRd.ar(1, buf, readPhasor, 1, 4) * amp * env;
    Out.ar(0, Pan2.ar(out, Demand.ar(endOfBufTrigger, 0, Dwhite(-0.6, 0.6)).varlag(0.1)));
}).add;
)

~clock = TempoClock.new().permanent_(true);
(
// Pdefn(\dur, 0.5);
Pdefn(\dur, Prand([0.5, 1, 2, 4], inf));
Pdef(\midi, Pbind(
    \type, \midi,
    \midiout, ~midiDevice,
    \chan, 0,
    \dur, Pdefn(\dur),
    \midicmd, \noteOn,
    \sustain, 0.25 * Pkey(\dur),
    \midinote, Prand(Scale.minorPentatonic.degrees +.x [0, 12], inf) + 24,
));
Pdef(\revDelay, Pbind(
    \instrument, \revDelay,
    \dur, Pdefn(\dur),
    \feedback, Pn(0.8, inf),
    \amp, 3.dbamp,
));
)

(
~midiDevice.allNotesOff(0);
~clock.beats_(-0.01);
Pdef(\revDelay).play(~clock, quant:Quant(1, timingOffset: 0.05));
Pdef(\midi).play(~clock, quant:1);
)