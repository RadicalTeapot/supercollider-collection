(SynthDef(\justEnd, {
    var buf = \buf.ir(0);
    var start = 0;
    var frames = BufFrames.ir(buf);

    var trigger = LocalIn.ar(1);
    var end = Demand.ar(trigger + Impulse.ar(0), 0, Dseq([200, 300, 500], inf));
    var phasor = Phasor.ar(trigger, end: frames, resetPos: start);
    // Take into account the delay introduced by LocalIn/LocalOut
    var clip = ((phasor+BlockSize.ir)-end).max(0);
    LocalOut.ar(clip);

    RecordBuf.ar([phasor], buf, loop: 0, doneAction: Done.freeSelf);
}).add;

SynthDef(\startAndEnd, {
    var buf = \buf.ir(0);
    // var start = 0;
    var frames = BufFrames.ir(buf);

    var triggers = LocalIn.ar(2);
    var start = Demand.ar(triggers[1] + Impulse.ar(0), 0, Dseq([0, 100, 200], inf));
    var end = Demand.ar(triggers[0] + Impulse.ar(0), 0, Dseq([200, 300, 400], inf));
    var phasor = Phasor.ar(triggers[0], end: frames, resetPos: start);
    // Take into account the delay introduced by LocalIn/LocalOut and shift the start sample trigger by an extra block size for it to have the correct value a whole block before the phasor trigger
    var clips = (((phasor+BlockSize.ir)-end) + [0, BlockSize.ir]).max(0);
    LocalOut.ar(clips);

    RecordBuf.ar([phasor], buf, loop: 0, doneAction: Done.freeSelf);
}).add;

SynthDef(\crossfade, {
    var buf = \buf.ir(0);
    var frames = BufFrames.ir(buf);

    var rate = \rate.ar(1).max(0);
    var crossfadeDuration = \crossfadeDuration.kr(50);
    var startArg = \start.ar(0).max(crossfadeDuration);
    var endArg = (\end.ar(500) + crossfadeDuration).min(frames);

    var triggers = LocalIn.ar(2);

    var phasorToggle = ToggleFF.ar(triggers[0]);
    var start = Latch.ar(startArg, triggers[1] + Impulse.ar(0));
    var end = Latch.ar(endArg, triggers[0] + Impulse.ar(0));

    var toggles = [1-phasorToggle, phasorToggle];
    var phasors = Phasor.ar(toggles, rate: rate, end: frames, resetPos: (start-crossfadeDuration));

    var crossfade = Slew.ar(phasorToggle, BufSampleRate.ir(buf) / crossfadeDuration, BufSampleRate.ir(buf) / crossfadeDuration);

    // Compute the offset of both phasors and gate it using the current phasor gate
    var offsetPhasors = ((phasors + BlockSize.ir + crossfadeDuration) - end) * toggles;
    var clips = (offsetPhasors.sum + [0, BlockSize.ir]).max(0);
    LocalOut.ar(clips);

    RecordBuf.ar(phasors ++ ([phasorToggle, crossfade] * endArg) ++ [(phasors * [1-crossfade,crossfade]).sum], buf, loop: 0, doneAction: Done.freeSelf);
}).add;

SynthDef(\crossfadeRev, {
    // TODO Run some tests
    var buf = \buf.ir(0);
    var frames = BufFrames.ir(buf);

    var rate = \rate.ar(1);
    var rateDir = [rate>=0,rate<0];
    var absRate = rate.abs.max(1);
    var crossfadeDuration = \crossfadeDuration.kr(50);
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

    // Compute the offset of both phasors and gate it using the current phasor gate
    var offsetPhasors = [
        ((phasors + BlockSize.ir + absRateCrossfade - end) * toggles).sum,
        ((start + BlockSize.ir + absRateCrossfade - phasors) * toggles).sum
    ] * rateDir;
    var clips = (offsetPhasors.sum + [0, BlockSize.ir]).max(0);
    LocalOut.ar(clips * (1-isInitialFrame)); // Skip first frame as phasor is 0 then and it can cause issues when starting with a negative rate

    RecordBuf.ar(phasors ++ ([phasorToggle, crossfade] * endArg) ++ [(phasors * [1-crossfade,crossfade]).sum], buf, loop: 0, doneAction: Done.freeSelf);
}).add;
)

(s.waitForBoot({
    var buf, duration;

    s.freeAll;
    Buffer.freeAll;
    s.sync;

    buf = Buffer.alloc(s, 3000, 5);
    duration = 10000 / s.sampleRate;
    s.sync;

    fork {
        s.bind { Synth(\crossfadeRev, [buf: buf, rate: 1]) };
        duration.wait;
        defer { buf.plot(bounds: Rect(100, 100, 1500, 800)) };
    };
}))