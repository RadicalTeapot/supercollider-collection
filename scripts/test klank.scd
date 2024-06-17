(
s = Server.default;

s.waitForBoot({
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    s.bind {
        {
            var ir, irbuffer, bufsize;
            ~fftsize = 2048;

            irbuffer = Buffer.readChannel(s, "~/Downloads/Ovation_Celebrity_CE44_48000.wav".standardizePath, channels: [0]);
            s.sync;

            bufsize = PartConv.calcBufSize(~fftsize, irbuffer);
            ~irspectrum = Buffer.alloc(s, bufsize, 1);
            ~irspectrum.preparePartConv(irbuffer, ~fftsize);
            s.sync;

            irbuffer.free; // don't need time domain data anymore, just needed spectral version
        }.fork; // Needs to run as a Routine (PartConv is a UGen)
    };
    s.sync;

    SynthDef(\guitarString, {
        var freq, decay, out, amplitudes, overtones, duration, pan, trigger; // Input variables
        var frequencies, fastDecay, slowDecay; // Internal variables
        var sig, fastEnvs, slowEnvs; // UGens

        freq = \freq.kr(164.81) + \detune.kr(0); // E3 + constant detuning for this string
        decay = \decay.kr(1);
        duration = \duration.kr(1);
        out = \out.ir(0);
        amplitudes = \amplitudes.kr((0.1).dup(12));
        pan = \pan.kr(0);
        overtones = \overtones.kr((1..12));
        trigger = \trigger.tr(0);

        frequencies = freq * overtones * (LFNoise2.kr(1.0 * overtones) * (0.033 * overtones)).midiratio;
        fastDecay = (frequencies.squared * (decay * 4.0 * 10e-7) * -1).exp; // Quadratic damping
        slowDecay = (frequencies.squared * (decay * 1.0 * 10e-7) * -1).exp; // Quadratic damping

        sig = SinOsc.ar(frequencies);
        fastEnvs = Env.perc(releaseTime: duration * fastDecay).ar(Done.none, trigger) * 0.33;
        slowEnvs = Env.perc(releaseTime: duration * slowDecay).ar(Done.none, trigger) * 0.66;
        sig = sig * amplitudes * (fastEnvs + slowEnvs);
        sig = (sig.sum * 2).tanh * 0.75;
        sig = sig.blend(PartConv.ar(sig, ~fftsize, ~irspectrum.bufnum, 0.3), 0.2);
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\guitarKlank, {
        var freq, decay, out, amplitudes, overtones, duration, pan, trigger; // Input variables
        var frequencies, slowDecay, fastDecay; // Internal variables
        var sig; // UGens

        freq = \freq.kr(164.81) + \detune.kr(0); // E3 + constant detuning for this string
        decay = \decay.kr(1);
        duration = \duration.kr(1);
        out = \out.ir(0);
        amplitudes = \amplitudes.kr((0.1).dup(12));
        pan = \pan.kr(0);
        overtones = \overtones.kr((1..12));
        trigger = \trigger.tr(0);

        frequencies = freq * overtones * (LFNoise2.kr(1.0 * overtones) * (0.033 * overtones)).midiratio;
        slowDecay = (frequencies.squared * (decay * 1.0 * 10e-7) * -1).exp * 2; // Quadratic damping
        fastDecay = (frequencies.squared * (decay * 4.0 * 10e-7) * -1).exp * 2; // Quadratic damping

        sig = DynKlank.ar(`[frequencies, amplitudes, slowDecay], K2A.ar(trigger) * 0.015, decayscale: duration);
        sig = sig.blend(DynKlank.ar(`[frequencies, amplitudes, fastDecay], K2A.ar(trigger) * 0.015, decayscale: duration), 0.33);
        sig = (sig * 2).tanh * 0.75;
        sig = sig.blend(PartConv.ar(sig, ~fftsize, ~irspectrum.bufnum, 0.3), 0.2);
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var sig;
        sig = In.ar(\out.kr(0), 2);
        sig = sig + (NHHall.ar(sig, 1) * -6.dbamp);
        sig = Limiter.ar(sig);
        ReplaceOut.ar(\out.kr(0), sig);
    }).add;
});

~naiveFFT = {
    |points, count|
    count.collect{
        |i|
        var real, imag;
        real = 0;
        imag = 0;
        points.do {
            |v, j|
            var angle = 2 * pi * i * (j.asFloat / points.size);
            real = real + (v * cos(angle));
            imag = imag - (v * sin(angle));
        };
        (real.squared + imag.squared).sqrt;
    }
};

~getPoints = {
    |pos, count=100|
    var ipos = (pos * count).asInteger;
    count.collect({|i| if(i<ipos, i.asFloat/ipos, (count-i).asFloat / (count-ipos)) });
};
)

(
var scale, root, index, synths, lastDegree;
scale = Scale.lydian.semitones;
root = 52;
index = 0;

s.bind {
    synths = [
        Synth(\guitarString, [decay: 0.2]),
        Synth(\guitarString, [decay: 0.3]),
    ];

    Synth.tail(s, \fx);
};

lastDegree = [rrand(-4, 12), rrand(-4, 12)];
Routine { loop {
    var time = [0.5, 1,2,3,4].wchoose([1, 1, 3, 2, 1.5].normalizeSum) * 0.5;
    var amp = rrand(0.33, 0.9) * 1;
    var pos = rrand(0.6, 0.8);
    var duration = rrand(1.0, 1.5) * time.max(1.0) * 3;
    var pointCount = 100;
    var amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
    var next = (lastDegree[index] + [-2, -1, 0, 1, 2].choose).clip(-4, 12);
    var note = scale.performDegreeToKey(next) + root;
    s.bind {
        synths[index].set(
            \freq, note.midicps,
            \amplitudes, amplitudes.drop(1),
            \duration, duration,
            \pan, (index * 2.0 - 1) * 0.33,
            \trigger, 1,
        );
    };
    lastDegree[index] = next;
    index = 1 - index;
    time.yield;
}}.play;
)