
(
SynthDef(\tapDelay, {
    |dur=1, in=0, rate=1, feedback=0.5, offset=0, amp=0.1, pan=0, out=0|
    var buf = LocalBuf.new(s.sampleRate * dur, 1).clear;
    var tap;

    RecordBuf.ar(In.ar(in, 1), buf, 0, 1, feedback, 1, 1);
    tap = PlayBuf.ar(1, buf, rate, 1, BufFrames.ir(buf) * offset, 1) * amp;
    tap = Pan2.ar(tap, pan);
    Out.ar(out, tap);
}).add;

SynthDef(\mixer, {
    |ins = #[0], levels = #[1.0], out=0|
    var sig = 0;
    ins.do({|in, i| sig = sig + (In.ar(in, 1) * levels[i])});
    Out.ar(out, sig!2);
}).add;
)

(
~delays = (0.0, 1/8..1).collect({ |v|
    Synth(\tapDelay, [
        dur: rrand(0.25, 10),
        rate: [-1, -0.5, -0.25, 0.25, 0.5, 1, 2, 4].choose,
        offset: v.squared,
        feedback: rrand(0.25, 0.6),
        pan: rrand(-0.75, 0.75)
    ], addAction: 'addToTail')
});
a = Pbind(
    \instrument, \default,
    \dur, Prand([1, 2, 4, Rest(1)], inf),
    \sustain, 0.25,
    \degree, Pn(Pdup({rrand(1, 4)}, Pshuf(Scale.minorPentatonic.degrees), inf)),
    \addAction, 'addToHead',
);

a.play;

b = {
    var sig = In.ar(0, 2);
    var verb = FreeVerb2.ar(sig[0], sig[1], 1, 0.8);
    verb = HPF.ar(LPF.ar(verb, 5000), 80);
    sig = SelectX.ar(0.5, [sig, verb]);
    ReplaceOut.ar(0, sig);
}.play;
)