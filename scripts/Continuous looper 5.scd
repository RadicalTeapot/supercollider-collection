~useJACK.();

(
SynthDef(\crossfadeLooper, {
    var buf = \buf.kr(0);
    var bus = \bus.kr(0);
    var amp = \amp.kr(-6.dbamp);
    var rate = \rate.kr(1);
    var start = \start.kr(0);
    var end = \end.kr(10000);

    var frames = BufFrames.kr(buf);
    var duration = (end - start) / (BufSampleRate.kr(buf) * rate);
    var bufRate = rate * BufRateScale.kr(buf);

    var trigger = TDuty.ar(duration, gapFirst: 1);
    var toggle = ToggleFF.ar(trigger);
    var invToggle = 1 - toggle;
    var crossfade = Lag.ar(toggle, 0.05);

    var sigs = [toggle, invToggle];
    var rates = Latch.kr(rate, sigs);
    var starts = Latch.kr(start, sigs);
    var ends = Latch.kr(end, sigs);
    var phasors = Phasor.ar(sigs, rates, starts, frames, starts);
    sigs = BufRd.ar(2, buf, phasors, interpolation: 4);

    Out.ar(bus, SelectX.ar(1-crossfade, sigs) * amp);
}).add;
)

(s.waitForBoot({
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/recordings/SC_230904_105002.wav";

    s.freeAll;
    Buffer.freeAll;
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
            var rate = [-12, 0, 12, 24].wchoose([1,2,1,0.66].normalizeSum).midiratio;
            s.bind { ~synth.set(\rate, rate, \start, ~splices[index], \end, ~splices[index+1]) };
            rrand(0.5, 4).wait;
    }}
}))