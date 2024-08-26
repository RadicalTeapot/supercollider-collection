(
s = ~useJACK.(2, 2);
s.waitForBoot {
    // TODO test each recorder

    var looperBuffer, zeroCrossingRecorder, xfadeRecorder, reader, looper, synth;
    Buffer.freeAll;
    s.sync;

    looperBuffer = Buffer.alloc(s, 16 * s.sampleRate);
    s.sync;

    // MONO
    zeroCrossingRecorder = { |in, buf, recGate|
        var input = SoundIn.ar(in);
        var prev = Delay1.ar(input); // Get the signal value for last frame
        var bufFrames = BufFrames.kr(buf);
        var bufRateScale = BufRateScale.kr(buf);

        var refPhasor = Phasor.ar(Changed.ar(recGate), bufRateScale, end: bufFrames);
        // Trigger on zero crossing (i.e. when signal was below and is now above 0 or the opposite)
        var zeroCrossTrigger = ((prev < 0) * (input > 0)) + ((prev > 0) * (input < 0));
        var firstCrossingPos = Latch.ar(refPhasor, SetResetFF.ar(zeroCrossTrigger, recGate));
        var lastCrossingPos = Latch.ar(refPhasor, zeroCrossTrigger * recGate);

        var startPoint = Select.ar(recGate, [firstCrossingPos, K2A.ar(0)]);
        var endPoint = Select.ar(recGate, [lastCrossingPos, bufFrames]);
        var phasor = Phasor.ar(Changed.ar(recGate), BufRateScale.kr(buf), startPoint, endPoint+1);
        var prevSig = BufRd.ar(1, buf, phasor) * (1-recGate);
        var recSig = Select.ar(recGate, [prevSig, input]);
        BufWr.ar(recSig, buf, phasor);
        [startPoint, endPoint];
    };

    // MONO
    xfadeRecorder = { |in, buf, recGate, fadeTime|
        var input = SoundIn.ar(in);

        var phasorFeedback = LocalIn.ar(1);
        var bufFrames = K2A.ar(BufFrames.kr(buf));
        var bufRateScale = BufRateScale.kr(buf);

        var readGate = 1 - recGate;
        var lastFrame = Latch.ar(phasorFeedback, readGate);
        var loopPoint = Select.ar((lastFrame > 0) * readGate, [bufFrames, lastFrame]);

        var recPhasor = Phasor.ar(Changed.ar(recGate), rate: bufRateScale, end: loopPoint, resetPos: -1);
        var prevSig = BufRd.ar(1, buf, recPhasor) * readGate;
        var recSig = SelectX.ar(recGate.slew(fadeTime.reciprocal, fadeTime.reciprocal), [prevSig, input]);
        BufWr.ar(recSig, buf, recPhasor);
        LocalOut.ar(recPhasor);
        [0, loopPoint];
    };

    // MONO
    reader = { |buf, readGate, bounds, reverse, speed, normalizedStartPos|
        var readRate = BufRateScale.kr(buf) * reverse * speed;
        var start = bounds.at(0);
        var end = bounds.at(1);
        var resetPos = normalizedStartPos * (end - start) + start;
        var readPhasor = Phasor.ar(Changed.ar(readGate), readRate, start, end, resetPos);
        BufRd.ar(1, buf, readPhasor, interpolation: 4);
    };

    looper = { |recorder, reader, in, out, buf, amp, speed, fadeTime, reverse, recGate, normalizedStartPos, pan|
        var readGate = 1-recGate;

        var phasorBounds = SynthDef.wrap(recorder, prependArgs: [in, buf, recGate, fadeTime]);
        var sig = SynthDef.wrap(reader, prependArgs: [buf, readGate, phasorBounds, reverse, speed, normalizedStartPos]);

        Pan2.ar(sig * amp * readGate.lag(fadeTime), pan);
    };

    SynthDef(\manualLooper, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var amp = \amp.kr(1);
        var speed = \speed.kr(1).abs;
        var fadeTime = \fadeTime.kr(0.02).max(0.005);
        var reverse = (\reverse.kr(0) <= 0) * 2 - 1;
        var recGate = (\recGate.ar(0) > 0); // Must be audio-rate signal
        var startPos = \startPos.kr(0).clip(0, 1);
        var pan = \pan.kr(0).clip(-1, 1);

        var sig = SynthDef.wrap(
            looper,
            prependArgs: [xfadeRecorder, reader, in, out, buf, amp * (speed*2+1).sqrt.reciprocal, speed, fadeTime, reverse, recGate, startPos, pan]
        );
        Out.ar(out, sig);
    }).add;

    SynthDef(\quantizedLooper, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var amp = \amp.kr(1);
        var speed = \speed.kr(1).abs;
        var fadeTime = \fadeTime.kr(0.02).max(0.005);
        var reverse = (\reverse.kr(0) <= 0) * 2 - 1;
        var recTrigger = \recTrigger.tr(0);
        var startPos = \startPos.kr(0).clip(0, 1);
        var pan = \pan.kr(0).clip(-1, 1);
        var bpm = \bpm.kr(80);
        var clockOffset = \clockOffset.kr(0).clip(0, 1); // in beats
        var duration = \duration.kr(4).max(0.001); // in beats

        var clockFreq = bpm / 60;
        var clock = Impulse.ar(clockFreq, clockOffset);
        var quantizedTrig = 1 - SetResetFF.ar(T2A.ar(recTrigger), clock);
        var gateLength = (clockFreq.reciprocal * duration).clip(2 * fadeTime, BufDur.kr(buf));
        var recGate = Env.linen(0, gateLength, 0).ar(Done.none, quantizedTrig);

        var sig = SynthDef.wrap(
            looper,
            prependArgs: [xfadeRecorder, reader, in, out, buf, amp * (speed*2+1).sqrt.reciprocal, speed, fadeTime, reverse, recGate, startPos, pan]
        );
        XOut.ar(out, 0.5, sig);
    }).add;

    SynthDef(\lfoLooper, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var minAmp = \minAmp.kr(-60.dbamp);
        var maxAmp = \maxAmp.kr(-6.dbamp);
        var ampLfoFreq = \ampLfoFreq.kr(0.1);
        var recLfoFreq = \recLfoFreq.kr(0.1);
        var reverseLfoFreq = \reverseLfoFreq.kr(0.1);
        var posLfoFreq = \posLfoFreq.kr(0.1);
        var panLfoFreq = \panLfoFreq.kr(0.1);
        var readPhasorSpeedsBuf = LocalBuf.newFrom(\readPhasorSpeed.ir([0.25, 4, 0.5, 2, 1]));
        var readPhasorSpeedLfoFreq = \readPhasorSpeedLfoFreq.kr(0.1);
        var recGateDurationLfoFreq = \recGateDurationLfoFreq.kr(10);
        var fadeTime = \fadeTime.kr(0.02);
        var minDuration = \minDuration.kr(0.02).max(2 * fadeTime);

        var startPosLfo = SinOsc.kr(posLfoFreq);
        var reverseLfo = LFPulse.kr(reverseLfoFreq).lag(0.05).linlin(0, 1, -1, 1);
        var panLfo = SinOsc.kr(panLfoFreq);
        var readPhasorSpeedLfo = LFSaw.kr(readPhasorSpeedLfoFreq);
        var ampLfo = VarSaw.kr(ampLfoFreq).unipolar.lincurve(0, 1, minAmp, maxAmp).clip(0, 1);

        var bufDur = BufDur.kr(buf);
        var recTrig = Impulse.ar(recLfoFreq);
        var gateDuration = SinOsc.ar(recGateDurationLfoFreq).range(minDuration, bufDur.min((2*recLfoFreq).reciprocal));
        var recGate = Trig1.ar(recTrig, gateDuration);
        var readGate = 1 - recGate;

        var readSpeedBufIndex = Latch.kr(readPhasorSpeedLfo.unipolar.lincurve * BufFrames.ir(readPhasorSpeedsBuf), readGate);
        var readPhasorSpeed = Index.ar(readPhasorSpeedsBuf, readSpeedBufIndex);
        var amp = ampLfo * (readPhasorSpeed*2+1).sqrt.reciprocal;

        var sig = SynthDef.wrap(
            looper,
            prependArgs: [xfadeRecorder, reader, in, out, buf, amp, readPhasorSpeed, fadeTime, reverseLfo, recGate, startPosLfo, panLfo]
        );
        Out.ar(out, sig);
    }).add;
    s.sync;

    // Synth(\lfoLooper, [in: 0, buf: looperBuffer, maxAmp: 0.dbamp, minAmp: -18.dbamp, minDuration: 0.5,]);
    // synth = Synth(\manualLooper, [in: 0, buf: looperBuffer]);
    // s.sync;

    /*fork { inf.do {
        s.bind { synth.set(\recGate, 1) };
        1.yield;
        s.bind { synth.set(\recGate, 0) };
        4.yield;
    }}*/
};
)