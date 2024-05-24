(
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

SynthDef(\guitar, {
    var
    note, decay, out, amplitudes, // Input variables
    overtones, fastDecay, slowDecay, freqDecayRate, freqDecay, // Internal variables
    sig, fastEnvs, slowEnvs; // UGens

    note = \note.kr(60);
    decay = \decay.kr(1);
    out = \out.ir(0);
    amplitudes = \amplitudes.kr((0.1).dup(12));

    overtones = amplitudes.size;
    fastDecay = 0.25 * decay;
    slowDecay = 1.0 * decay;
    freqDecayRate = -1.2;
    freqDecay = (1-((1..overtones) * freqDecayRate).exp).reciprocal; // Slower decay for lower harmonics

    sig = SinOsc.ar(note.midicps * (1..(overtones)));
    fastEnvs = Env.perc(releaseTime: fastDecay * freqDecay).ar(Done.none) * 0.66;
    slowEnvs = Env.perc(releaseTime: slowDecay * freqDecay).ar(Done.none) * 0.33;
    sig = sig * amplitudes * (fastEnvs + slowEnvs);
    sig = Clip.ar(sig.sum.dup, -1.0, 1.0) * -6.dbamp;
    Env.perc(releaseTime: slowDecay * 1.5).kr(Done.freeSelf);
    Out.ar(out, sig);
}).add;

Routine { loop {
    var time, note, amp, pos, decay, pointCount, amplitudes;
    time = rrand(0.2, 1.5);
    note = ([36, 48, 60] +.x Scale.minorPentatonic.semitones).choose;
    amp = rrand(0.33, 0.9);
    pos = rrand(0.55, 0.95);
    decay = rrand(1.0, 1.5) * time.max(1.0) * 2;
    pointCount = 100;
    amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 12) / pointCount;
    Synth(\guitar, [note: note, amplitudes: amplitudes, decay: decay]);
    time.yield;
}}.play;
)