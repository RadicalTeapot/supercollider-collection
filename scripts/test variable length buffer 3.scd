(
CmdPeriod.run;
s.waitForBoot {
    var bus, outBus, readBuf, recBuf, displayBuf, samplerSynth, channelCount = 1;

    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    readBuf = Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01.wav");
    bus = Bus.audio(s, channelCount);
    outBus = Bus.audio(s, channelCount);
    recBuf = Buffer.alloc(s, s.sampleRate * 3, channelCount);
    s.sync;

    SynthDef(\recAndPlay, {
        var recGate = \recGate.ar(0);
        var buf = \buf.ir(0);
        var in = \in.ir(0);
        var out = \out.ir(0);

        var bufFrames = K2A.ar(BufFrames.ir(buf));
        var lastFrame = Latch.ar(Phasor.ar(recGate, BufRateScale.ir(buf), end: bufFrames, resetPos: -1), 1-recGate);
        var loopPoint = Select.ar(recGate, [lastFrame, bufFrames]);
        var writePhasor = Phasor.ar(Changed.ar(recGate), BufRateScale.ir(buf), end: loopPoint, resetPos: -1); // Fix first buf frame being 0
        var prev = BufRd.ar(channelCount, buf, writePhasor);
        var recSig = SelectX.ar(recGate.slew(0.02.reciprocal, 0.02.reciprocal), [prev * (1 - recGate), In.ar(in, channelCount)]);

        BufWr.ar(recSig, buf, writePhasor);
        Out.ar(out, prev);
    }).add;
    s.sync;

    {PlayBuf.ar(1, readBuf, BufRateScale.kr(readBuf)).dup(channelCount) * -12.dbamp}.play(s, bus);
    samplerSynth = Synth.tail(s, \recAndPlay, [buf: recBuf, in: bus, out: 0]);
    s.sync;

    Routine {
        0.1.wait;
        s.bind { samplerSynth.set(\recGate, 1) };
        0.2.wait;
        s.bind { samplerSynth.set(\recGate, 0) };
    }.play;

    s.scope(channelCount, 0, bufsize: 10 * s.sampleRate / 60.midicps);
};
)