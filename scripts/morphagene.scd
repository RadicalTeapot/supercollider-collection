~useJACK.();

(
SynthDef(\phasor, {
    var bus = \bus.ir(0);
    var duration = \duration.kr(1.0);

    var phasor = Line.ar(dur: duration, doneAction: Done.freeSelf);
    var gate = Trig.ar(Impulse.ar(0), duration);

    Out.ar(bus, [phasor, gate]);
}).add;

SynthDef(\player1, {
    var buf = \buf.ir(0);
    var start = \start.kr(0);
    var end = \end.kr(1);
    var audioBus = \audioBus.ir(0);
    var posBus = \posBus.ir(1);
    var amp = \amp.kr(0.25);
    var trigger = \trigger.tr(1);
    var rate = \rate.kr(1);

    var phasor = Phasor.ar(trigger, BufRateScale.ir(buf) * rate, start, end, start);
    var sig = BufRd.ar(2, buf, phasor, 0);
    var pos = (phasor - start) / (end - start);
    pos = Select.ar(rate>0, [1-pos, pos]);
    Out.ar(posBus, pos);
    Out.ar(audioBus, sig * amp);
}).add;

SynthDef(\player2, {
    // Args
    var audioBuf = \audioBuf.ir(0);
    var audioBus = \audioBus.ir(0);

    var posBus = \posBus.ir(1);

    var amp = \amp.kr(-6.dbamp);
    var rateLag = \rateLag.kr(0.1);
    var rate = \rate.kr(1, rateLag) * BufRateScale.ir(audioBuf);

    // TODO test
    var slideLag = \slideLag.kr(0);
    var slide = \slide.kr(0, slideLag);

    // TODO test
    var geneSizeLag = \geneSizeLag.kr(0);
    var geneSize = (\geneSize.kr(1, geneSizeLag) * (rate.abs)).clip(0.001, 1); // Gene size is rate independent

    // TODO Connect once morph is implemented (at least for gene shift)
    var useExtClock = \useExtClock.kr(0).clip(0, 1);
    var extClock = \extClock.tr(0) * useExtClock;

    var inIndex = \index.kr(0);
    var indexBuf = \indexBuf.ir(0);

    var playGate = \playGate.kr(0);
    var envLag = \envLag.kr(0.005);

    // Last sample was end of slice?
    var endOfSplice = LocalIn.ar(1);
    // Trigger at end of splice (when play gate is high) or when play gate becomes high
    var trigger = Changed.ar(endOfSplice + playGate) * playGate;

    // TODO Use 2 buffers and crossfade to fix pops
    // Sample and hold splice index and read start / end sample number
    var index = Latch.ar(K2A.ar(inIndex), trigger);
    var start = BufRd.ar(1, indexBuf, index, 0, 1);
    var endRd = BufRd.ar(1, indexBuf, index+1, 0, 1);
    var end = start + (endRd-start) * geneSize;

    // Adjust for play direction
    var resetPos = (start*(rate>=0)) + (end*(rate<0));
    var phasor = Phasor.ar(trigger, rate, start-1, end+1, resetPos).clip(start, end);
    var bufPos = (phasor + slide).wrap(start, end);

    var envOffset = envLag * rate.abs * BufSampleRate.ir(audioBuf);
    var env = bufPos.linlin(start, start+envOffset, 0, 1) * bufPos.linlin(end-envOffset, end, 1, 0);

    var sig = BufRd.ar(2, audioBuf, bufPos);
    var pos = (bufPos - start) / (end - start);
    pos = Select.ar(rate>0, [1-pos, pos]);

    // Adjust for play direction
    LocalOut.ar(
        ((phasor>=(end-1))*(rate>=0))
        + ((phasor<=(start+1))*(rate<0))
    );

    Out.ar(posBus, pos);
    Out.ar(audioBus, sig * env * amp * playGate);
}).add;
)

(s.waitForBoot({
    var previous;
    var bufferContentPath = thisProcess.nowExecutingPath.dirname ++ "/../assets/recordings/SC_230904_105002.wav";

    s.freeAll;
    s.newBusAllocators;
    Buffer.freeAll;
    s.sync;

    ~posBus = Bus.audio(s, 1);
    ~buf = Buffer.read(s, bufferContentPath/*, 0, 48000 * 10*/); // Only the first 10 sec
    s.sync;

    // Create splices position array
    previous = 0;
    // ~splices = [0] ++ Array.rand(20, 5000, ~buf.numFrames-5000).sort ++ [~buf.numFrames.asInteger];
    ~splices = Array.interpolation(20, 0, ~buf.numFrames).asInteger;
    ~indexBuf = Buffer.loadCollection(s, ~splices);
    s.sync;

    /*
    // Create the synth
    ~synth = Synth(\player1, [buf: ~buf, posBus: ~posBus]);
    ~splices = (~splices.size - 1).collect {|i| [~splices[i], ~splices[i+1]]};
    s.sync;

    // Pick a splice at random and wait for it to be done before picking another one
    { loop {
        var index = rrand(0, ~splices.size-1);
        var rate = [rrand(0, 26.midiratio) * -1, rrand(0, 12.midiratio)].choose;  // Values from morphagene manual
        var duration = (~splices[index][1] - ~splices[index][0]) / (~buf.sampleRate * rate.abs.max(0.25)); // Retrigger at the end of a sample but don't let samples run for too long
        s.bind {
            ~synth.set(\start, ~splices[index][0], \end, ~splices[index][1], \trigger, 1, \rate, rate);
        };
        ('new slice duration: ' ++ duration ++ ' rate: ' ++ rate).postln;
        duration.wait;
    }}.fork;

    ~posBus.scope;
    */

    ~synth = Synth(\player2, [audioBuf: ~buf, posBus: ~posBus, indexBuf: ~indexBuf, playGate: 1, rateLag: 0, amp: 0.dbamp]);
    s.sync;
    { loop {
        var index = rrand(0, ~indexBuf.numFrames-2);
        var duration = rrand(1, 5);
        var prevRate = 1;
        3.do {
            // var rate = [rrand(0, 26.midiratio) * -1, rrand(0, 12.midiratio)].choose;  // Values from morphagene manual
            var rate = [[-24, -12, -5, 0, 7, 12, 19, 24].choose.midiratio*(-1), [-24, -12, -5, 0, 7, 12].choose.midiratio].choose;
            var rateDiff = (rate - prevRate).abs;
            s.bind { ~synth.set(\index, index, \rate, rate, \rateLag, rateDiff * 0.02) };
            (duration * 0.33).wait;
        }
    }}.fork;
});)

({
    var p = Phasor.ar(end: 1000);
    [p.linlin(0, 1000, 0, 1), p.linlin(0, 100, 0, 1) * p.linlin(1000-100, 1000, 1, 0)];
}.plot(0.05))