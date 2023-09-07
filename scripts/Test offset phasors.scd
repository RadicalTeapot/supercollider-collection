(SynthDef(\phasorWithOffsetTriggers, {
    var recBufNum = \recBufNum.ir(0);
    var frames = BufFrames.ir(recBufNum);
    var offset = \offset.kr(0.1);

    var endOfPhasor = LocalIn.ar(1);
    var inputStart = \start.ar(0);
    var start = Latch.ar(inputStart, endOfPhasor);
    var end = Latch.ar(\end.ar(1000), endOfPhasor);

    // Don't use the latched start value otherwise it won't work (it would use the previous latched value instead
    var phasor = Phasor.ar(endOfPhasor, 1, 0, frames, inputStart);

    var remapped = phasor.linlin(start, end, 0, 1);
    var offsetTriggers = 4.collect {|v| remapped>((v+1)*offset)};

    LocalOut.ar((phasor < start) + (phasor > end));

    offsetTriggers = (Changed.ar(offsetTriggers) * offsetTriggers).sum * 0.25;
    frames = frames * 0.2;
    RecordBuf.ar([phasor, Trig.ar(endOfPhasor + offsetTriggers, 0.002) * frames, K2A.ar(start), K2A.ar(end)], recBufNum, loop: 0, doneAction: Done.freeSelf);
}).add;
)

(s.waitForBoot({
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    ~duration = 1;
    ~recBuf = Buffer.alloc(s, s.sampleRate * ~duration, 4);
    s.sync;

    Routine.run({
        s.bind { ~synth = Synth(\phasorWithOffsetTriggers, [recBufNum: ~recBuf]); };
        10.do {
            s.bind { ~synth.set(\start, rrand(0, ~duration * 0.08) * s.sampleRate, \end, rrand(~duration * 0.12, ~duration * 0.2) * s.sampleRate) };
            (~duration * 0.1).wait;
        };
        { ~recBuf.plot(bounds: Rect(100, 100, 1500, 1000)) }.defer;
    })
}))