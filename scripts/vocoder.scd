(
s.waitForBoot {
    var noraBuffer, carrierBuffer, vocoder;

    s.freeAll;
    Buffer.freeAll;
    s.sync;

    noraBuffer = Buffer.read(s, "C:/Users/mathi/AppData/Local/_data/recordings/field_recordings/nora_singing_13.wav");
    carrierBuffer = Buffer.read(s, "C:/Users/mathi/AppData/Local/_data/recordings/field_recordings/sea crashing waves wind 1.WAV");
    s.sync;

    SynthDef(\vocoder, {
        var car, bpfcar, mod, bpfmod, track, sig,
        num = 30, q = \q.kr(10), bpfhz = (1..num).linexp(1, num, 25, 16000);
        mod = PlayBuf.ar(2, noraBuffer, BufRateScale.ir(noraBuffer), loop: 1);
        car = PlayBuf.ar(2, carrierBuffer, BufRateScale.ir(carrierBuffer), loop: 1);
        car = CombL.ar(car, 1/20, 1 /\freq.kr(48.midicps), 3);
        bpfmod = BPF.ar(mod, bpfhz, 1/q, sqrt(q));
        track = Amplitude.kr(bpfmod).lag(0.03);
        bpfcar = BPF.ar(car, bpfhz, 1/q, sqrt(q)) * track * 10;
        sig = Splay.ar(bpfcar.scramble, 0.2);
        sig = Limiter.ar(sig);
        Out.ar(\out.ir(0), sig);
    });
    s.sync;

    fork {
        var scale = Scale.lydian.semitones,
        root = 48, vocoder;
        s.bind {vocoder = Synth(\vocoder, [q: 20])};
        loop {
            var time = [1, 2, 4, 8].choose / 8;
            var degree = rrand(0, 14);
            s.bind {vocoder.set(\freq, (scale.performDegreeToKey(degree) + root).midicps)};
            time.yield;
        }
    };
}
)
