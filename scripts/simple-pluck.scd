(
s = Server.default;
s.waitForBoot {
    var buffers, bus;
    s.free;
    s.newBusAllocators;
    Buffer.freeAll;
    s.sync;

    bus = Bus.audio(s, 2);
    buffers = 3.collect {|i| Buffer.alloc(s, 4 * s.sampleRate, 2) };
    s.sync;

    SynthDef(\pluck, {
        var freq = \freq.kr(440);
        var pwm = \pwm.kr(0.5);
        var pwmEnv = \pwmEnv.kr(0);
        var pwmEnvDur = \pwmEnvDur.kr(1);
        var dur = \dur.kr(1);
        var rq = \rq.kr(0.5);
        var cf = \cf.kr(200000);
        var cfEnv = \cfEnv.kr(0);
        var cfEnvDur = \cfEnvDur.kr(1);
        var pan = \pan.kr(0);
        var amp = \amp.kr(-6.dbamp);
        var out = \out.ir(0);

        var sig = Pulse.ar(
        freq.clip(20, 20000),
            (pwm * Env.perc.ar(Done.none, timeScale: pwmEnvDur).range(1, 1+pwmEnv)).clip(0, 1));
        sig = RLPF.ar(
        sig,
            (cf * Env.perc.ar(Done.none, timeScale: cfEnvDur).range(1, 1+cfEnv)).clip(20, 20000),
                rq.clip(0.001, 1)
        ) * (rq.clip(0,1)+1).sqrt;
        sig = sig * Env.perc.ar(Done.freeSelf, timeScale: dur);
        sig = Pan2.ar(sig, pan);
        sig = sig * amp;
        Out.ar(bus, sig);
        Out.ar(out, sig);
    }).add;
    SynthDef(\fx, {
        var in = \in.ir(0);
        var out = \out.ir(0);

        var sig = In.ar(in, 2);
        var prev = LocalIn.ar(2);
        prev = Balance2.ar(prev[0], prev[1], LFNoise2.ar(5).range(-1, 1));
        prev = DelayN.ar(sig, 1, 1);
        sig = sig.blend(prev, 0.25);
        sig = sig.blend(NHHall.ar(HPF.ar(sig, 200), 2, 0.8), 0.2);
        LocalOut.ar(HPF.ar(sig, 50));
        ReplaceOut.ar(out, sig);
    }).add;
    SynthDef(\looper, {
        var buf = \buf.ir(0);
        var in = \in.ir(0);
        var out = \out.ir(0);
        var fadeTime = \fadeTime.kr(0.1);

        var trig = Dust.ar(0.05);
        var fadeTrigDelay = Trig.ar(trig, fadeTime);
        var writeGate = Trig.ar(1-fadeTrigDelay, BufDur.kr(buf));
        var writePhasor = Phasor.ar(writeGate, BufRateScale.kr(buf), 0, BufFrames.kr(buf));
        //Note: we assume BufDur > 2 * fadeTime
        var writeEnv = Env.linen(fadeTime, BufDur.kr(buf) - (fadeTime * 2), fadeTime).ar(0, writeGate);

        // Global playback envelope
        var playGate = 1 - min(fadeTrigDelay + writeGate, 1);
        var playEnv = Env.asr(fadeTime, 1, fadeTime, 0).ar(Done.none, playGate);

        // Those are randomized on write
        var dur = TRand.kr(0.1, 0.7, writeGate) * BufDur.kr(buf);
        var speed = TChoose.kr(writeGate, [0.5, 1, 2, 4]) * TChoose.kr(writeGate, [-1, 1]);
        var start = TRand.kr(0, 1, writeGate);

        var readTrig = Impulse.ar(dur.reciprocal);
        // Only trigger envelope from time to time (dust with low freq)
        var readEnv = Env.linen(fadeTime, dur - (2*fadeTime), fadeTime).ar(Done.none, Dust.ar((dur * 5).reciprocal));
        var readPhasor = Phasor.ar(readTrig, speed * BufRateScale.kr(buf), 0, BufFrames.kr(buf), start);

        var sig, input;

        input = BufRd.ar(2, buf, writePhasor);
        //input = input.blend(NHHall.ar(input), 0.1);
        input = LPF.ar(HPF.ar(input, 80), 10000);
        // Only record new values writeGate is on
        BufWr.ar(SelectX.ar(writeEnv, [
            input,
            In.ar(in, 2),
        ]), buf, writePhasor);

        sig = BufRd.ar(2, buf, readPhasor);
        sig = LPF.ar(HPF.ar(sig, LFNoise2.ar(0.1).range(20, 100)), LFNoise2.ar(0.1).range(1000, 15000));
        sig = sig * readEnv * playEnv;
        sig = Balance2.ar(sig[0], sig[1], LFNoise2.kr(0.2).range(-1, 1));
        sig = sig.blend(NHHall.ar(sig, 2, 0.8), LFNoise2.ar(0.1).range(0.1, 0.5));

        Out.ar(out,sig);
    }).add;
    s.sync;

    s.bind { Synth(\fx) };
    s.bind { buffers.do {|buf| Synth(\looper, [buf: buf, in: bus]); } };
    Routine {
        var lfsr = {|seed = 1, taps = #[0, 2, 3, 5], size=4|
            var register = seed.asInteger;
            var maxValue = ((2**size)-1).asInteger;
            var bit;
            Routine { loop {
                bit = taps.collect { |tap| (register >> tap) & 1 }.sum % 2;
                register = ((register << 1) | bit) & maxValue;
                register.yield;
            }};
        };
        var pingPong = {|min=0, max=1, initialStep=0.1, initialValue=0|
            var value = initialValue;
            var step = initialStep;
            var direction = 1;
            var range = abs(max - min);
            Routine { loop {
                if ((value < min) || (value > max)) {
                    direction = direction * -1;
                    step = range * rrand(0.02, 0.08);
                };
                value = value + (step * direction);
                value.yield;
            }};
        };
        var l1 = lfsr.();
        var l2 = lfsr.(seed: 2, size: 8);
        var l3 = lfsr.(seed: 3, size: 8);
        var l4 = lfsr.(size: 6);
        loop {
            var freq = (Scale.minorPentatonic.performDegreeToKey(l1.next.linlin(0, 16, 0,  10)) + 36).midicps;
            var pwm = rrand(0.4, 0.6) + freq.linlin(36.midicps, 60.midicps, 0, 0.1);
            var cf = l3.next.linlin(0, 16, freq * 0.5, freq * 1.5);
            var dur = rrand(0.5, 1) + freq.linlin(36.midicps, 60.midicps, 0.5, 0.0);
            if (l4.next > 20) {
                s.bind { Synth(\pluck, [freq: freq, pwm: pwm, pwmEnvDur: 0.25 * dur, pwmEnv: 0.2, cf: cf, cfEnv: 5, cfEnvDur:
                    0.5 * dur]) };
            };
        ([1, 2, 4, 8].wrapAt(l2.next) * 0.25).wait
        } }.play;
}
)

// Test looper envs
(
{
    var fadeTime = 0.01;
    var bufDur = 0.03;
    var trig = Impulse.ar(10);
    var delay = Trig.ar(trig, fadeTime);
    var writeGate = Trig.ar(1-delay, bufDur);
    var writeEnv = Env.linen(fadeTime, bufDur - (fadeTime * 2), fadeTime).ar(0, writeGate);
    var playGate = 1-min(delay+writeGate, 1);
    var playEnv = Env.asr(fadeTime, 1, fadeTime, 0).ar(Done.none, playGate);
[delay, writeGate, writeEnv, playGate, playEnv];
}.plot(0.2);
)

s.plotTree
