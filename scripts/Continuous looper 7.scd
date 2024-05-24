~useJACK.();

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
    var crossfadeSamples = crossfadeDuration * BufSampleRate.kr(buf);

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

    var starts = Latch.kr(start, toggles).clip(crossfadeSamples*(rate>=0), frames-(crossfadeSamples*(rate<0)));
    var ends = Latch.kr(end, toggles).clip(crossfadeSamples*(rate>=0), frames-(crossfadeSamples*(rate<0)));
    LocalOut.ar((((phasors<starts) + (phasors>ends)) * (1-toggles)).sum);

    Out.ar(out, LeakDC.ar(sig) * amp);
}).add;

SynthDef(\crossfadeLooper2, {
    // TODO Run some tests
    var buf = \buf.ir(0);
    var frames = BufFrames.ir(buf);
    var sr = BufSampleRate.ir(buf);

    var out = \out.kr(0);
    var amp = \amp.kr(-6.dbamp);

    var rateLag = \rateLag.kr(0);
    var rate = \rate.ar(1, rateLag);
    var rateDir = [rate>=0,rate<0];
    var absRate = rate.abs.max(1);

    var crossfadeDuration = \crossfadeDuration.kr(0.05) * sr;
    var absRateCrossfade = crossfadeDuration * absRate;

    var startArg = \start.ar(0).max(absRateCrossfade);
    var endArg = (\end.ar(500) + absRateCrossfade).min(frames - absRateCrossfade);

    var isInitialFrame = Impulse.ar(0);
    var triggers = LocalIn.ar(2) + [0, isInitialFrame];

    var phasorToggle = ToggleFF.ar(triggers[0]);
    var start = Latch.ar(startArg, triggers[1]);
    var end = Latch.ar(endArg, triggers[1]);

    var toggles = [1-phasorToggle, phasorToggle];
    var resetPos = ([start - absRateCrossfade, end + absRateCrossfade] * rateDir).sum;
    var phasors = Phasor.ar(toggles, rate,
        isInitialFrame * start, // Start on 1st run, 0 otherwise
        frames - (isInitialFrame * (frames - end)), // End on 1st run, frames otherwise
        resetPos);

    var crossfade = Slew.ar(phasorToggle, BufSampleRate.ir(buf) / crossfadeDuration, BufSampleRate.ir(buf) / crossfadeDuration);
    var sigs = BufRd.ar(2, buf, phasors, interpolation: 4);
    var sig = LinXFade2.ar(sigs[0], sigs[1], crossfade.linlin(0,1,-1,1));

    // Compute the offset of both phasors and gate it using the current phasor gate
    var offsetPhasors = [
        ((phasors + BlockSize.ir + absRateCrossfade - end) * toggles).sum,
        ((start + BlockSize.ir + absRateCrossfade - phasors) * toggles).sum
    ] * rateDir;
    var clips = (offsetPhasors.sum + [0, BlockSize.ir]).max(0);
    LocalOut.ar(clips * (1-isInitialFrame)); // Skip first frame as phasor is 0 then and it can cause issues when starting with a negative rate

    Out.ar(out, LeakDC.ar(sig) * amp);
}).add;
)

(s.waitForBoot({
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/recordings/SC_230904_105002.wav";
    var splices, crossfadeDuration, buf, synth;

    s.freeAll;
    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    buf = Buffer.read(s, bufferContentPath);
    s.sync;

    crossfadeDuration = 0.1;
    splices = Array.interpolation(20, 0, buf.numFrames).asInteger;

    synth = Synth(\crossfadeLooper2, [buf: buf, start: splices[0], end: splices[1], crossfadeDuration: crossfadeDuration, amp: 1]);
    s.sync;

    fork {
        loop {
            var index = rrand(0, splices.size-2);
            var rate = [-12, 0, 12, 24].wchoose([1,2,1,0.66].normalizeSum).midiratio * [-1, 1].choose;
            var rateLag = [0, 0.02, 0.05, 0.2, 0.4].wchoose([8, 1, 2, 1, 1, 0.25].normalizeSum);
            s.bind { synth.set(\rate, rate, \start, splices[index], \end, splices[index+1], \rateLag, rateLag) };
            rrand(2*crossfadeDuration, 4).wait;
    }}
}))