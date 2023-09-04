~useAudioInterface.value;

(
SynthDef(\voice, {
    var freqDetune = LFNoise2.ar(\detuneFreq.kr(5)!5).bipolar(\detune.kr(0.17));
    var sig = VarSaw.ar(\freq.kr(440) + freqDetune, width: \pwm.kr(0.5));
    var env = Env.perc(\atk.kr(0.05), \rel.kr(1)).kr(2);
    sig = MoogFF.ar(sig, (\cf.kr(20000) + freqDetune).clip(20,20000));
    sig = Splay.ar(sig, \spread.kr(1), center: \pan.kr(0));
    Out.ar(\bus.kr(0), sig * env * \amp.kr(0.03));
}).add;

~base = Pbind(
    \instrument, \voice,
    \dur, Pwrand([0.5, Rest(0.5)], [0.75, 0.25], inf),
    \rel, 5 - Pexprand(2, 4),
    \atk, Pexprand(0.2, 0.5),
    \amp, Pmeanrand(0.02, 0.04),
);

~voiceA = Pbind(
    \pan, Pexprand(hi: 0.5) * -1,
    \midinote, Pseq([-3, 0, 2, 4, 7, 9, 7, 4, 2, 0, -3], inf) + 60,
    \cf, Pexprand(800, 1600) + Pkey(\freq) * 0.25,
) <> ~base;

~voiceB = Pbind(
    \pan, Pexprand(hi: 0.5),
    \midinote, Pseq([-7, -3, 0, 2, 5, 7, 5, 2, 0, -3, -7], inf) + 72,
    \cf, Pexprand(1200, 2400) + Pkey(\freq) * 0.25,
) <> ~base;

~voiceC = Pbind(
    \instrument, \voice,
    \midinote, 39, //Pwrand([32, 39], [0.75, 0.25], inf),
    \rel, 8,
    \dur, Pwrand([8, Rest(8)], [0.75, 0.25], inf),
    \cf, 300,
    \amp, 0.1
);
)

(
~clock = TempoClock(20.0/60.0);
~clock.beats_(-0.1);
~voiceA.play(~clock, quant: 1);
~voiceB.play(~clock, quant: Quant(1, 0.25));
~voiceC.play(~clock, quant: 1);
)