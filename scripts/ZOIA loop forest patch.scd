(
s.waitForBoot {
    var looperBuffers, looperBuses, mixOutBus, delayBuf, recLfoFreqs, reverseLfoFreqs, panLfoFreqs, startPosLfoFreqs, phasorSpeedLfoFreqs, mixValues;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    looperBuffers = 4.collect { Buffer.alloc(s, 16 * s.sampleRate) };
    delayBuf = Buffer.alloc(s, s.sampleRate, 2);
    looperBuses = 4.collect { Bus.audio(s, 2) };
    mixOutBus = Bus.audio(s, 2);
    s.sync;

    SynthDef(\looper, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var recLfoFreq = \recLfoFreq.kr(0.1);
        var reverseLfoFreq = \reverseLfoFreq.kr(0.1);
        var posLfoFreq = \posLfoFreq.kr(0.1);
        var panLfoFreq = \panLfoFreq.kr(0.1);
        var posLfoFeedback = \posLfoFeedback.kr(0);
        var readPhasorSpeeds = LocalBuf.newFrom(\readPhasorSpeed.ir([0.25, 4, 0.5, 2, 1])); // Curved LFO favors higher indices
        var readPhasorSpeedLfoFreq = \readPhasorSpeedLfoFreq.kr(0.1);

        var input = SoundIn.ar(in);
        var feedback = LocalIn.kr(1);

        var startPosLfo = SinOsc.kr(posLfoFreq + feedback * posLfoFeedback);
        var reverseLfo = LFPulse.kr(reverseLfoFreq).varlag(0.05).linlin(0, 1, -1, 1); // Small crossfade to avoid clicks
        var panLfo = SinOsc.kr(panLfoFreq);
        var readPhasorSpeedLfo = LFSaw.kr(readPhasorSpeedLfoFreq);
        var recLfo = LFPulse.kr(recLfoFreq).varlag(0.05); // Small crossfade to avoid clicks
        var readLfo = 1 - recLfo;

        var readSpeedBufIndex = Latch.kr(readPhasorSpeedLfo.unipolar.lincurve * BufFrames.ir(readPhasorSpeeds), readLfo);
        var readPhasorSpeed = Index.ar(readPhasorSpeeds, readSpeedBufIndex);
        var readPhasor = Phasor.ar(readLfo, BufRateScale.ir(buf) * reverseLfo * readPhasorSpeed, end: BufFrames.ir(buf));

        var recPhasor = Phasor.ar(rate: BufRateScale.ir(buf), end: BufFrames.ir(buf));
        var sig, prevSig, startPos;
        prevSig = BufRd.ar(1, buf, recPhasor);
        // If recLFO is on, record from input otherwise keep buffer content
        BufWr.ar(SelectX.ar(recLfo, [prevSig, input]), buf, recPhasor);

        startPos = Latch.kr(startPosLfo.unipolar(BufFrames.ir(0) * 0.95), readLfo).wrap(1, BufFrames.ir(buf));
        sig = BufRd.ar(1, buf, readPhasor + startPos, interpolation: 4) * readLfo * (readSpeedBufIndex+1).sqrt.reciprocal * 2; // Lower higher octaves volume

        sig = Pan2.ar(sig, panLfo);

        LocalOut.kr(startPosLfo);
        Out.ar(out, sig);
    }).add;

    SynthDef(\mixer, {
        var inputs = \inputs.ir(#[0,1,2,3]);
        var mixValues = \mixValues.kr([1,1,1,1]);
        var out = \out.ir(0);
        var sig = Mix(inputs.collect({ |v| In.ar(v, 2) }) * mixValues);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var sndIn = \sndIn.ir(0);

        var phasor = Phasor.ar(rate: BufRateScale.ir(buf), end: BufFrames.ir(buf));
        var input = In.ar(in, 2);

        // Read from tape with some wobble
        var tapeWobble = LFNoise2.ar(2!2).lincurve(-1, 1, 0, BufSampleRate.ir(buf) * 0.004, 10);
        // var tapeWobble = SinOsc.ar(0.99).unipolar(0.004) * BufSampleRate.ir(0);
        var tapeDelay = BufRd.ar(2, buf, (phasor + tapeWobble).wrap(0, BufFrames.ir(buf)), interpolation: 4);

        var sig = Mix([input, tapeDelay]) * -6.dbamp;

        // Reverb from "clean" delay sound and input mixed
        var soundIn = SoundIn.ar(sndIn + [0,1]);
        var toRev = Mix([sig, soundIn])  * -6.dbamp;
        var rev = NHHall.ar(toRev, 2, 0.15);

        // Back to tape delay with some hiss, crackles and saturation
        var tapeCrackle = BPF.ar(PinkNoise.ar(1!2) * WhiteNoise.ar(1!2), 2000, 0.75) * LFNoise2.kr(0.5!2).linlin(-1, 1, -46.dbamp, -36.dbamp);
        var tapeHiss = BPF.ar(PinkNoise.ar(1!2), LFNoise1.kr(2.3587!2).linlin(-1, 1, 2000, 4000), 0.95);
        sig = sig.blend(tapeHiss, 0.005) + tapeCrackle;
        sig = sig.tanh;
        RecordBuf.ar(LPF.ar(HPF.ar(sig, 50), 10000), buf, recLevel: 1, preLevel: -12.dbamp);

        sig = toRev.blend(rev, 0.5);
        sig = Compander.ar(sig, sig, 0.4, 1, 5.reciprocal, 0.005, 0.5);
        Out.ar(out, sig);
    }).add;
    s.sync;

    recLfoFreqs = [0.02, 0.04, 0.04, 0.13].linexp(0, 1, 0.05, 20000); // Remap from 0 to 1 to ZOIA LFO freq values (double check if that matches)
    startPosLfoFreqs = [0.05, 0.05, 0.02, 0.03].linexp(0, 1, 0.05, 20000);
    reverseLfoFreqs = [0.03, 0.06, 0.06, 0.07].linexp(0, 1, 0.05, 20000);
    panLfoFreqs = [0.06, 0.12, 0.1, 0.11].linexp(0, 1, 0.05, 20000);
    mixValues = [0.53, 0.54, 0.27, 0.29];
    phasorSpeedLfoFreqs = [0.05, 0.066, 0.13, 0.27].linexp(0, 1, 0.05, 20000);
    4.do {|i| Synth(\looper, [
        in: i%2, // 2 loopers for left channel and 2 for right channel
        out: looperBuses[i],
        buf: looperBuffers[i],
        recLfoFreq: recLfoFreqs[i],
        reverseLfoFreq: reverseLfoFreqs[i],
        posLfoFreq: startPosLfoFreqs[i],
        posLfoFeedback: if (i==0) {100} {0},
        panLfoFreq: panLfoFreqs[i],
        readPhasorSpeedLfoFreq: phasorSpeedLfoFreqs[i],
    ])};
    Synth.tail(s, \mixer, [inputs: looperBuses, mixValues: mixValues, out: mixOutBus]);
    Synth.tail(s, \fx, [in: mixOutBus, out: 0, buf: delayBuf]);
};
)