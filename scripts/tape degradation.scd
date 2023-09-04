~useAudioInterface.();

(
SynthDef(\tapeLooper, {
    |in=0, buf, recGate=0, out=0|
    var phasor, recLvl, sig, bufRd, bufFrames;
    bufFrames = BufFrames.kr(buf);
    phasor = Phasor.ar(end: bufFrames);
    recLvl = EnvGen.ar(Env(times:[0.01, 0.01], releaseNode: 1), recGate);
    sig = In.ar(in, 2);
    bufRd = BufRd.ar(2, buf, phasor);
    sig = SelectX.ar(recLvl, [bufRd, sig]);

    sig = AnalogDegrade.ar(sig, 0.001, 0.001);
    sig = AnalogTape.ar(sig, saturation: 0.51, drive: 0.8, oversample: 2);

    BufWr.ar(sig, buf, phasor);
    ReplaceOut.ar(out, sig);
}).add;
)

(
Buffer.freeAll;
~buffer = Buffer.alloc(s, s.sampleRate * 30, 2).zero;
Pbind(
    \instrument, \defaultPluck,
    \dur, Pwrand([0.25, 0.5, 1, Rest(1), Rest(2)], [0.5, 0.25, 0.25, 0.2, 0.1].normalizeSum, inf),
    \midinote, Pn(Pshuf(Scale.dorian.degrees, {rrand(1, 3)})) + 60,
    \atk, 0.01,
    \cutoff, 1000,
    \fEnvAmp, 500,
    \rq, 0.75,
    \subAmp, 0.2,
    \detune, 1,
    \spread, 0.25,
).play;
~looper = Synth(\looper, [\buf, ~buffer, \recGate, 1, \feedback, 0.9, \overdub, 1], addAction: 'addToTail');
)

~looper.set(\recGate, 0);
~looper.set(\recGate, 1);

