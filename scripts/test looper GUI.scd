(
s.waitForBoot {
    var count = 16;
    SynthDef(\varLooperUI, {
        var id = \id.ir(0);
        var bufDuration = \bufDuration.kr(16);
        var minAmp = \minAmp.kr(-60.dbamp);
        var maxAmp = \maxAmp.kr(-6.dbamp);
        var ampLfoFreq = \ampLfoFreq.kr(0.1);
        var recLfoFreq = \recLfoFreq.kr(0.1);
        var reverseLfoFreq = \reverseLfoFreq.kr(0.1);
        var posLfoFreq = \posLfoFreq.kr(0.1);
        var panLfoFreq = \panLfoFreq.kr(0.1);
        var posLfoFeedback = \posLfoFeedback.kr(0);
        var readPhasorSpeedsBuf = LocalBuf.newFrom(\readPhasorSpeed.ir([0.25, 4, 0.5, 2, 1]));
        var readPhasorSpeedLfoFreq = \readPhasorSpeedLfoFreq.kr(0.1);
        var refreshRate = \refreshRate.kr(30);
        var fadeTime = \fadeTime.kr(0.02);

        var localIn = LocalIn.ar(2);
        var feedback = localIn[0];
        var phasorFeedback = localIn[1];

        var startPosLfo = SinOsc.kr(posLfoFreq + feedback * posLfoFeedback);
        var reverseLfo = LFPulse.kr(reverseLfoFreq).lag(0.05).linlin(0, 1, -1, 1);
        var panLfo = SinOsc.kr(panLfoFreq);
        var readPhasorSpeedLfo = LFSaw.kr(readPhasorSpeedLfoFreq);
        var ampLfo = VarSaw.kr(ampLfoFreq).unipolar.lincurve(0, 1, minAmp, maxAmp).clip(0, 1);

        var recTrig = Impulse.ar(recLfoFreq);
        var gateDuration = SinOsc.ar(37.273).range(4 * fadeTime, bufDuration.min((2*recLfoFreq).reciprocal));
        var recGate = Trig1.ar(recTrig, gateDuration);
        var readGate = 1 - recGate;

        var bufRateScale = 1;
        var bufFrames = K2A.ar(bufDuration * SampleRate.ir);
        var lastFrame = Latch.ar(phasorFeedback, readGate);
        var loopPoint = Select.ar((lastFrame > 0) * readGate, [bufFrames, lastFrame]);

        var readSpeedBufIndex = Latch.kr(readPhasorSpeedLfo.unipolar.lincurve * BufFrames.ir(readPhasorSpeedsBuf), readGate);
        var readPhasorSpeed = Index.ar(readPhasorSpeedsBuf, readSpeedBufIndex);
        var startPos = Latch.kr(startPosLfo.unipolar(loopPoint * 0.95), readGate);

        var recPhasor = Phasor.ar(Changed.ar(recGate), rate: bufRateScale, end: loopPoint, resetPos: -1);
        var readPhasor = Phasor.ar(Changed.ar(readGate), bufRateScale * reverseLfo * readPhasorSpeed, end: loopPoint, resetPos: startPos);

        var amp = ampLfo * (readPhasorSpeed*2+1).sqrt.reciprocal * readGate.lag(fadeTime);

        LocalOut.ar([K2A.ar(startPosLfo), recPhasor]);
        SendReply.kr(Impulse.kr(refreshRate), '/update', [id, recGate, loopPoint / bufFrames, readPhasor / bufFrames, recPhasor / bufFrames, amp, panLfo.unipolar]);
    }).add;
    s.sync;

    count.do{|i|
        var recLfoFreq = exprand(0.01, 0.2);
        var reverseLfoFreq = exprand(0.08, 0.2);
        var startPosLfoFreq = exprand(0.1, 0.3);
        var posLfoFeedback = (0.1).coin;
        var panLfoFreq = exprand(0.1, 0.3);
        var phasorSpeedLfoFreq = exprand(0.1, 0.75);
        var ampLfoFreq = exprand(0.03, 0.2);
        Synth(\varLooperUI, [
            id: i,
            recLfoFreq: recLfoFreq,
            reverseLfoFreq: reverseLfoFreq,
            posLfoFreq: startPosLfoFreq,
            posLfoFeedback: posLfoFeedback,
            panLfoFreq: panLfoFreq,
            readPhasorSpeedLfoFreq: phasorSpeedLfoFreq,
            ampLfoFreq: ampLfoFreq,
        ])
    };

    AppClock.sched(0, {
        var
        recGates = Array.fill(count, 0),
        normalizedLoopPoints = Array.fill(count, 0),
        readPositions = Array.fill(count, 0),
        recPositions = Array.fill(count, 0),
        amps = Array.fill(count, 0),
        pans = Array.fill(count, 0);

        var bounds = Rect(500, 500, 500, 500);
        var window = Window(bounds: bounds)
        .alwaysOnTop_(true)
        .onClose_({CmdPeriod.run})
        .front
        .background_(Color.white)
        .drawFunc_({
            count.do { |i|
                var width = bounds.width;
                var height = bounds.height / count;
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
                    var size = (amps[i]*10+1);
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