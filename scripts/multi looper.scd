(
~morphOffsetLookup = (0..3).collect {|i|
    {|x| (i/(3*x+1)).clip(0, 1) }
};

SynthDef(\multilooper, {
    var morph = \morph.kr(0);
    var bufnum = \bufnum.ir(0);
    var start = \start.ir(0);
    var end = \end.ir(100000);
    var amp = \amp.kr(-12.dbamp);
    var out = \out.ir(0);
    var recBufNum = \recBufNum.ir(0);

    var frames = BufFrames.ir(bufnum);
    var triggers = LocalIn.ar(4);
    var shMorph = Latch.kr(morph, triggers[0]);


    var geneStatus = SetResetFF.ar(triggers * [1, morph>0, morph>1/3, morph>2/3], [0, morph<=0, morph<=1/3, morph<=2/3]);

    var geneAmp = [1,
        morph.linlin(0, 0.05, 0, 1),
        morph.linlin(1/3, 1/3+0.05, 0, 1),
        morph.linlin(2/3, 2/3+0.05, 0, 1)
    ] * geneStatus;

    // On the morphagene panning occurs in a dead zone between 3rd and 4th gene overlap, here it happens after the 4th gene is introduced
    var panningVariation = morph.linlin(4/6,5/6,0,1);
    var pitchUpVariation = morph.linlin(5/6,6/6,0,1);
    var useReverse = morph>=0.99;

    var shStart = Latch.kr(start, triggers[0]);
    var shEnd = Latch.kr(end, triggers[0]);
    var offsets = ~morphOffsetLookup.collect { |func| func.(shMorph) } * (shEnd-shStart);
    var phasors = Phasor.ar(triggers, BufRateScale.kr(bufnum), 0, frames, shStart);

    var sigs = BufRd.ar(2, bufnum, phasors);
    sigs = (sigs * geneAmp).sum * amp;

    LocalOut.ar(((phasors[0]<(shStart+offsets))+(phasors[0]>(shEnd+offsets))));
    RecordBuf.ar(phasors[0..1].linlin(0,frames,0,1) ++ Trig.ar(triggers[0..1], 0.01), recBufNum, loop: 0, doneAction: Done.freeSelf);
    // Out.ar(out, sigs!2);
}).add;
)


(s.waitForBoot({
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/recordings/SC_230904_105002.wav";
    var splices, crossfadeDuration, buf, recBuf, synth;

    s.freeAll;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    buf = Buffer.read(s, bufferContentPath, 0, 1.1 * 48000);
    ~recBuf = Buffer.alloc(s, 3.5 * s.sampleRate, 4);
    s.sync;

    fork {
        s.bind { Synth(\multilooper, [bufnum: buf, recBufNum: ~recBuf, end: buf.sampleRate * 1, morph: 0.15]) };
        3.wait;
        'Done'.postln;
    }
}))

~recBuf.plot;