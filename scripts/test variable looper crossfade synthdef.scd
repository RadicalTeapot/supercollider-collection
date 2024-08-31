(
s.waitForBoot {
    var buf, synth;
    Buffer.freeAll;
    s.sync;

    buf = Buffer.read(s, "C:/Users/Mathias/AppData/Local/_data/Supercollider/scripts/assets/recordings/SC_230904_105002.wav");
    s.sync;

    SynthDef(\looper, {
        var inTrig = \trig.tr(0);
        var fadeTime = 0.02;
        var center = LFNoise2.ar(0.263473).range(0.25, 0.75);
        var width = LFNoise2.ar(0.67324572).unipolar(0.5);
        var frames = BufFrames.ir(buf);
        var start = (center - width * 0.5).clip(0, 0.9) * frames;
        var end = (center + width * 0.5).clip((start/frames)+0.05, 1) * frames;

        var speeds = LocalBuf.newFrom([-0.5, -1, -2, 0.5, 1, 2]);

        var speed = Index.ar(speeds, LFNoise0.ar(0.3457).unipolar(6)).lag(1.0); // Lag here makes tape speed up / down sounds ;)
        var currentPhasorIndex = ToggleFF.ar(LocalIn.ar);
        var resetTrigs = [1-currentPhasorIndex, currentPhasorIndex];
        var rate = speed * BufRateScale.ir(buf);
        var phasors = Phasor.ar(resetTrigs, rate: rate, start: 0, end: frames, resetPos: Select.ar(rate>=0, [end, start]));
        var currentPhasor = Select.ar(currentPhasorIndex, phasors);
        // Only check boundaries in direction of travel (getting "caught-up" by the other bound doesn't trigger)
        var trig = Select.ar(rate >= 0, [
            currentPhasor < (start + (ControlDur.ir * rate.abs)),
            currentPhasor > (end - (ControlDur.ir * rate))
        ]) + inTrig;
        var xfade = Slew.ar(currentPhasorIndex, fadeTime.reciprocal, fadeTime.reciprocal);
        var bufSig = BufRd.ar(2, buf, phasors);
        var sig = SelectX.ar(xfade, bufSig);

        trig = 1 - SetResetFF.ar(Impulse.ar(fadeTime.reciprocal), trig); // Debounce trig so it doesn't happen faster than fade time
        // Extra trig if close to the start / end of buffer (not debounced as it needs to occur right away to avoid clicks)
        trig = trig + Select.ar(rate >= 0, [
            currentPhasor < ((fadeTime + ControlDur.ir) * rate.abs),
            currentPhasor > (frames - ((fadeTime + ControlDur.ir) * rate))
        ]);
        // For UI
        SendReply.ar(Impulse.ar(30), '/values', [
            start / frames, end / frames, phasors[0] / frames, phasors[1] / frames,
            currentPhasorIndex, SelectX.ar(xfade, phasors) / frames
        ]);

        LocalOut.ar(trig);
        Out.ar(0, sig);
    }).add;
    s.sync;

    s.bind { synth = Synth(\looper) };
    Routine {
        loop {
            var time = [2, 4, 8, 16].choose;
            if (0.5.coin) {
                var count = 2.pow(rrand(1, 4));
                count.do {
                    s.bind { synth.set(\trig, 1) };
                    count.reciprocal.yield;
                }
            } {
                time.yield;
            }
        };
    }.play;

    AppClock.sched(0, {
        var win, start=0, end=1, phasorA=0, phasorB=0, currentIndex=0, interpPhasor=0, userView, soundFileView;
        Window.closeAll;

        win = Window(bounds: Rect(100, 100, 600, 100))
        .alwaysOnTop_(true)
        .background_(Color.white)
        .onClose_({CmdPeriod.run})
        .front;

        userView = UserView(win, win.bounds.moveTo(0,0))
        .drawFunc_({|view|
            var rect = view.bounds;
            var width = rect.width;
            var height = rect.height;
            var pos;

            Pen.fillColor_(Color.gray(0.5));
            Pen.addRect(Rect(start * width, 0, (end - start) * width, height));
            Pen.fill;

            [start, end].do {|v|
                pos = v * width;
                Pen.strokeColor_(Color.red);
                Pen.width_(2);
                Pen.moveTo(pos@0);
                Pen.lineTo(pos@height);
                Pen.stroke;
            };

            pos = interpPhasor * width;
            Pen.strokeColor_(Color.yellow);
            Pen.width_(1);
            Pen.moveTo(pos@0);
            Pen.lineTo(pos@height);
            Pen.stroke;

            [phasorA, phasorB].do {|v, i|
                pos = v * width;
                if (i == currentIndex.asInteger) { Pen.strokeColor_(Color.green) } { Pen.strokeColor_(Color.blue) };
                Pen.width_(2);
                Pen.moveTo(pos@0);
                Pen.lineTo(pos@height);
                Pen.stroke;
            };
        });

        soundFileView = SoundFileView(win, win.bounds.moveTo(0,0))
        .soundfile_(SoundFile.openRead(buf.path))
        .peakColor_(Color.black)
        .rmsColor_(Color.black)
        .background_(Color.clear);
        soundFileView.read(0, buf.numFrames).refresh;
        soundFileView.gridOn = false;
        soundFileView.timeCursorOn = false;
        soundFileView.drawsCenterLine  = false;
        soundFileView.drawsBoundingLines = false;

        OSCFunc({ |msg|
            #start, end, phasorA, phasorB, currentIndex, interpPhasor = msg[3..];
            defer { userView.refresh };
            }, '/values');
    });
};
)