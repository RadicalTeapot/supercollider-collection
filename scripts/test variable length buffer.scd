(
s.waitForBoot {
    var win, recBuf, samplerSynth;

    Buffer.freeAll;
    s.sync;

    recBuf = Buffer.alloc(s, s.sampleRate * 16, 2);
    s.sync;

    SynthDef(\testNotes, {
        var amp = \amp.kr(0.5);
        var out = \out.ir(0);
        var localBuf = LocalBuf.newFrom(Scale.minorPentatonic.semitones);
        var impulse = Impulse.kr(3);
        var rel = Latch.kr(LFNoise0.kr(4.498275), impulse).range(0.1, 0.3);
        var env = Env.perc(releaseTime: rel).kr(0, impulse);
        var note = (DegreeToKey.kr(localBuf, Latch.kr(LFNoise0.kr(2.58375), impulse).unipolar(12)) + 48).midicps;
        var sig = VarSaw.ar(note * LFNoise2.kr(4.32!5).range(0.02, 0.04).midiratio);
        sig = LPF.ar(sig, 250);
        sig = sig * env * amp;
        Out.ar(out, Splay.ar(sig, 0.33, center: LFNoise2.kr(2.1297).bipolar(0.5)));
    }).add;

    SynthDef(\looperNoFeedback, {
        var recGate = \recGate.ar(0);
        var buf = \buf.ir(0);
        var in = \in.ir(0);
        var out = \out.ir(0);
        var amp = \amp.kr(1);
        var fadeTime = \fadeTime.kr(0.02).reciprocal;

        var bufFrames = K2A.ar(BufFrames.ir(buf));
        var lastFrame = Latch.ar(Phasor.ar(recGate, BufRateScale.ir(buf), end: bufFrames, resetPos: -1), 1-recGate);
        var loopPoint = Select.ar(
            (lastFrame > 0) * (1 - recGate), // Only use lastFrame if latch has been initialized and not recording, otherwise use the whole buffer
            [bufFrames, lastFrame]);
        var writePhasor = Phasor.ar(Changed.ar(recGate), BufRateScale.ir(buf), end: loopPoint, resetPos: -1); // Set reset point to -1 to fix an issue where the first frame of the buffer being written to was frame 1 instead of frame 0
        var prev = BufRd.ar(2, buf, writePhasor);
        var gatedPrev = prev * (1 - recGate); // Only use prev for recording when rec gate is at 0
        var recSig = SelectX.ar(recGate.slew(fadeTime, fadeTime), [gatedPrev, In.ar(in, 2)]); // Fade in and out are mixed due to the write phase being reset by the gate (i.e., signals fades in at beginning (mixed with 0 since gatedPrev is used) and when recGate goes to 0, phase is reset and fadeOut occurs which is recorded at the beginning added on fade in)

        BufWr.ar(recSig, buf, writePhasor);
        Out.ar(out, prev * amp * (1-recGate).lag(0.05));
    }).add;

    SynthDef(\looperWithFeedback, {
        var recGate = \recGate.ar(0);
        var buf = \buf.ir(0);
        var in = \in.ir(0);
        var out = \out.ir(0);
        var amp = \amp.kr(1);
        var fadeTime = \fadeTime.kr(0.02).reciprocal;

        var bufFrames = K2A.ar(BufFrames.ir(buf));
        var lastFrame = Latch.ar(LocalIn.ar(1), 1-recGate);
        var loopPoint = Select.ar(
            (lastFrame > 0) * (1 - recGate), // Only use lastFrame if latch has been initialized and not recording, otherwise use the whole buffer
            [bufFrames, lastFrame]);
        var phasor = Phasor.ar(Changed.ar(recGate), BufRateScale.ir(buf), end: loopPoint, resetPos: -1); // Set reset point to -1 to fix an issue where the first frame of the buffer being written to was frame 1 instead of frame 0
        var prev = BufRd.ar(2, buf, phasor);
        var gatedPrev = prev * (1 - recGate); // Only use prev for recording when rec gate is at 0
        var recSig = SelectX.ar(recGate.slew(fadeTime, fadeTime), [gatedPrev, In.ar(in, 2)]); // Fade in and out are mixed due to the write phase being reset by the gate (i.e., signals fades in at beginning (mixed with 0 since gatedPrev is used) and when recGate goes to 0, phase is reset and fadeOut occurs which is recorded at the beginning added on fade in)

        BufWr.ar(recSig, buf, phasor);
        LocalOut.ar(phasor);
        ReplaceOut.ar(out, prev * amp * (1-recGate).lag(0.05));
    }).add;
    s.sync;

    Synth(\testNotes);
    samplerSynth = Synth.tail(s, \looperWithFeedback, [buf: recBuf]);


    AppClock.sched(0, {
        Window.closeAll;
        win = Window(bounds: Rect(500, 150, 250, 70)).alwaysOnTop_(true).front.layout_(
            HLayout(Button().string_("Press me").mouseDownAction_({|view|
                s.bind { samplerSynth.set(\recGate, 1) }
            }).mouseUpAction_({|view|
                s.bind { samplerSynth.set(\recGate, 0) }
            }))
        ).onClose_({CmdPeriod.run});
    });
}
)

{var pulse = LFPulse.ar(10).unipolar; [pulse, pulse.slew(20, 20)]}.plot(0.2)

0.05.reciprocal