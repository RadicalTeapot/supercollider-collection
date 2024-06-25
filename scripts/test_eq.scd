(
s = Server.default;

s.waitForBoot({
    SynthDef(\kick, {
        var trigger, freq, amp, decay, pan, out;
        var env, fmEnv, osc, sig;

        trigger = \trigger.tr(0);
        freq = \freq.kr(41); // E1
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.5);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(gate: trigger);
        fmEnv = Env.perc(releaseTime: decay).kr(gate: trigger, timeScale: 0.4).range(0.9, 1.1);
        osc = SinOsc.ar(freq * fmEnv);
        sig = osc * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    SynthDef(\snare, {
        var trigger, freq, bpfFreq, amp, decay, pan, out;
        var env, noise, osc, sig;

        trigger = \trigger.tr(0);
        freq = \freq.kr(164); // E3
        bpfFreq = \bpfFreq.kr(1320); // E6
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.2);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(gate: trigger);
        noise = WhiteNoise.ar();
        osc = SinOsc.ar(freq);
        sig = noise + (osc * -3.dbamp);
        sig = BPF.ar(sig, bpfFreq) * env;
        sig = Pan2.ar(sig, pan) * amp;

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

    SynthDef(\bowl, {
        var freq, pan, amp, out;
        var sig, exc;
        freq = \freq.kr(261);
        pan = \pan.kr(0);
        amp = \amp.kr(-6.dbamp);
        out = \out.ir(0);

        exc = PinkNoise.ar() * Env.perc(0.01, 0.03).ar();
        sig = Klank.ar([
            `[[530, 1430, 2550, 3130], [-20, -34.5, -52.5, -79.8].dbamp, [20, 10, 7, 4]],
            `[[532, 1440, 2550, 3120, 3672], [-20, -25.5, -53.5, -85.8, -72.2].dbamp, [20, 10, 7, 4]],
        ], exc, freq/530) * amp;
        sig = sig * SinOsc.kr(5 * Rand(0.9, 1.2), [0, pi * Rand(0.9, 1.1)]).range(0.3, 1);

        DetectSilence.ar(sig, doneAction: Done.freeSelf);
        Balance2.ar(sig[0], sig[1], pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\pan, {
        |freq = 440, pan = 0, amp = 0.5|
        var sig, lfo;
        sig = Resonz.ar(
            WhiteNoise.ar()!2 * Env.perc(releaseTime: 0.001).ar(),
            [150, 300, 440, 600, 700, 900, 1200] / 300 * freq,
            Line.ar(0.002, (1 / [1.5, 1, 0.5, 1.5, 0.8, 0.7, 2]) * 0.001, 0.001).lincurve(0.00001, 0.002, 0.00001, 0.002, [4, 2, 8, 4, 4, 2, 8] * 0.75)
        );
        lfo = SinOsc.ar([1, 2, 2, 5, 6, 6.5, 7] * Array.rand(6, 0.99, 1.01), pi/2).range([0.8, 0.5, 0.66, 0.66, 0.66, 0.8, 0.9], 1);
        sig = sig * 3000 * amp * [0.25, 1.0, 0.02, 0.075, 0.05, 0.15, 0.01].squared * lfo;
        DetectSilence.ar(sig.sum, 0.02, doneAction: Done.freeSelf);
        Out.ar(\out.ir(0), Splay.ar(sig.scramble, 0.5, center: pan));
    }).add;

    SynthDef(\drone, {
        |freq = 220, amp=1|
        var rq = LFNoise2.kr(0.5).range(0.2, 0.8).lag(0.2);
        var trig = Dust.kr(0.01);
        var sig = Saw.ar(freq * LFNoise2.kr(2!10).range(-0.2, 0.2).midiratio);
        var bands = Array.series(16, 20, (20000-20)/15).linexp(20, 20000, 20, 20000);
        bands = bands.collect{|v, i| (FSinOsc.kr(sqrt(i+1) * 0.1, Rand(0, 2*pi)) * sqrt(i+1) * 20 + v).clip(20, 20000)};
        sig = BPF.ar(sig, bands, rq) * sqrt(rq) * 5 * amp;
        sig = (MoogFF.ar(sig, (100 + LFNoise2.kr(4!5).range(-50, 100) + Env.perc(2, 10).kr(0, trig).range(0, 600)).clip(20, 20000), 3)).tanh;
        Out.ar(0, Splay.ar(sig.scramble, LFNoise2.kr(0.1).range(0.5, 1.0)));
    }).add;

    SynthDef(\spectralFx, {
        var sig, out;
        var size = 128; // FFT size
        var updateTrigger = Impulse.kr(\updateFreq.kr(100));
        var indexLFOs = size.collect{|i| FSinOsc.kr(sqrt(i+1) * \lfoFreq.kr(1.0), Rand(0, 2*pi)) * sqrt(i+1) * \lfoRange.kr(1.0).lag(1) };
        var in = In.ar(\in.ir(0), 2);
        var fft = FFT(LocalBuf(size), in.sum);
        fft = fft.pvcollect(size, {| magnitude, phase, index |
            var mag = Demand.kr(updateTrigger, 0, Unpack1FFT(fft, size, (index + indexLFOs[index]).clip(0, size-1), 0)).lag(0.1);
            [mag, phase]
        });

        sig = IFFT(fft)!2;
        ReplaceOut.ar(\out.ir(0), in.blend(sig, \dryWet.kr(0.2).lag(1)));
    }).add;

    SynthDef(\fx, {
        var sig;
        sig = In.ar(\out.kr(0), 2) * -6.dbamp;
        sig = sig.blend(NHHall.ar(sig, 2), 0.25);
        ReplaceOut.ar(\out.kr(0), sig);
    }).add;
    s.sync;
})
)

(
var patterns, metro, root;
var fretboard, lastPlayedNotes, intensityTriggerChance;
metro = TempoClock.new(80/60, -1);
root = 52;

s.bind {
    ~kick = Synth(\kick);
    ~snare = Synth(\snare, [pan: 0.2, amp: -16.dbamp, decay: 0.3]);
    ~hihat = Synth(\hihat, [pan: 0.2, amp: -10.dbamp]);
    ~drone = Synth(\drone, [freq: (root-12).midicps, amp: -3.dbamp]);

    ~spectral = Synth.tail(s, \spectralFx);
    ~fx = Synth.tail(s, \fx);
};

patterns = [
    (type: \perc, synthVar: ~kick,  triggers: [1,\,1,\,1,0.2,1,\], amp: [-2.0, -3.0].dbamp ),
    (type: \perc, synthVar: ~snare, triggers: [\,\,1,\,\,\,1,\], amp: (-15 + [0.0, -4.0]).dbamp ),
    (type: \perc, synthVar: ~hihat, triggers: [1,0.75,1,0.33,1,0.75,1,0.33], amp: (-11 + [0.0, -2.0]).dbamp ),
    (type: \bowl, degrees: (0..10) + 5, amp: [-10.0, -13.0].dbamp),
    (type: \pan, degrees: (0..10), probability: 0.75, percPatterns: [
        [1,1,1,1],
        [0.25,0.25,0.5,\,\,\],
        [0.25,0.25,\,0.5,0.5,0.5,\],
        \,
    ], percPatternsWeight: [3, 2, 1, 1].normalizeSum)
];

~playDrumNote = {
    |trigger, synthVar, amp|
    var offset = exprand(0.001, 0.01);
    offset.yield;
    if ((trigger != \) && (trigger.coin)) { s.bind { synthVar.set(\trigger, 1, \amp, amp ) } };
    (0.5 - offset).yield; // 8th notes
};

~playBowl = {
    |degrees, amp, scale = (Scale.lydian.semitones), root=52|
    var time = [1,2,4,8].choose;
    var note = scale.performDegreeToKey(degrees.choose) + root;
    var pan = exprand(0.5, 1) * [-1, 1].choose;
    var offset = exprand(0.005, 0.02);
    offset.yield;
    s.bind { Synth(\bowl, [freq: note.midicps, amp: amp, pan: pan]) };
    (time - offset).yield;
};

~playPan = {
    |degrees, probability, amp, percPatterns, percPatternsWeight, scale = (Scale.lydian.semitones), root=52|
    var percPattern = percPatterns.wchoose(percPatternsWeight);
    if (percPattern == \) {
        var time = [1,2,4,8].choose;
        time.yield;
    } {
        percPattern.do { |time|
            var offset = exprand(0.005, 0.02);
            offset.yield;
            if (time != \) {
                var note = scale.performDegreeToKey(degrees.choose) + root;
                var pan = exprand(0.2, 0.5) * [-1, 1].choose;
                s.bind { Synth(\pan, [freq: note.midicps, amp: amp, pan: pan]) };
            } {time=1};
            (time - offset).yield;
    } };
};

patterns.do{|pattern|
    switch(pattern.type,
        \perc, { { loop { pattern.triggers.do { |trigger| ~playDrumNote.(trigger, pattern.synthVar, rrand(pattern.amp[0], pattern.amp[1])) } } }.fork(metro) },
        \bowl, { { loop { ~playBowl.(pattern.degrees, rrand(pattern.amp[0], pattern.amp[1]), [0, 4, 6, 9, 11], root); } }.fork(metro) },
        \pan, { { loop { ~playPan.(pattern.degrees, pattern.probability, 1, pattern.percPatterns, pattern.percPatternsWeight, Scale.lydian.semitones, root); } }.fork(metro) },
    );
};

fork { loop { rrand(4, 10).yield; ~spectral.set(\dryWet, rrand(0.0, 0.2), \lfoRange, rrand(0.5, 3.0)); } };
\;
)