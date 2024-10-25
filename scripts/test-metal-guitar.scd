(
s = Server.default;
s.waitForBoot {
    var patterns;
    s.free;
    s.sync;

    SynthDef('\guitar', {
        var hpf = 40;
        var sig = Pulse.ar(\freq.kr(440), 0.175);
        sig = sig * 3;
        sig = LPF.ar(sig, \cf.kr(20000).clip(20, 20000));
        sig = HPF.ar(HPF.ar(sig, hpf), hpf);
        sig = sig.tanh * 1.5;
        sig = sig * Env.perc(0.02, curve: -4).ar(Done.none, \trig.tr(0), \dur.kr(0.25));
        sig = Compander.ar(sig, sig, 0.4, 1, 0.2, 0.01, 0.05) * \amp.kr(1);
        Out.ar(\out.ir(0), sig);
    }).add;
    s.sync;

    patterns = [
        (
            rhythm: [0,0,0,\,0,0,0,\,0,0,0,\,0,0,0,\],
            accents: [\,\,\,\,\,\,\,\,\,\,\,\,\,\,\,\],
        ),
        (
            rhythm: [0,0,0,0,0,\,0,\,0,0,0,0,0,\,0,\,],
            accents: [\,\,\,\,\,\,\,\,\,\,\,\,\,\,\,\],
        ),
        (
            rhythm: [0,0,\,0,0,0,\,0,0,0,\,0,0,0,\,0],
            accents: [\,\,\,\,\,\,\,\,\,\,\,\,\,\,\,\],
        ),
        (
            rhythm: [0,0,0,\,0,0,\,0,0,\,0,\,0,0,0,0],
            accents: [\,\,\,\,\,\,\,\,\,\,\,\,\,\,\,\],
        ),
    ];

    Routine({
        var rhythm = patterns[0].rhythm;
        var synth;
        s.bind {synth = Synth(\guitar, [freq: 82, cf: 2000, amp: 0.5, dur: 0.22])};
        loop {
            rhythm.do { |note|
                if (note != \) { s.bind { synth.set(\trig, 1) } };
                0.1.wait;
            }
        }
    }).play;
}
)