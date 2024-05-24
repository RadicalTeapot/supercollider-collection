({
    var lfo, sig, out;
    lfo = SinOsc.ar([0.101, 0.099]).range(1, 10);
    sig = SinOsc.ar(40 + [SinOsc.ar(0.099).range(-0.2, -0.1), SinOsc.ar(0.101).range(0.1, 0.2)]);
    sig = MoogFF.ar((sig * lfo).tanh, SinOsc.ar([0.101, 0.099]).range(-0.1, 0.1) + 80, 12);
    sig = (sig * lfo).distort;
    out = Clip.ar(sig, -1, 1) * -6.dbamp;
    out;
}.play)