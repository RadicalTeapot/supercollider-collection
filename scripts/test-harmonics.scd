(
s = Server.default;
s.waitForBoot {
    s.free;
    s.sync;

    SynthDef(\harmonics, {
        var freq = \freq.kr(110);
        var harmonics = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        var levels = harmonics.collect { |v| 1/(v**3) };
        var sig = SinOsc.ar(freq * harmonics * LFNoise2.ar(0.1.dup(harmonics.size)).range(0.995, 1.005)) * levels;
        sig = Splay.ar(sig, 0.1);
        Out.ar(0, sig * \amp.kr(-6.dbamp));
    }).add;
    s.sync;

    a = Synth(\harmonics, [freq: 24.midicps, amp: 2]);
    Routine { loop { 
        var freq = (Scale.minorPentatonic.performDegreeToKey([0, 3, 5, 7, 10].choose) + 24).midicps;
        s.bind { a.set(\freq, freq) };
        2.yield;
    } }.play;
    s.meter(0, 2);
};
)

