(
CmdPeriod.run;
s.waitForBoot {
    var looperCount, looperBuffers, inGroup, looperGroup, fxGroup, delayBuf;
    var replyName = '/trigger';
    var root = 36;
    var notes = [0, 12, 19, 24, 28, 31, 38, 48 ]; // Add9
    var freqs = [8, 4, 2, 2, 1, 1, 1, 1].reciprocal;
    looperCount = 8; // Original patch value was 4
    Buffer.freeAll;
    s.sync;

    looperBuffers = looperCount.collect { Buffer.alloc(s, 16 * s.sampleRate) };
    inGroup = Group.new;
    looperGroup = Group.after(inGroup);
    fxGroup = Group.after(looperGroup);
    delayBuf = Buffer.alloc(s, s.sampleRate * 2, 2);
    s.sync;

    SynthDef(\triggerer, {
        var rate = \freq.kr(1) / SampleRate.ir;
        var phasor = Phasor.ar(rate: rate) + \phase.kr(0) % 1;
        SendReply.ar(phasor - rate, replyName, [\id.ir(0)]);
    }).add;

    SynthDef(\pulse, {
        var sig = Pulse.ar(\freq.kr(440) * LFNoise2.kr(3!5).bipolar(0.01).midiratio * SinOsc.kr(Rand(3.0, 4.5)).bipolar(0.01).midiratio, \width.kr(0.5).clip(0, 1));
        sig = MoogFF.ar(sig, \cf.kr(20000).clip(20, 20000));
        sig = sig * Env.perc(\atk.kr(0.01), \rel.kr(1)).ar(Done.freeSelf, timeScale: \dur.kr(1));
        sig = Splay.ar(sig, 0.5, center: \pan.kr(0).clip(-1, 1));
        sig = sig * \amp.kr(0.5) * SinOsc.ar(Rand(3.0, 4.5)).range(0.8, 1);
        Out.ar(\out.ir(0), sig);
    }).add;

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

        var input = In.ar(in);
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

    SynthDef(\fx, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var sndIn = \sndIn.ir(0);

        var phasor = Phasor.ar(rate: BufRateScale.ir(buf), end: BufFrames.ir(buf));
        var tapeWobble = LFNoise2.ar(2!2).lincurve(-1, 1, 0, BufSampleRate.ir(buf) * 0.004, 10);
        var tapeDelay = BufRd.ar(2, buf, (phasor + tapeWobble).wrap(0, BufFrames.ir(buf)), interpolation: 4);
        var sig = In.ar(in, 2).blend(tapeDelay, 0.5);
        var rev = NHHall.ar(sig, 4, 0.15);

        // Back to tape delay with some hiss, crackles and saturation
        var tapeCrackle = BPF.ar(PinkNoise.ar(1!2) * WhiteNoise.ar(1!2), 2000, 0.75) * LFNoise2.kr(0.5!2).linlin(-1, 1, -24.dbamp, -12.dbamp);
        var tapeHiss = BPF.ar(PinkNoise.ar(1!2), LFNoise1.kr(2.3587!2).linlin(-1, 1, 2000, 4000), 0.95);
        sig = sig.blend(tapeHiss, 0.05) + tapeCrackle;
        sig = sig.tanh;
        RecordBuf.ar(LPF.ar(HPF.ar(sig, 50), 10000), buf, recLevel: 1, preLevel: -36.dbamp);

        sig = sig.blend(rev, 0.5);
        sig = Compander.ar(sig, sig, 0.4, 1, 5.reciprocal, 0.005, 0.5);
        ReplaceOut.ar(out, sig);
    }).add;
    s.sync;

    OSCFunc({|msg|
        var index = msg[3].asInteger;
        s.bind { Synth(\pulse, [freq: (root + notes[index]).midicps, atk: rrand(1.0, 5.0), rel: (index+1).reciprocal*rrand(10.0, 20.0), cf: exprand(200, 2000), amp: (index/8+1).reciprocal, pan: rrand(-1.0, 1.0), width: exprand(0.5, 0.95)], inGroup) };
    }, replyName);

    s.bind { notes.do { |note, i|
        Synth(\triggerer, [freq: (freqs[i] + rrand(-0.01, 0.01)) * 0.03, id: i, phase: exprand(0.001, 1.0)]);
    }};

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
        ], looperGroup);
    };
    Synth.tail(fxGroup, \fx, [out: 0, buf: delayBuf]);

    /*AppClock.sched(0, {
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
    });*/
};
)