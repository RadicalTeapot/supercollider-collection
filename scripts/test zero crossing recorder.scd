(
s.waitForBoot {
    SynthDef(\testNotes, {
        var noteFreq = \noteFreq.kr(3);
        var root = \root.kr(48);
        var range = \range.kr(12);
        var amp = \amp.kr(0.5);
        var out = \out.ir(0);

        var localBuf = LocalBuf.newFrom(Scale.minorPentatonic.semitones);
        var impulse = Impulse.kr(noteFreq);
        var rel = Latch.kr(LFNoise0.kr(noteFreq * 1.2425), impulse).range(0.1, 0.3);
        var env = Env.perc(releaseTime: rel).kr(0, impulse);
        var note = (DegreeToKey.kr(localBuf, Latch.kr(LFNoise0.kr(noteFreq * 0.9764), impulse).unipolar(range)) + root).midicps;
        var sig = VarSaw.ar(note * LFNoise2.kr((noteFreq*1.2645346)!5).range(0.02, 0.04).midiratio);
        sig = LPF.ar(sig, 250);
        sig = sig * env * amp;
        // Out.ar(out, Mix(sig));
        Out.ar(out, Splay.ar(sig, 0.33, center: LFNoise2.kr(noteFreq * 0.8979).bipolar(0.5)));
    }).add;

    SynthDef(\zeroCrossingRecorder, {
        var in = \in.ir(0);
        var buf = \buf.ir(0);

        var sig = In.ar(in, 2); // Assumes stereo input (should not click even then but it would be safer to use a mono version)
        var monoSig = Mix(sig); // Use signal mixed down to mono to check for zero crossings (seems to work well enough for signals that are not super wide, not so much for wider signals)
        var prev = Delay1.ar(monoSig); // Get the signal value for last frame

        var phasor = Line.ar(end: BufFrames.kr(buf), dur: BufDur.kr(buf), doneAction: Done.freeSelf); // Used a line rather than a phasor just for convenience here, phasor works just as well
        var end = (phasor >= (BufFrames.kr(buf) - 1)); // Used to send osc signal

        // Trigger on zero crossing (i.e. when signal was below and is now above 0 or the opposite
        var cross = ((prev < 0) * (monoSig > 0)) + ((prev > 0) * (monoSig < 0));
        // Use a flip flop to catch the first crossing trigger only (the value will be the first crossing only)
        var firstCrossing = Latch.ar(phasor, SetResetFF.ar(cross));
        // Latch on all crossings (the last value will be the last crossing)
        var lastCrossing = Latch.ar(phasor, cross);

        SendReply.ar(end, '/crossings', [firstCrossing, lastCrossing]);
        BufWr.ar(sig, buf, phasor);
        FreeSelf.kr(end);
    }).add;

    SynthDef(\zeroCrossingLooper, {
        var in = \in.ir(0);
        var buf = \buf.ir(0);
        var rec = \rec.ar(0);
        var out = \out.ir(0);
        var amp = \amp.kr(-6.dbamp);

        var inputSig = In.ar(in, 2); // Assumes stereo input (should not click even then but it would be safer to use a mono version)
        var monoInputSig = Mix(inputSig);
        var prev = Delay1.ar(monoInputSig);

        var recPhasor = Phasor.ar(rec, BufRateScale.kr(buf), end: BufFrames.kr(buf));
        var cross = ((prev < 0) * (monoInputSig > 0)) + ((prev > 0) * (monoInputSig < 0));

        var firstCrossing = Latch.ar(recPhasor, SetResetFF.ar(cross, rec));
        var lastCrossing = Latch.ar(recPhasor, cross * rec);

        var startPoint = Select.ar(rec, [firstCrossing, DC.ar(0)]);
        var endPoint = Select.ar(rec, [lastCrossing, K2A.ar(BufFrames.kr(buf))]);
        var phasor = Phasor.ar(Changed.ar(rec), BufRateScale.kr(buf), startPoint, endPoint+1);
        var sig = BufRd.ar(2, buf, phasor);
        BufWr.ar(Select.ar(rec, [sig, inputSig]), buf, phasor);
        sig = SelectX.ar(rec.slew(10, 10), [sig, inputSig]);
        sig = sig * amp;
        sig = Pan2.ar(sig);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var delayDW = \delayDW.kr(0.33).clip(0, 1);
        var revbDW = \revbDW.kr(0.25).clip(0, 1);
        var cmpTresh = \cmpTresh.kr(0.4).clip(0, 1);

        var sig = In.ar(in, 2);
        sig = sig.blend(CombL.ar(sig, 1, 1, 3), delayDW);
        sig = sig.blend(HPF.ar(LPF.ar(NHHall.ar(sig, 2, 0.2), 5000), 80), revbDW);
        sig = LeakDC.ar(sig);
        sig = Compander.ar(sig, sig, cmpTresh, 1, 5.reciprocal, 0.005, 0.066);

        ReplaceOut.ar(out, sig);
    }).add;
};
)


// Using recorder
(
fork {
    var buf, bus;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    bus = Bus.audio(s, 1);
    buf = Buffer.alloc(s, s.sampleRate, 1);
    s.sync;

    OSCFunc({ |msg|
        var loopBuf, start, end;
        #start, end = msg[3..];
        ("Loop from"+start+"to"+end).postln;
        fork {
            loopBuf = Buffer.alloc(s, end - start, 1);
            s.sync;
            buf.copyData(loopBuf, 0, start, end - start);
            s.sync;
            defer { loopBuf.plot };
        };
    }, '/crossings').oneShot;

    Synth(\testNotes, [out: bus]);
    Synth.tail(s, \zeroCrossingRecorder, [in: bus, buf: buf]);
};
)

// Using looper
(
fork {
    var buf, bus, looper, notes;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    bus = Bus.audio(s, 2);
    buf = Buffer.alloc(s, s.sampleRate * 4, 2);
    s.sync;

    notes = Synth(\testNotes, [out: bus, root: 60]);
    looper = Synth.tail(s, \zeroCrossingLooper, [in: bus, buf: buf, amp: 1]);
    // Synth.tail(s, \fx, [revbDW: 0.2]);

    Routine {
        inf.do {
            var time = rrand(2.0, 3.5);
            s.bind {
                notes.set(\noteFreq, rrand(1.5, 3.0) * 2);
                looper.set(\rec, 1);
            };
            "Rec".postln;
            time.yield;
            s.bind { looper.set(\rec, 0) };
            "Loop".postln;
            (rrand(2, 6) * time).yield;
        }
    }.play;
};
)