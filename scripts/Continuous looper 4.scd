~useJACK.();

(
SynthDef(\looper, {
    var buf = \buf.ir(0);
    var trigger, start, end, frames, phasor, sig;

    trigger = LocalIn.ar(1) + Impulse.ar(0);
    start = 0;
    end = BufFrames.ir(buf) * 0.1;
    frames = BufFrames.ir(buf);

    phasor = Phasor.ar(trigger, 1, 0, end: frames).clip(0, end);
    sig = BufRd.ar(2, buf, phasor);

    LocalOut.ar(phasor>=(end-1));

    sig = LeakDC.ar(sig);
    Out.ar(\bus.ir(0), sig * \amp.kr(-6.dbamp));
}).add;

SynthDef(\crossfadeLooper, {
    var buf = \buf.kr(0);
    var rate = \rate.kr(1).max(0); // Reverse is not implemented here
    var trigger, start, end, crossEnd, frames, phasorA, phasorB, sigA, sigB, sig;
    var aOrB, startA, startB, rateA, rateB, preEndA, preEndB, endA, endB, crossfade, crossfadeDuration;

    trigger = LocalIn.ar(1) + Impulse.ar(0);
    frames = BufFrames.kr(buf);
    rate = rate * BufRateScale.kr(buf);
    crossfadeDuration = 0.05;
    start = max(\start.kr(0) - (crossfadeDuration * rate * SampleRate.ir), 0);
    end = \end.kr(10000);
    crossEnd = min(end + (crossfadeDuration * rate * SampleRate.ir), frames);

    // latch to change trigger between the two loopers
    aOrB=ToggleFF.kr(trigger);

    startA=Latch.kr(start,aOrB);
    preEndA = Latch.kr(end, aOrB);
    endA=Latch.kr(crossEnd,aOrB);
    rateA = Latch.kr(rate, aOrB);

    startB=Latch.kr(start,1-aOrB);
    preEndB = Latch.kr(end, 1-aOrB);
    endB=Latch.kr(crossEnd,1-aOrB);
    rateB = Latch.kr(rate, 1-aOrB);

    crossfade=Lag.ar(K2A.ar(aOrB),0.05);

    phasorA = Phasor.ar(aOrB, rateA, startA, frames, startA);
    sigA = BufRd.ar(2, buf, phasorA + startA);

    phasorB = Phasor.ar((1-aOrB), rateB, startB, frames, startB);
    sigB = BufRd.ar(2, buf, phasorB + startB);

    LocalOut.ar(((phasorA*aOrB)>=(preEndA-1)) + ((phasorB*(1-aOrB))>=(preEndB-1)));

    sig = (crossfade*sigA)+((1-crossfade)*sigB);
    sig = LeakDC.ar(sig);
    Out.ar(\bus.ir(0), sig * \amp.kr(-6.dbamp));
}).add;

)

(s.waitForBoot({
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/recordings/SC_230904_105002.wav";

    s.freeAll;
    Buffer.freeAll;
    s.sync;

    ~buf = Buffer.read(s, bufferContentPath, 0, 48000 * 10); // Only the first 10 sec
    s.sync;

    ~splices = Array.interpolation(10, 5000, ~buf.numFrames-5000).asInteger;
    ~synth = Synth(\crossfadeLooper, [buf: ~buf]);
    s.sync;
    fork { loop {
        var index = rrand(0, ~splices.size-2);
        s.bind { ~synth.set(/*\rate, [-24, -12, 0, 12, 24].choose.midiratio,*/ \start, ~splices[index], \end, ~splices[index+1]) };
        1.wait;
    }}
}))