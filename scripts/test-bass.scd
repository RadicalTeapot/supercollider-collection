(
s = Server.default;
s.waitForBoot {
    s.free;
    s.sync;

    SynthDef(\bass, {
        var freq = \freq.kr(440) * (LFNoise2.ar(\detuneFreq.kr(1)!5).bipolar(\detune.kr(0.1)).midiratio);
        var width = \width.kr(0.5) + (LFNoise2.ar(\detuneFreq.kr(1)!5).bipolar(\widthDetune.kr(0.1)));
        var cf = (\cf.kr(20000) * LFNoise2.ar(\detuneFreq.kr(1)!2).bipolar(\cfDetune.kr(0.1)).midiratio).clip(20, 20000);
        var sig = Mix.ar(Pulse.ar(freq, width.fold(0.01, 0.999)) * 0.2);
        sig = sig + (SinOsc.ar(\freq.kr(440) * 0.5) * \sub.kr(0.5));
        sig = RLPF.ar(sig, cf, \rq.kr(1).clip(0, 1));
        sig = sig * (LFNoise2.ar(\detuneFreq.kr(1)!2).bipolar(\detuneAmp.kr(0.1)).midicps.clip(0, 1));
        sig = sig * \amp.kr(1);
        sig = sig.blend(NHHall.ar(sig, 4, 0.8, 40), 0.33);
        Out.ar(0, sig);
    }).add;
    s.sync;

    a = Synth(\bass, [\freq, 40, \cf, 80, \amp, 0.33, \rq, 0.33, \detune, 0.1, \detuneFreq, 0.2, \width,
    0.1, \widthDetune, 0.2, \detuneAmp, 0.5, \sub, 0.4, \cfDetune, 5]);
};
)

s.meter(0, 2);
