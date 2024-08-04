(
s.waitForBoot({
    var delayBuf;

    Buffer.freeAll;
    delayBuf = Buffer.alloc(s, 4 * s.sampleRate, 2);
    s.sync;

    SynthDef(\lostWoods, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var amp = \amp.kr(0.1);
        var switch = \switch.kr(0).varlag(2);

        var input = SoundIn.ar(in + [0,1]);
        var envFollow = Amplitude.ar(input[0], releaseTime: 0.1).lag(0.05).lincurve;
        var rev = FreeVerb2.ar(input[0], input[1], 0.28, (0.5 + (envFollow * 0.5)).clip(0, 1));
        var pitch = Pitch.kr(input[0]).linlin(60, 4000, 0, 1).lag(0.05);
        var lfo = LFTri.ar(1 + ((pitch + (switch * 0.3)) * 100)).unipolar(1);
        var sig = (rev * (1-switch) * 0.5) + (rev * [lfo, 1-lfo]);
        sig = sig * amp;
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var sig, bufPhasor, rev, delay;
        var buf = \buf.ir(0);
        var in = \in.ir(0);
        var out = \out.ir(0);

        sig = In.ar(in, 2);
        sig = sig + (BPF.ar(PinkNoise.ar(1!2) * WhiteNoise.ar(1!2), 2000, 0.75) * LFNoise2.kr(0.5!2).linlin(-1, 1, -52.dbamp, -42.dbamp)); // Crackle

        bufPhasor = Phasor.ar(rate: BufRateScale.ir(buf), end: BufFrames.ir(buf));

        rev = NHHall.ar(sig, 2);
        delay = BufRd.ar(2, buf, (bufPhasor + LFNoise2.ar(2!2).lincurve(-1, 1, 0, BufSampleRate.ir(buf) * 0.004, 10)).wrap(0, BufFrames.ir(buf))).rotate; // Ping pong tape delay
        sig = sig.blend(rev, 0.25).blend(delay, 0.2);
        sig = sig.tanh;

        sig = LPF.ar(HPF.ar(sig, 200), 5000);
        sig = sig.blend(BPF.ar(PinkNoise.ar(1!2), LFNoise1.kr(2.3587!2).linlin(-1, 1, 2000, 4000), 0.95), 0.003);

        RecordBuf.ar(sig, buf, recLevel: 1, preLevel: -6.dbamp);
        sig = Compander.ar(sig, sig, 0.4, 1, 5.reciprocal, 0.005, 0.5);

        ReplaceOut.ar(out, sig);
    }).add;
    s.sync;

    x = Synth(\lostWoods, [amp: -6.dbamp]);
    Synth.tail(s, \fx, [buf: delayBuf]);

    Routine {
        var chance = 0.1;
        var state = 0;
        inf.do {
            var time = rrand(10, 20) * state.linlin(0, 1, 1, 0.2);
            if (chance.coin) {
                state = 1 - state;
                s.bind {x.set(\switch, state)};
                chance = 1 - chance;
                ("Stomp"+state).postln;
            };
            time.yield;
        }
    }.play;
});
)