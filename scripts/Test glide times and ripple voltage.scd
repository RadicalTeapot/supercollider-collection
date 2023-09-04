~useAudioInterface.();

(
~voice = SynthDef(\voice, {
    |freq=440, detune=0, detuneFreq=0, glide=0, t_trig=0, envMix=0, atk=0.05, rel=1, dur=1, amp=0.25, sawPulseMix=0, out=0|
    var sig, env;
    freq = VarLag.kr(freq, glide);
    freq = freq * (LFTri.ar(detuneFreq, 1).bipolar(((detune.midiratio - 1) * 0.5)) + 1);
    sig = SelectX.ar(K2A.ar(sawPulseMix), [VarSaw.ar(freq, width: 0), LFPulse.ar(freq)]);
    env = Env.perc(atk, rel).kr(gate: t_trig, timeScale: dur);
    env = SelectX.kr(envMix, [1, env]);
    Out.ar(out, sig.dup * env * amp);
}).add;
)

// 9 bits
(
~notes = (0,0.009765625..1) * 12 +.x [60, 72];
Pmono(
    \voice,
    \dur, 0.25,
    \detune, 12*0.01818,
    \detuneFreq, 31250,
    \glide, 0.0124,
    \midinote, Pshuf(~notes, inf), //Pn(Pshuf(Scale.minorPentatonic.degrees +.x [48, 60], 1)),
    \envMix, 1,
    \t_trig, 1,
    \atk, 0.05,
    \sawPulseMix,0
).play;
)

// 8 bits
(
~notes = [60, 72] +.x ((0,0.01953125..1) * 12);
Pmono(
    \voice,
    \dur, 0.05,
    \detune, 12*0.02,
    \detuneFreq, 44100,
    \glide, 0.0055,
    \midinote, Pseq(~notes, inf),
    // \envMix, 1,
    // \t_trig, 1,
    // \atk, 0.05,
    \sawPulseMix,1
).play;
)