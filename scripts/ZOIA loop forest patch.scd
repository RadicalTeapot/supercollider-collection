(
// s = ~useJACK.(2, 2);
s.waitForBoot {
    var looperCount, looperBuffers, looperBuses, mixOutBus, delayBuf, mixer, fx;
    var mixValues;
    // var recLfoFreqs, reverseLfoFreqs, panLfoFreqs, startPosLfoFreqs, phasorSpeedLfoFreqs, mixValues;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    looperCount = 8; // Original patch value was 4
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
        var minDuration = \minDuration.kr(0.02).max(2 * fadeTime);

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
        // Gate duration is held until the next trigger so we can use a sine here (i.e. a latch is not needed)
        var gateDuration = SinOsc.ar(recGateDurationLfoFreq).range(minDuration, bufDur.min((2*recLfoFreq).reciprocal));
        var recGate = Trig1.ar(recTrig, gateDuration);
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
        SendReply.kr(Impulse.kr(refreshRate), '/updateGUI', [id, recGate, loopPoint / bufFrames, readPhasor / bufFrames, recPhasor / bufFrames, amp, panLfo.unipolar, (Amplitude.kr(sig.sum, 0.1, 0.5).lag(0.1) * 30).clip(0, 1)]);
        Out.ar(out, sig);
    }).add;

    SynthDef(\mixer, {
        var inputs = \inputs.ir(Array.series(looperCount));
        var levels = \levels.kr(Array.fill(looperCount, 1));
        var out = \out.ir(0);
        var sig = Mix(inputs.collect({ |v| In.ar(v, 2) }) * levels);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var sndIn = \sndIn.ir(0);

        // Parameters below should be controlled by GUI
        var tapeDryWet = \tapeDryWet.kr(0.33);
        var reverbDryWet = \reverbDryWet.kr(0.5);
        var hissAmp = \hissAmp.kr(-46.dbamp).clip(0, 1);
        var crackleAmp = \crackleAmp.kr(-36.dbamp).clip(0, 1);

        var phasor = Phasor.ar(rate: BufRateScale.ir(buf), end: BufFrames.ir(buf));
        var input = In.ar(in, 2);

        // Read from tape with some wobble
        var tapeWobble = LFNoise2.ar(2!2).lincurve(-1, 1, 0, BufSampleRate.ir(buf) * 0.004, 10);
        // var tapeWobble = SinOsc.ar(0.99).unipolar(0.004) * BufSampleRate.ir(0);
        var tapeDelay = BufRd.ar(2, buf, (phasor + tapeWobble).wrap(0, BufFrames.ir(buf)), interpolation: 4);

        var soundIn = SoundIn.ar(sndIn + [0,1]);
        var sig = (Mix([input, soundIn]) * -6.dbamp).blend(tapeDelay, tapeDryWet);
        // To reverb before hiss, crackles and saturation
        var rev = NHHall.ar(sig, 2, 0.15);

        // Back to tape delay with some hiss, crackles and saturation
        var tapeCrackle = BPF.ar(PinkNoise.ar(1!2) * WhiteNoise.ar(1!2), 2000, 0.75) * LFNoise2.kr(0.5!2).linlin(-1, 1, 0.25, 1);
        var tapeHiss = BPF.ar(PinkNoise.ar(1!2), LFNoise1.kr(2.3587!2).linlin(-1, 1, 2000, 4000), 0.95);
        sig = sig + (tapeHiss * hissAmp) + (tapeCrackle * crackleAmp);
        sig = sig.tanh;
        RecordBuf.ar(LPF.ar(HPF.ar(sig, 50), 10000), buf, recLevel: 1, preLevel: -12.dbamp);

        // Add reverb
        sig = sig.blend(rev, reverbDryWet);
        sig = Compander.ar(sig, sig, 0.4, 1, 5.reciprocal, 0.005, 0.5);
        Out.ar(out, sig);
    }).add;
    s.sync;

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
            minDuration: 0.5,
        ]);
    };

    mixValues = Array.fill(looperCount, 1);
    mixer = Synth.tail(s, \mixer, [inputs: looperBuses, levels: mixValues, out: 2/*, out: mixOutBus*/]);
    // fx = Synth.tail(s, \fx, [in: mixOutBus, out: 0, buf: delayBuf]);

    AppClock.sched(0, {
        var
        recGates = Array.fill(looperCount, 0),
        normalizedLoopPoints = Array.fill(looperCount, 0),
        readPositions = Array.fill(looperCount, 0),
        recPositions = Array.fill(looperCount, 0),
        amps = Array.fill(looperCount, 0),
        pans = Array.fill(looperCount, 0),
        amplitudes = Array.fill(looperCount, 0);

        var bounds = Rect(1200, 50, 600, 400);
        var userViews = looperCount.collect({ |i|
            var level = ObservableParameter(mixValues[i], set: {|value| value.clip(0.0, 1.0)});
            var enabled = ObservableParameter(1, set: {|value| value.asInteger});
            var isDragging = false;
            var userView = UserView()
            .background_(Color.white)
            .mouseDownAction_({ |view, x, y, mods, button|
                if (button == 0) { isDragging = true }; // Left click
                if (button == 1) { enabled.value = 1 - enabled.value; } // Right click
            })
            .mouseUpAction_({ isDragging = false; })
            .mouseMoveAction_({ |view, x, y| level.value = 1 - (y / view.bounds.height); })
            .drawFunc_({|view|
                var width = view.bounds.width;
                var height = view.bounds.height;
                var ampBarWidth = 15;

                // Draw amplitude color rect
                var amplitude = amplitudes[i] * level.value;
                Pen.fillColor = Color.hsv((1-amplitude) * 0.66, enabled.value, enabled.value * 0.5 + 0.5);
                Pen.addRect(Rect(width-ampBarWidth-2, (1-amplitude)*(height-1), ampBarWidth+1, height)); // Can use height for height as it will get clipped when going out of bounds
                Pen.fill;

                // Draw control borders
                Pen.width = 1;
                Pen.strokeColor = Color.black;
                Pen.addRect(Rect(1, 1, width-ampBarWidth-2, height-2));
                Pen.addRect(Rect(width-ampBarWidth-1, 1, ampBarWidth-1, height-2));
                Pen.stroke;

                // Draw level bar
                Pen.width = 2;
                Pen.strokeColor = Color.black;
                Pen.moveTo((width-ampBarWidth-2)@((1-level.value) * (height-1)));
                Pen.lineTo((width-1)@((1-level.value) * (height-1)));
                Pen.stroke;

                // Draw rec / play loop point rect
                Pen.width = 2;
                Pen.strokeColor = Color.black;
                if (recGates[i].asInteger == 1) {
                    Pen.fillColor = Color(1, 0.66, 0.66); // Light red
                } {
                    Pen.fillColor = Color(0.66, 1, 0.66); // Light green
                };
                if (enabled.value == 0) { Pen.fillColor = Color.gray };
                Pen.addRect(Rect(2, 2, (width-ampBarWidth-4) * normalizedLoopPoints[i], height-4));
                Pen.fillStroke;

                if (recGates[i].asInteger == 0) {
                    // Draw pan + amp point and play pos bar
                    var x = readPositions[i] * (width-ampBarWidth);
                    var size = (amps[i]*5+1);
                    Pen.width = size;
                    Pen.strokeColor = Color(0, 0.5 * enabled.value, 0);
                    Pen.moveTo(x@3);
                    Pen.lineTo(x@(height-3));
                    Pen.stroke;
                    Pen.strokeColor = Color.black;
                    Pen.fillColor = Color.black;
                    Pen.addArc(x@(pans[i]*(height-20)+10), size, 0, 2pi);
                    Pen.fillStroke;
                } {
                    // Draw rec pos bar
                    var x = recPositions[i] * (width-ampBarWidth);
                    Pen.width = 2;
                    Pen.strokeColor = Color(0.5 * enabled.value, 0, 0);
                    Pen.moveTo(x@3);
                    Pen.lineTo(x@(height-3));
                    Pen.stroke;
                };
            });

            // Link parameters to UI and synths
            level.register(\uiUpdate, { defer { userView.refresh }});
            level.register(\synthUpdate, { |value|
                mixValues[i] = value * enabled.value;
                s.bind { mixer.set(\levels, mixValues) };
            });
            enabled.register(\uiUpdate, { defer { userView.refresh }});
            enabled.register(\synthUpdate, { |value|
                mixValues[i] = value * level.value;
                s.bind { mixer.set(\levels, mixValues) };
            });

            // Return user view
            userView;
        });

        var window = Window(bounds: bounds)
        .front
        .alwaysOnTop_(true)
        .background_(Color.white)
        .layout_(VLayout(*userViews)) // TODO Add FX controls
        .onClose_({CmdPeriod.run});

        OSCFunc({ |msg|
            var i = msg[3].asInteger;
            [recGates, normalizedLoopPoints, readPositions, recPositions, amps, pans, amplitudes].do { |v, j|
                v[i] = msg[4+j];
            };
            defer { userViews[i].refresh };
        }, '/updateGUI');
    });
};
)
