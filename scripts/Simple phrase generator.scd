(
s = Server.default;

s.newBusAllocators;
~controlBus = Bus.control(s, 1);

s.waitForBoot {
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    SynthDef(\drone, {
        var trigger, freq, dur, amp, out;
        var env, sig;

        trigger = \trigger.tr(0);
        freq = \freq.kr(60.midicps);
        dur = \duration.kr(1);
        amp = \amp.kr(-6.dbamp);
        out = \out.ir(0);

        sig = SinOsc.ar(freq);
        env = Env.perc().kr(Done.none, gate: trigger, timeScale: dur*2) * 0.75 + 0.25;
        sig = (sig * 2 * env).tanh;
        sig = Pan2.ar(sig) * amp;
        sig = Limiter.ar(sig);

        Out.ar(out, sig);
    }).add;

    SynthDef(\pulse, {
        var freq, dur, amp, pan, out;
        var env, sig;

        freq = \freq.kr(60.midicps);
        dur = \duration.kr(1);
        amp = \amp.kr(-6.dbamp);
        pan = \pan.kr(0);
        out = \out.ir(0);

        sig = LFPulse.ar(freq);
        sig = RLPF.ar(sig, XLine.ar(1000, freq * 0.25, dur).clip(20, 20000), 0.33);
        env = Env.perc().kr(Done.freeSelf, timeScale: dur*2);
        sig = sig * env;
        sig = Pan2.ar(sig, pan) * amp;
        sig = Limiter.ar(sig);

        Out.ar(out, sig);
    }).add;

    SynthDef(\hihat, {
        var trigger, hpfFreq, amp, decay, pan, out;
        var env, noise, hpf, sig;

        trigger = \trigger.tr(0);
        hpfFreq = \hpfFreq.kr(8000);
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.1);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(gate: trigger);
        noise = WhiteNoise.ar();
        hpf = HPF.ar(noise, 8000);
        sig = hpf * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(0, sig);
    }).add;

    s.sync;
};

~generateHalfBarSeq = { |degree, root, scale = (Scale.major.semitones)|
    var pattern, climaxPos, climaxRamp, degreeOffsetScale, chordShape, event;
    pattern = [
        [1, 0.5, 0.5],
        [0.5, 0.5, 0.5, 0.5],
        [1, 1],
        [0.5, 0.5, 1],
        [0.5, 1.5],
        [1.5, 0.5],
    ].choose;

    climaxPos = ([0, 1, -2, -1].choose + pattern.size) % pattern.size;
    climaxRamp = pattern.collect({|v, i| if (i == climaxPos, 1.0, if (i < climaxPos, i.asFloat/climaxPos, (pattern.size - i).asFloat / (pattern.size - climaxPos)))});

    chordShape = [0,2,4];
    degreeOffsetScale = [2, 3].choose;

    event = (notes: [], velocities: [], durations: []);
    pattern.do { |duration, i|
        var offset, d;
        event.durations = event.durations.add(duration);
        event.velocities = event.velocities.add(1 - (climaxRamp[i] * 0.1));
        offset = (degreeOffsetScale * climaxRamp[i]).asInteger;
        if ((i == 0) || (i == (pattern.size - 1))) {
            d = chordShape[chordShape.indexOfGreaterThan(offset)] + degree;
        } {
            d = degree + offset;
        };
        event.notes = event.notes.add(root + scale[d % scale.size] + (12 * d.div(scale.size)));
    };
    event;
};
)

(
TempoClock.default.tempo = 2;

s.makeBundle(s.latency, {
    ~hihat = Synth(\hihat);
    ~drone = Synth(\drone, [amp: -18.dbamp]);
});

fork { loop {
    var degree = rrand(0, 6);
    var seq = ~generateHalfBarSeq.(rrand(0, 6), 48);

    s.makeBundle(s.latency, {
        ~drone.set(\trigger, 1, \freq, (Scale.major.semitones[degree] + 36).midicps, \duration, 1);
    });

    2.yield;

    seq.notes.do { |note, i|
        s.makeBundle(s.latency, {
            Synth(\pulse, [freq: note.midicps, amp: -6.dbamp * seq.velocities[i], duration: seq.durations[i]]);
        });
        seq.durations[i].yield;
    };
}};

fork { loop {
    s.makeBundle(s.latency, {
        ~hihat.set(\trigger, 1, \amp, -10.dbamp);
    });
    (0.5).yield;
}};
)