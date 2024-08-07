(
s.waitForBoot {
    var looperCount, looperBuffers, looperBuses, mixOutBus, delayBuf;
    // var recLfoFreqs, reverseLfoFreqs, panLfoFreqs, startPosLfoFreqs, phasorSpeedLfoFreqs, mixValues;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    looperCount = 16; // Original patch value was 4
    looperBuffers = looperCount.collect { Buffer.alloc(s, 16 * s.sampleRate) };
    delayBuf = Buffer.alloc(s, s.sampleRate, 2);
    looperBuses = looperCount.collect { Bus.audio(s, 2) };
    mixOutBus = Bus.audio(s, 2);
    s.sync;

    // Could use SynthDef.wrap to break this down into smaller SynthDefs (i.e. one responsible for recording and one for playing)
    SynthDef(\varLooper, {
        var sig;

        var id = \id.ir(0);
        var refreshRate = \refreshRate.kr(30);

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
        var posLfoFeedback = \posLfoFeedback.kr(0);
        var readPhasorSpeedsBuf = LocalBuf.newFrom(\readPhasorSpeed.ir([0.25, 4, 0.5, 2, 1])); // Curved LFO favors higher indices
        var readPhasorSpeedLfoFreq = \readPhasorSpeedLfoFreq.kr(0.1);
        var recGateDurationLfoFreq = \recGateDurationLfoFreq.kr(10);
        var fadeTime = \fadeTime.kr(0.02);

        var input = SoundIn.ar(in);
        var localIn = LocalIn.ar(2);
        var feedback = localIn[0];
        var phasorFeedback = localIn[1];

        var bufDur = BufDur.kr(buf);
        var bufRateScale = BufRateScale.kr(buf);
        var bufFrames = K2A.ar(BufFrames.kr(buf));

        var startPosLfo = SinOsc.kr(posLfoFreq + feedback * posLfoFeedback);
        var reverseLfo = LFPulse.kr(reverseLfoFreq).lag(0.05).linlin(0, 1, -1, 1);
        var panLfo = SinOsc.kr(panLfoFreq);
        var readPhasorSpeedLfo = LFSaw.kr(readPhasorSpeedLfoFreq);
        var ampLfo = VarSaw.kr(ampLfoFreq).unipolar.lincurve(0, 1, minAmp, maxAmp).clip(0, 1);

        var recTrig = Impulse.ar(recLfoFreq);
        var gateDuration = SinOsc.ar(recGateDurationLfoFreq).range(4 * fadeTime, bufDur.min((2*recLfoFreq).reciprocal)); // 16 is buf duration
        var recGate = Trig1.ar(recTrig, gateDuration); // Get duration is held until the next trigger so we can use a sine here
        var readGate = 1 - recGate;

        var lastFrame = Latch.ar(phasorFeedback, readGate);
        var loopPoint = Select.ar((lastFrame > 0) * readGate, [bufFrames, lastFrame]);

        var readSpeedBufIndex = Latch.kr(readPhasorSpeedLfo.unipolar.lincurve * BufFrames.ir(readPhasorSpeedsBuf), readGate);
        var readPhasorSpeed = Index.ar(readPhasorSpeedsBuf, readSpeedBufIndex);
        var startPos = Latch.kr(startPosLfo.unipolar(loopPoint * 0.95), readGate);

        var readPhasor = Phasor.ar(Changed.ar(readGate), bufRateScale * reverseLfo * readPhasorSpeed, end: loopPoint, resetPos: startPos);
        var recPhasor = Phasor.ar(Changed.ar(recGate), rate: bufRateScale, end: loopPoint, resetPos: -1);

        var amp = ampLfo * (readPhasorSpeed*2+1).sqrt.reciprocal * readGate.lag(fadeTime);

        var prevSig = BufRd.ar(1, buf, recPhasor) * readGate;
        var recSig = SelectX.ar(recGate.slew(fadeTime.reciprocal, fadeTime.reciprocal), [prevSig, input]);
        BufWr.ar(recSig, buf, recPhasor);

        sig = BufRd.ar(1, buf, readPhasor, interpolation: 4) * amp;
        sig = Pan2.ar(sig, panLfo);

        LocalOut.ar([K2A.ar(startPosLfo), recPhasor]);
        SendReply.kr(Impulse.kr(refreshRate), '/update', [id, recGate, loopPoint / bufFrames, readPhasor / bufFrames, recPhasor / bufFrames, amp, panLfo.unipolar]);
        Out.ar(out, sig);
    }).add;

    SynthDef(\mixer, {
        var inputs = \inputs.ir(Array.series(looperCount));
        var out = \out.ir(0);
        var sig = Mix(inputs.collect({ |v| In.ar(v, 2) }));
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

    // Original patch values
    // recLfoFreqs = [0.02, 0.04, 0.04, 0.13].linexp(0, 1, 0.05, 20000); // Remap from 0 to 1 to ZOIA LFO freq values (double check if that matches)
    // startPosLfoFreqs = [0.05, 0.05, 0.02, 0.03].linexp(0, 1, 0.05, 20000);
    // reverseLfoFreqs = [0.03, 0.06, 0.06, 0.07].linexp(0, 1, 0.05, 20000);
    // panLfoFreqs = [0.06, 0.12, 0.1, 0.11].linexp(0, 1, 0.05, 20000);
    // mixValues = [0.53, 0.54, 0.27, 0.29];
    // phasorSpeedLfoFreqs = [0.05, 0.066, 0.08, 0.13].linexp(0, 1, 0.05, 20000);
    looperCount.do {|i|
        var recLfoFreq = exprand(0.01, 0.2);
        var reverseLfoFreq = exprand(0.08, 0.2);
        var startPosLfoFreq = exprand(0.1, 0.3);
        var posLfoFeedback = (0.1).coin;
        var panLfoFreq = exprand(0.1, 0.3);
        var phasorSpeedLfoFreq = exprand(0.1, 0.75);
        var ampLfoFreq = exprand(0.03, 0.2);

        Synth(\varLooper, [
            id: i,
            in: i%2, // 2 loopers for left channel and 2 for right channel
            out: looperBuses[i],
            buf: looperBuffers[i],
            recLfoFreq: recLfoFreq,
            reverseLfoFreq: reverseLfoFreq,
            posLfoFreq: startPosLfoFreq,
            posLfoFeedback: posLfoFeedback, //if (i==0) {100} {0},
            panLfoFreq: panLfoFreq,
            readPhasorSpeedLfoFreq: phasorSpeedLfoFreq,
            ampLfoFreq: ampLfoFreq,
            maxAmp: 0.dbamp,
            minAmp: -18.dbamp,
        ]);
    };
    Synth.tail(s, \mixer, [inputs: looperBuses, out: mixOutBus]);
    Synth.tail(s, \fx, [in: mixOutBus, out: 0, buf: delayBuf]);

    AppClock.sched(0, {
        var
        recGates = Array.fill(looperCount, 0),
        normalizedLoopPoints = Array.fill(looperCount, 0),
        readPositions = Array.fill(looperCount, 0),
        recPositions = Array.fill(looperCount, 0),
        amps = Array.fill(looperCount, 0),
        pans = Array.fill(looperCount, 0);

        var bounds = Rect(500, 500, 500, 500);
        var window = Window(bounds: bounds)
        .alwaysOnTop_(true)
        .onClose_({CmdPeriod.run})
        .front
        .background_(Color.white)
        .drawFunc_({
            looperCount.do { |i|
                var width = bounds.width;
                var height = bounds.height / looperCount;
                var y = height * i;
                Pen.width = 2;
                Pen.strokeColor = Color.black;
                if (recGates[i].asInteger == 1) {
                    Pen.fillColor = Color(1, 0.66, 0.66); // Light red
                } {
                    Pen.fillColor = Color(0.66, 1, 0.66); // Light green
                };
                Pen.addRect(Rect(2, y+2, (width-4) * normalizedLoopPoints[i], height-4));
                Pen.fillStroke;

                if (recGates[i].asInteger == 0) {
                    var x = readPositions[i] * width;
                    var size = (amps[i]*5+1);
                    Pen.width = size;
                    Pen.strokeColor = Color(0, 0.5, 0);
                    Pen.moveTo(x@(y+3));
                    Pen.lineTo(x@(y+height-3));
                    Pen.stroke;
                    Pen.strokeColor = Color.black;
                    Pen.fillColor = Color.black;
                    Pen.addArc(x@(y+(pans[i]*(height-20)+10)), size, 0, 2pi);
                    Pen.fillStroke;
                } {
                    var x = recPositions[i] * width;
                    Pen.width = 2;
                    Pen.strokeColor = Color(0.5, 0, 0);
                    Pen.moveTo(x@(y+3));
                    Pen.lineTo(x@(y+height-3));
                    Pen.stroke;
                };
            }
        });

        OSCFunc({ |msg|
            var i = msg[3].asInteger;
            [recGates, normalizedLoopPoints, readPositions, recPositions, amps, pans].do { |v, j|
                v[i] = msg[4+j];
            };
            defer { window.refresh };
        }, '/update');
    });
};
)