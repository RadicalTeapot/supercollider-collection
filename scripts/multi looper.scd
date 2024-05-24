(
~morphOffsetLookup = (1..3).collect {|i|
    {|x| (i/(3*x+1)).clip(0, 1) }
};

SynthDef(\multilooper, {
    // TODO Test adding crossfade to get rid of clicks (see continous looper 7)
    var morph = \morph.kr(0);
    var bufnum = \bufnum.ir(0);
    var start = \start.ir(0);
    var end = \end.ir(100000);
    var amp = \amp.kr(-12.dbamp);
    var out = \out.ir(0);
    var recBufNum = \recBufNum.ir(0);

    var frames = BufFrames.ir(bufnum);
    var triggers = LocalIn.ar(4);
    var trigger = triggers[0];
    var shMorph = Latch.kr(morph, trigger);

    var activations = [-1,0,1/3,2/3];
    var geneStatus = SetResetFF.ar((shMorph>activations) * triggers, shMorph<=activations);
    var geneAmp = geneStatus.lag(0.05);

    // On the morphagene panning occurs in a dead zone between 3rd and 4th gene overlap, here it happens after the 4th gene is introduced
    var panningVariation = morph.linlin(4/6,5/6,0,1);
    var pitchUpVariation = morph.linlin(5/6,6/6,0,1);
    var useReverse = morph>=0.99;

    var shStart = Latch.kr(start, trigger);
    var shEnd = Latch.kr(end, trigger);
    var rate = BufRateScale.kr(bufnum);
    var phasor = Phasor.ar(trigger, rate, 0, frames, start);

    var offsets = ~morphOffsetLookup.collect { |func| func.(shMorph) }.linlin(0,1,shStart,shEnd);
    var geneTriggers = phasor>offsets;
    var genePhasors = Phasor.ar(geneTriggers, rate, 0, frames, start);

    var sigs = BufRd.ar(2, bufnum, [phasor] ++ genePhasors);
    sigs = (sigs * geneAmp).sum * amp;

    LocalOut.ar([(phasor<shStart)+(phasor>shEnd)] ++ (Changed.ar(geneTriggers) * geneTriggers));
    // RecordBuf.ar([phasor] ++ genePhasors ++ (Trig.ar(triggers, 0.01) * frames * 0.01), recBufNum, loop: 0, doneAction: Done.freeSelf);
    Out.ar(out, sigs!2);
}).add;

SynthDef(\crossfadeMultilooper, {
    var morph = \morph.kr(0);
    var bufnum = \bufnum.ir(0);
    var start = \start.ir(0);
    var end = \end.ir(100000);
    var amp = \amp.kr(-12.dbamp);
    var out = \out.ir(0);
    var recBufNum = \recBufNum.ir(0);
    var crossfadeDuration = \crossfadeDuration.kr(0.05);
    var geneAmpLag = \geneAmpLag.kr(0.05);

    var frames = BufFrames.ir(bufnum);
    var triggers = LocalIn.ar(4);
    var toggles = ToggleFF.ar(triggers);
    var toggleSets = toggles.collect {|v| [v, 1-v] };
    var trigger = triggers[0];
    var toggleSet = toggleSets[0];
    var shMorph = Latch.kr(morph, toggleSet);

    var activations = [-1,0,1/3,2/3];
    var geneStatus = SetResetFF.ar((shMorph>activations) * triggers, shMorph<=activations);
    var geneAmp = geneStatus.lag(geneAmpLag);

    // On the morphagene panning occurs in a dead zone between 3rd and 4th gene overlap, here it happens after the 4th gene is introduced
    var panningVariation = morph.linlin(4/6,5/6,0,1);
    var pitchUpVariation = morph.linlin(5/6,6/6,0,1);
    var useReverse = morph>=0.99;

    var crossfadeSamples = crossfadeDuration * BufSampleRate.kr(buf);

    var shStart = Latch.kr(start, toggleSet);
    var shEnd = Latch.kr(end, toggleSet);
    var rate = BufRateScale.kr(bufnum);
    var phasor = Phasor.ar(toggleSet, rate, 0, frames, start);

    var offsets = ~morphOffsetLookup.collect { |func| func.(shMorph) }.linlin(0,1,shStart,shEnd);
    var geneTriggers = (phasor * toggleSet).sum>offsets;
    var genePhasors = Phasor.ar(geneTriggers, rate, 0, frames, start);

    var sigs = BufRd.ar(2, bufnum, [phasor] ++ genePhasors);
    sigs = (sigs * geneAmp).sum * amp;

    LocalOut.ar([(phasor<shStart)+(phasor>shEnd)] ++ (Changed.ar(geneTriggers) * geneTriggers));
    // RecordBuf.ar([phasor] ++ genePhasors ++ (Trig.ar(triggers, 0.01) * frames * 0.01), recBufNum, loop: 0, doneAction: Done.freeSelf);
    Out.ar(out, sigs!2);
}).add;
)


(s.waitForBoot({
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/400820__makenoisemusic__mylarpianoouttakes.wav";
    var splices, crossfadeDuration, buf, recBuf, recBufDuration, synth;

    s.freeAll;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    buf = Buffer.read(s, bufferContentPath);
    // recBufDuration = 3.5;
    // recBuf = Buffer.alloc(s, recBufDuration * s.sampleRate, 8);
    s.sync;

    ~synth = Synth(\multilooper, [bufnum: buf, end: buf.sampleRate * 1, morph: 0, start: 10 * buf.sampleRate, end: 12 * buf.sampleRate]);

    /*fork {
        s.bind { ~synth = Synth(\multilooper, [bufnum: buf, recBufNum: recBuf, end: buf.sampleRate * 1, morph: 0]) };
        1.wait;
        s.bind { ~synth.set(\morph, 1) };
        recBufDuration.wait;
        { recBuf.plot(bounds: Rect(100,100,1500,900)) }.defer;
    }*/
}))

~synth.set(\morph, 0.15)