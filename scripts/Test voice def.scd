~useAudioInterface.();

(
SynthDef(\sawPluck, {
    |freq=440, amp=0.5, width=0.5, detune=0, detuneFreq=1,
    subAmp=0, subOctave=1
    atk=0.01, rel=0.5,
    fAtk=0.05, fRel=0.2, fEnvAmp=0,  cutoff=20000,
    pan=0, spread=0, out=0|
    var env, filterEnv, sig, sub, subFreq, unison=5;

    // Envelopes
    env = Env.perc(atk, rel).kr(2);
    filterEnv = Env.perc(fAtk, fRel).kr() * fEnvAmp;

    // Sub
    subFreq = freq * ((subOctave.squared).max(2).reciprocal);
    sub = LFPulse.ar(subFreq ! unison);
    sub = sub * subAmp;

    // Main
    freq = freq + LFNoise2.kr(detuneFreq ! unison).unipolar(detune);
    sig = VarSaw.ar(freq, width: width);

    // Mix with sub
    sig = sig + sub;

    // Pan
    sig = Splay.ar(sig, spread, center: pan);

    // Filter
    sig = MoogFF.ar(sig, (cutoff + filterEnv).clip(20, 20000), 2 + amp * 0.25);

    // Distortion
    sig = (sig/2)*amp;
    sig = sig.tanh*env;

    Out.ar(out, sig*amp);
}).add;
)

(
~scaleNotes = Scale.dorian.degrees;

~loop = (index: 0, length: 0, loopStart: true, loopEnd: false, other: 0,);
~looper = Pbind().collect({
    if ((~loop.length == 0) || (~loop.index == ~loop.length)) {
        ~loop.length = rrand(8, 16);
        ~loop.index = 0;
    };
    ~loop.loopStart = (~loop.index == 0);
    ~loop.index = ~loop.index + 1; // range is 1 to length
    ~loop.loopEnd = (~loop.index == ~loop.length);
});

~stream = Pbind(
    \instrument, \sawPluck,
    \type, Pfunc({|ev| if (~loop.loopEnd) {\rest} {\note} }),
    \dur, Pfunc({|ev| if(ev.type == \note) {[0.25, 0.5, 1].wchoose([~loop.length-~loop.index, 4, ~loop.index].normalizeSum)} {[4, 8].choose}}),
    \scaleNotes, Pfunc({|ev| if (~loop.loopStart) {~scaleNotes = ~scaleNotes.scramble}; ~scaleNotes }),
    \midinote, Pfunc({|ev| ev.scaleNotes.wrapAt(~loop.index) + 60 }),
    \amp, Pwhite(0.3, 0.5, inf),
    \detune, 0.5 + Pkey(\amp).linlin(0.3, 0.5, 0, 0.5),
    \spread, 0.25 + Pkey(\amp).linlin(0.3, 0.5, 0, 0.25),
    \cutoff, 72.midicps + Pkey(\amp).linlin(0.3, 0.5, 0, 7).midicps,
    \fEnvAmp, 24.midicps,
    \rel, Pkey(\amp).linlin(0.3, 0.5, 0.5, 1) * Pwhite(1.0, 2.0),
    \fRel, Pkey(\amp).linlin(0.3, 0.5, 0.5, 1) * 1,
    \subAmp, Pwhite(0.02, 0.1, inf),
    \subOctave, 2
) <> ~looper;

~stream.play;
)