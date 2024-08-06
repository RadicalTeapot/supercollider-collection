(
CmdPeriod.run;
s.waitForBoot {
    var bus, recBuf, displayBuf, samplerSynth;

    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    bus = Bus.audio(s, 2);
    recBuf = Buffer.alloc(s, s.sampleRate, 2);
    s.sync;

    SynthDef(\recAndPlay, {
        var recGate = \recGate.ar(0);
        var buf = \buf.ir(0);
        var in = \in.ir(0);

        var bufFrames = K2A.ar(BufFrames.ir(buf));
        var localIn = LocalIn.ar(1);
        // var localIn = LocalIn.ar(2, bufFrames);
        // var frames = Select.ar(recGate, [localIn[0], bufFrames]);
        var phasor = Phasor.ar(Changed.ar(recGate), BufRateScale.ir(buf), end: bufFrames); // Reset on gate on and off
        var prev = BufRd.ar(2, buf, phasor);

        // var frameSH = Latch.ar(localIn[1]+1, 1 - recGate); // Sample and hold with previous phasor value (to avoid sampling the just reseted value)
        var recSig = SelectX.ar(recGate.slew(0.01.reciprocal, 0.01.reciprocal), [prev * (1 - recGate), In.ar(in, 2)]);

        SendReply.ar(1-recGate, '/doneRecording', [localIn]); // Send to display buffer
        LocalOut.ar(phasor);
        BufWr.ar(recSig, buf, phasor); // Since recSig is lagged but phasor is not, we record the fade out at the beginning of the buffer (where it should match the fade in)
        // LocalOut.ar([
        // Select.ar(frameSH > 0, [bufFrames, frameSH]), // Latch defaults to 0 until its first triggered
        // phasor
    // ]);
        ReplaceOut.ar(0, Silent.ar(2));
    }).add;
    s.sync;

    {LFNoise2.ar(132.5395).dup}.play(s, bus);

    samplerSynth = Synth.tail(s, \recAndPlay, [buf: recBuf, in: bus]);
    s.sync;

    Routine {
        s.bind { samplerSynth.set(\recGate, 1) };
        0.1.wait;
        s.bind { samplerSynth.set(\recGate, 0) };
    }.play;

    OSCFunc({ |msg|
        var lastFrame = msg[3];
        Routine {
            var buf = Buffer.alloc(s, lastFrame, 2);
            s.sync;
            s.bind { recBuf.copyData(buf, numSamples: lastFrame) };
            0.2.wait;
            defer { buf.plot };
        }.play;
    }, '/doneRecording').oneShot;

    // s.scope(2, bus.index);
};
)