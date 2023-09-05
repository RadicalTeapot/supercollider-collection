(
SynthDef(\crossfadeLooper, {
    var buf = \buf.kr(0);
    var out = \out.kr(0);
    var amp = \amp.kr(-6.dbamp);
    var rateLag = \rateLag.kr(0);
    var rate = \rate.kr(1, rateLag);
    var crossfadeDuration = \crossfadeDuration.kr(0.05);
    var start = \start.kr(0);
    var end = \end.kr(10000);

    var bufRate = rate * BufRateScale.kr(buf);
    var frames = BufFrames.kr(buf);

    var trigger = LocalIn.ar(1);
    var toggle = ToggleFF.ar(trigger);
    var invToggle = 1 - toggle;
    var toggles = [toggle, invToggle];

    var phasors = Phasor.ar(
        toggles, bufRate, 0, frames,
        (start*(rate>=0)) + (end*(rate<0))
    );
    var sigs = BufRd.ar(2, buf, phasors, interpolation: 4);

    var crossfade = VarLag.ar(toggle, crossfadeDuration);
    var sig = LinXFade2.ar(sigs[0], sigs[1], crossfade.linlin(0,1,1,-1));

    var starts = Latch.kr(start, toggles).clamp(crossfadeSamples*(rate>=0), frames-(crossfadeSamples*(rate<0)));
    var ends = Latch.kr(end, toggles).clamp(crossfadeSamples*(rate>=0), frames-(crossfadeSamples*(rate<0)));
    LocalOut.ar(((phasors<(starts)) + (phasors>(ends))).sum);

    Out.ar(out, LeakDC.ar(sig) * amp);
}).add;
)

(s.waitForBoot({
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/recordings/SC_230904_105002.wav";
    var crossfadeSamples, splices, crossfadeDuration, buf, synth;

    s.freeAll;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    buf = Buffer.read(s, bufferContentPath);
    s.sync;

    crossfadeDuration = 0.1;
    crossfadeSamples = buf.sampleRate * crossfadeDuration * 2; // Times two to take into account max playback rate
    splices = Array.interpolation(20, crossfadeSamples, buf.numFrames-crossfadeSamples).asInteger;

    synth = Synth(\crossfadeLooper, [buf: buf, start: splices[0], end: splices[1], crossfadeDuration: crossfadeDuration, amp: 1]);
    s.sync;

    fork {
        loop {
            var index = rrand(0, splices.size-2);
            var rate = [-12, 0, 12, 24].wchoose([1,2,1,0.66].normalizeSum).midiratio * [-1, 1].choose;
            var rateLag = [0, 0.02, 0.05, 0.2].wchoose([10, 1, 2, 1, 1].normalizeSum);
            s.bind { synth.set(\rate, rate, \start, splices[index], \end, splices[index+1], \rateLag, rateLag) };
            rrand(2*crossfadeDuration, 4).wait;
    }}
}))