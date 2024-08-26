(
s.waitForBoot {
    var looperBuf, xfadeRecorder, reader, looper, synth, clock, delayBuf;
    Buffer.freeAll;
    s.sync;

    looperBuf = Buffer.alloc(s, 16 * s.sampleRate, 2);
    delayBuf = Buffer.alloc(s, s.sampleRate, 2);
    s.sync;

    // MONO
    xfadeRecorder = { |in, buf, recGate, bufRateScale, loopPoint, fadeTime|
        var input = In.ar(in, 2);
        var recPhasor = Phasor.ar(Changed.ar(recGate), rate: bufRateScale, end: loopPoint, resetPos: -1);
        var prevSig = BufRd.ar(2, buf, recPhasor) * (1-recGate);
        var recSig = SelectX.ar(recGate.slew(fadeTime.reciprocal, fadeTime.reciprocal), [prevSig, input]);
        BufWr.ar(recSig, buf, recPhasor);
        recPhasor;
    };

    // MONO
    reader = { |buf, readGate, bufRateScale, loopPoint, reverse, speed, normalizedStartPos|
        var readPhasor = Phasor.ar(Changed.ar(readGate), rate: bufRateScale * reverse * speed, end: loopPoint, resetPos: normalizedStartPos * loopPoint);
        BufRd.ar(2, buf, readPhasor, interpolation: 4);
    };

    looper = { |in, out, buf, amp, speed, fadeTime, reverse, recGate, normalizedStartPos|
        var readGate = 1 - recGate;

        var phasorFeedback = LocalIn.ar(1);
        var bufRateScale = BufRateScale.kr(buf);
        var bufFrames = K2A.ar(BufFrames.kr(buf));
        var lastFrame = Latch.ar(phasorFeedback, readGate);
        var loopPoint = Select.ar((lastFrame > 0) * readGate, [bufFrames, lastFrame]);

        var recPos = SynthDef.wrap(xfadeRecorder, prependArgs: [in, buf, recGate, bufRateScale, loopPoint, fadeTime]);
        var sig = SynthDef.wrap(reader, prependArgs: [buf, readGate, bufRateScale, loopPoint, reverse, speed, normalizedStartPos]);

        LocalOut.ar(recPos);
        sig * amp * readGate.lag(fadeTime);
    };

    SynthDef(\quantizedLooper, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var amp = \amp.kr(1);
        var speed = \speed.kr(1).abs;
        var fadeTime = \fadeTime.kr(0.02).max(0.005);
        var reverse = (\reverse.kr(0) <= 0) * 2 - 1;
        var recTrigger = \recTrigger.tr(0);
        var startPos = \startPos.kr(0).clip(0, 1);
        var bpm = \bpm.kr(80);
        var clockOffset = \clockOffset.kr(0).clip(0, 1); // in beats
        var duration = \duration.kr(4).max(0.001); // in beats

        var clockFreq = bpm / 60;
        var clock = Impulse.ar(clockFreq, clockOffset);
        var quantizedTrig = 1 - SetResetFF.ar(T2A.ar(recTrigger), clock);
        var gateLength = (clockFreq.reciprocal * duration).clip(2 * fadeTime, BufDur.kr(buf));
        var recGate = Env.linen(0, gateLength, 0).ar(Done.none, quantizedTrig);

        var sig = SynthDef.wrap(
            looper,
            prependArgs: [in, out, buf, amp * (speed*2+1).sqrt.reciprocal, speed, fadeTime, reverse, recGate, startPos]
        );
        XOut.ar(out, 0.5, sig);
    }).add;

    SynthDef(\pluck, {
        var freq = \freq.kr(440);
        var pw = \pw.kr(0.5);
        var detune = \detune.kr(0.01);
        var cfEnvAmt = \cfEnvAmt.kr(0.33);
        var cf = \cf.kr(20000).clip(20, 20000);
        var rq = \rq.kr(0.75).clip(0.0001, 1);
        var atk = \atk.kr(0.05);
        var rel = \rel.kr(1);
        var dur = \dur.kr(1);
        var pan = \pan.kr(0);
        var amp = \amp.kr(1);
        var out = \out.ir(0);

        var sig = Pulse.ar(freq * LFNoise1.kr(3.5263!5).bipolar(detune).midiratio, pw);
        var env = Env.perc(atk, rel).kr(Done.freeSelf, timeScale: dur);
        var filterEnv = Env.perc(atk, rel).kr(timeScale: dur * 0.25) * cfEnvAmt + 1;
        sig = RLPF.ar(sig, (cf * filterEnv).clip(20, 20000), rq) * (rq.sqrt.reciprocal);
        sig = Splay.ar(sig.scramble, 0.33, center: pan);
        sig = sig * env * amp;
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);

        // Parameters below should be controled by GUI
        var tapeDryWet = \tapeDryWet.kr(0.33);
        var reverbDryWet = \reverbDryWet.kr(0.5);
        var hissAmp = \hissAmp.kr(-46.dbamp).clip(0, 1);
        var crackleAmp = \crackleAmp.kr(-36.dbamp).clip(0, 1);

        var phasor = Phasor.ar(rate: BufRateScale.ir(buf), end: BufFrames.ir(buf));
        var input = In.ar(in, 2);

        // Read from tape with some wobble
        var tapeWobble = LFNoise2.ar(2!2).lincurve(-1, 1, 0, BufSampleRate.ir(buf) * 0.004, 10);
        // var tapeWobble = SinOsc.ar(0.99).unipolar(0.004) * BufSampleRate.ir(0);
        var tapeDelay = BufRd.ar(2, buf, (phasor + tapeWobble).wrap(0, BufFrames.ir(buf)), interpolation: 4);

        var sig = input.blend(tapeDelay, tapeDryWet);
        // To reverb before hiss, crackles and saturation
        var rev = NHHall.ar(sig, 2, 0.5);

        // Back to tape delay with some hiss, crackles and saturation
        var tapeCrackle = BPF.ar(PinkNoise.ar(1!2) * WhiteNoise.ar(1!2), 2000, 0.75) * LFNoise2.kr(0.5!2).linlin(-1, 1, 0.25, 1);
        var tapeHiss = BPF.ar(PinkNoise.ar(1!2), LFNoise1.kr(2.3587!2).linlin(-1, 1, 2000, 4000), 0.95);
        sig = sig + (tapeHiss * hissAmp) + (tapeCrackle * crackleAmp);
        sig = sig.tanh;
        RecordBuf.ar(LPF.ar(HPF.ar(sig, 50), 10000), buf, recLevel: 1, preLevel: -24.dbamp);

        // Add reverb
        sig = sig.blend(rev, reverbDryWet);
        sig = Compander.ar(sig, sig, 0.4, 1, 5.reciprocal, 0.005, 0.5);
        ReplaceOut.ar(out, sig);
    }).add;

    SynthDef(\metronome, {
        var bpm = \bpm.kr(80);
        var out = \out.ir(0);
        var amp = \amp.kr(1);
        var release = \release.kr(0.1);

        var clockFreq = bpm/60;
        var clock = Impulse.ar(clockFreq);
        var beat = Impulse.ar(clockFreq / 4);
        var rest = clock - beat;
        var env = Env.perc(releaseTime: release);
        var sig = Pan2.ar(Mix([
            Pulse.ar(2000) * env.ar(Done.none, beat),
            Pulse.ar(1000) * env.ar(Done.none, rest) * 0.5
        ])) * amp;
        Out.ar(out, sig);
    }).add;
    s.sync;

    clock = TempoClock(60/60);
    clock.playNextBar({
        s.bind {
            synth = Synth.tail(s, \quantizedLooper, [bpm: clock.tempo * 60, buf: looperBuf]);
            Synth.tail(s, \fx, [buf: delayBuf, reverbDryWet: 0.2, tapeDryWet: 0.15]);
            // Synth.tail(s, \metronome, [bpm: clock.tempo * 60, amp: -12.dbamp, release: 0.2]);
        };
    });
    Routine {
        var next = 0;
        var root = 48;
        var scale = Scale.minorPentatonic.semitones;
        var direction = 1;
        loop {
            var time = [0.25, 0.5, 1].choose;
            var note = (next.nearestInScale(scale) + root).midicps;
            var amp = (rrand(-9, -3)).dbamp;
            var pan = exprand(0.001, 1) * [-1, 1].choose;
            var pw = exprand(0.5, 1);
            next = (
                next + (
                    [exprand(1, 3), exprand(4, 7)].wchoose([0.8, 0.2]).asInteger      // Jump in halfsteps or steps
                    * direction
                    * [0, 1].wchoose([0.2, 0.8]) // 20% chance to repeat last note
            ));
            if (0.1.coin) { direction = direction * -1 };
            if (next > 12) { direction = -1 };
            if (next < -12) { direction = 1 };
            if (0.8.coin) {
                s.bind { Synth.before(synth, \pluck, [
                    freq: note, detune: 0.03, pw: pw, dur: time, cf: 500, cfEnvAmt: 0.5, rq: 0.5, amp: amp, pan: pan]) };
            };
            time.yield;
        }
    }.play(clock);

    Routine { loop {
        var time = rrand(1, 4) * 16;
        "Record".postln;
        s.bind { synth.set(\recTrigger, 1, \speed, [1, 2, 4].wchoose([3, 2, 1].normalizeSum), \reverse, [0, 1].choose) };
        time.yield;
    } }.play(clock);
};
)