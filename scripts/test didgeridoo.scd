(a = {
    var freq, rq, amp, out;
    var sig;

    freq = \freq.kr(120);
    amp = \amp.kr(-6.dbamp);
    out = \out.ir(0);

    rq = 0.5;

    sig = LFSaw.ar(freq * (LFNoise2.kr([2.9, 3.1]).range(-0.05, 0.05).lag(0.5)).midiratio * 0.5).blend(WhiteNoise.ar(), 0.2) * LFNoise2.kr(2).range(0.9, 1.1).lag(2);
    sig = BPF.ar(sig, freq.clip(20, 20000), rq);
    sig = BPF.ar(sig, (Env.perc(0.5, 1).kr(Done.none, Impulse.kr(0.25)) * WhiteNoise.ar().range(0.9, 1) * 600 + freq).clip(20, 20000), 0.2) * (Env.perc(0.5, 1.5).kr(Done.none, Impulse.kr(0.25)) * 5 + 5);
    sig = sig + (SinOsc.ar(freq * 0.5 * (LFNoise2.kr(3).range(-0.02, 0.02).lag(0.5)).midiratio) * -12.dbamp);
    sig = (sig * 1).tanh;
    sig = sig.blend(NHHall.ar(sig, 1), 0.33);
    // sig = sig.blend(CombL.ar(sig, 0.5, 0.5, 5), 0.33);
    sig = Limiter.ar(sig * amp);
    Out.ar(out, sig);
}.play;
)

a.set(\freq, 40.midicps);
a.set(\amp, -6.dbamp);