({
    var count, pos, freq, tones, amps, fftamps, decay, dur, envs, sig;
    freq = 60.midicps;
    tones = (1..12) * freq;
    count = 64;
    pos = rrand(count / 10.0, 9.0 * count / 10.0).asInteger;
    amps = (((0..(pos-1)) / pos.asFloat) ++ (((count-pos-1)..0) / (count-pos).asFloat)).normalizeSum;
    fftamps = tones.collect{
        |v, i|
        var resonance = 0;
        amps.do { |w, j|
            var angle = 2 * pi * (j/count) * (v/freq);
            resonance = resonance + w * (sin(angle) * -1);
        };
        resonance;
    };
    decay = 3;
    dur = tones.collect {|v, i| 1.0/((i/3.0)+1)} * decay;
    envs = Env.perc(0.01, dur).kr(Done.none);
    sig = SinOsc.ar(tones) * envs * fftamps.max(0);
    sig = Clip.ar(sig.sum, -1, 1) * -6.dbamp;
    Env.perc(0.01, decay).kr(Done.freeSelf);
    sig.dup;
}.play)