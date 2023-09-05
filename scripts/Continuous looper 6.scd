~useJACK.();

(
SynthDef(\crossfadeLooper, {
    var buf = \buf.kr(0);
    var out = \out.kr(0);
    var amp = \amp.kr(-6.dbamp);
    var rateLag = \rateLag.kr(0);
    var rate = \rate.kr(1, rateLag);
    var start = \start.kr(0);
    var end = \end.kr(10000);
    var updateTrigger = \updateTrigger.tr(0);

    var frames = BufFrames.kr(buf);
    var duration = (end - start) / (BufSampleRate.kr(buf) * rate.abs);
    var bufRate = rate * BufRateScale.kr(buf);

    var trigger = TDuty.ar(duration, gapFirst: 1);
    var toggle = ToggleFF.ar(trigger);
    var invToggle = 1 - toggle;
    var crossfade = VarLag.ar(toggle, 0.05);

    var sigs = [toggle, invToggle];
    var phasors = Phasor.ar(
        sigs, bufRate, 0, frames,
        (start*(rate>=0)) + (end*(rate<0))
    );
    sigs = BufRd.ar(2, buf, phasors, interpolation: 4);

    Out.ar(out, LeakDC.ar(LinXFade2.ar(sigs[0], sigs[1], crossfade.linlin(0,1,1,-1))) * amp);

    // DON'T SEND THIS OUT TO HEADPHONES, ONLY TO A BUS TO BE RECORDED
    // Out.ar(out, phasors.linlin(0, frames, 0, 1) ++ [crossfade, toggle, T2A.ar(updateTrigger)]);
}).add;

SynthDef(\diskOut, {
    DiskOut.ar(\bufNum.ir(0), In.ar(\in.ir(0), 5));
}).add;
)

(s.waitForBoot({
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/recordings/SC_230904_105002.wav";
    var recordingChannels = 5;

    s.freeAll;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    ~buf = Buffer.read(s, bufferContentPath);
    s.sync;

    ~splices = Array.interpolation(20, 10000, ~buf.numFrames-10000).asInteger;
    ~synth = Synth(\crossfadeLooper, [buf: ~buf, start: ~splices[0], end: ~splices[1]]);
    s.sync;
    fork {
        4.wait;
        loop {
            var index = rrand(0, ~splices.size-2);
            var rate = [-12, 0, 12, 24].wchoose([1,2,1,0.66].normalizeSum).midiratio * [-1, 1].choose;
            var rateLag = [0, 0.02, 0.05, 0.2].wchoose([10, 1, 2, 1, 1].normalizeSum);
            s.bind { ~synth.set(\rate, rate, \start, ~splices[index], \end, ~splices[index+1], \rateLag, rateLag) };
            rrand(1, 4).wait;
    }}

    // Recording logic to test out values
    /*
    ~outBus = Bus.audio(s, recordingChannels);
    ~outBuf = Buffer.alloc(s, (s.sampleRate * 10).nextPowerOfTwo, recordingChannels);
    s.sync;

    ~synth = Synth(\crossfadeLooper, [buf: ~buf, rate: -4, start: ~splices[0], end: ~splices[1], out: ~outBus]);
    ~outBuf.write("~/Documents/SuperCollider/Recordings/looper.wav".standardizePath, "wave", "int16", 0, 0, leaveOpen: true);
    s.sync;
    fork {
        s.bind {~writer = Synth.tail(nil, \diskOut, [bufNum: ~outBuf, in: ~outBus])};
        3.wait;
        s.bind {~synth.set(\start, ~splices[0], \end, ~splices[2], \updateTrigger, 1)};
        4.wait;
        s.bind {~synth.set(\start, ~splices[0], \end, ~splices[1], \updateTrigger, 1)};
        5.wait;
        s.bind {
            ~writer.free;
            ~outBuf.close;
            ~outBuf.free;
            'Done recording'.postln;
        }
    }
    */
}))