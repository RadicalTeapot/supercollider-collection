({
    var in, bpf, saw, freq, bpfFreq, comb, trigA, trigB, out;
    trigA = Impulse.kr(1/7);
    trigB = Impulse.kr(9/7);
    in = LocalIn.ar(2); // Feedback
    freq = TChoose.kr(trigA, [30, 40, 60, 80]);
    saw = Saw.ar(freq + [-1, 1]);
    bpfFreq = ((2**(LFNoise0.kr(4/3) * 4))*300).lag(0.01);
    bpf = BPF.ar(in * 7.5 + saw * 0.2, bpfFreq, 0.1);
    comb = CombC.ar(bpf.tanh, 4, TChoose.kr(trigA, [1,2,4]), 5);
    LocalOut.ar(comb); // Feedback
    out = comb;
    out;
}.play)