({
    var in, freq, trig, sig, out;
    in = LocalIn.ar(2);
    trig = Impulse.kr(4/7);
    freq = TChoose.kr(trig, ([12, 17, 24, 28] + 12).midicps).lag(0.1); // 1st, 4th, 8th, 10th
    sig = Saw.ar(freq + [-1, 1]);
    sig = (in * 5 + sig).tanh;
    sig = BPF.ar(sig, (2.5**LFNoise0.kr(2, 4)) * 200 + 100, 0.1) * 1;
    sig = CombC.ar(sig, 2, 2 + (LFNoise0.ar(1) * 0.0025).lag(TExpRand.kr(0.01, 1.0, trig)), 20); // Simple delay
    out = Clip.ar(sig, -1, 1) * -6.dbamp;
    LocalOut.ar(out);
    out;
}.play)