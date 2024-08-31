(
CmdPeriod.run;
s.waitForBoot {
    var looperCount, looperBuffers, inGroup, looperGroup, fxGroup, postFxGroup, delayBuf;
    var replyName = '/trigger';
    var root = 36;
    var notes = [0, 12, 19, 24, 28, 31, 38, 48 ]; // Add9
    var freqs = [8, 4, 2, 2, 1, 1, 1, 1].reciprocal;
    looperCount = 8;
    Buffer.freeAll;
    s.sync;

    looperBuffers = looperCount.collect { Buffer.alloc(s, 16 * s.sampleRate) };
    inGroup = Group.new;
    looperGroup = Group.after(inGroup);
    fxGroup = Group.after(looperGroup);
    postFxGroup = Group.after(fxGroup);
    delayBuf = Buffer.alloc(s, s.sampleRate * 2, 2);
    s.sync;

    SynthDef(\triggerer, {
        var rate = \freq.kr(1) / SampleRate.ir;
        var phasor = Phasor.ar(rate: rate) + \phase.kr(0) % 1;
        SendReply.ar(phasor - rate, replyName, [\id.ir(0)]);
    }).add;

    SynthDef(\pulse, {
        var sig = Pulse.ar(\freq.kr(440) * LFNoise2.kr(3!5).bipolar(0.01).midiratio * SinOsc.kr(Rand(3.0, 4.5)).bipolar(0.01).midiratio, \width.kr(0.5).clip(0, 1));
        sig = MoogFF.ar(sig, \cf.kr(20000).clip(20, 20000));
        sig = sig * Env.perc(\atk.kr(0.01), \rel.kr(1)).ar(Done.freeSelf, timeScale: \dur.kr(1));
        sig = Splay.ar(sig, 0.5, center: \pan.kr(0).clip(-1, 1));
        sig = sig * \amp.kr(0.5) * SinOsc.ar(Rand(3.0, 4.5)).range(0.8, 1);
        Out.ar(\out.ir(0), sig);
    }).add;

    SynthDef(\bass, {
        var freq = \freq.kr(440).max(0);
        var cf = \cf.kr(20000).clip(20, 20000);
        var atk = \atk.kr(0.01).max(0);
        var rel = \rel.kr(1).max(0);
        var dur = \dur.kr(1).max(0);
        var filtAtk = \filtAtk.kr(0.01).max(0);
        var filtRel = \filtRel.kr(1).max(0);
        var filtEnvAmp = \filtEnvAmp.kr(0).max(0);
        var rq = \rq.kr(1).clip(0.0001, 1);
        var satBlend = \satBlend.kr(0.5).clip(0, 1);
        var pan = \pan.kr(0).clip(-1, 1);
        var harmonicsAmp = \harmonicsAmp.kr(0.5);
        var subOctave = \subOctave.kr(1).max(1);
        var amp = \amp.kr(0.5).max(0);
        var out = \out.ir(0);

        var sig = Saw.ar(freq) * harmonicsAmp;
        var sub = SinOsc.ar(freq * 2.pow(subOctave).reciprocal);
        var cfEnv = Env.perc(filtAtk, filtRel, filtEnvAmp).kr(timeScale: dur);
        var filtAmp = (rq+1).reciprocal.sqrt;
        sig = RLPF.ar(sig, (cf + cfEnv).clip(20, 20000), rq) * filtAmp;
        sig = sig + sub;
        sig = sig.blend((sig*2).tanh, satBlend);
        sig = sig * Env.perc(atk, rel).ar(timeScale: dur);
        sig = Pan2.ar(sig, pan) * amp;
        DetectSilence.ar(sig, doneAction: Done.freeSelf);
        Out.ar(out, sig);
    }).add;

    SynthDef(\arp, {
        var freq = \freq.kr(440).max(20);
        var cf = \cf.kr(20000).clip(20, 20000);
        var atk = \atk.kr(0.01).max(0);
        var rel = \rel.kr(1).max(0);
        var dur = \dur.kr(1).max(0);
        var rq = \rq.kr(1).clip(0.0001, 1);
        var pan = \pan.kr(0).clip(-1, 1);
        var amp = \amp.kr(0.5).max(0);
        var delayBlend = \delayBlend.kr(0.2).clip(0, 1);
        var decayTime = \decaytime.kr(5);
        var out = \out.ir(0);

        var sig = VarSaw.ar(freq);
        var filtAmp = (rq+1).reciprocal.sqrt;
        sig = BPF.ar(sig, cf, rq) * filtAmp;
        sig = sig * Env.perc(atk, rel).ar(timeScale: dur);
        sig = Pan2.ar(sig, pan);
        sig = sig.blend(CombL.ar(sig, dur/2, dur/2, decayTime).rotate, delayBlend);
        sig = LeakDC.ar(sig);
        sig = sig * amp;
        DetectSilence.ar(sig, time: 1, doneAction: Done.freeSelf);
        Out.ar(out, sig);
    }).add;

    SynthDef(\kick, {
        var freq, amp, decay, pan, out;
        var env, fmEnv, osc, sig;

        freq = \freq.kr(32.7); // C1
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.5);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).ar(Done.freeSelf);
        fmEnv = Env.perc(releaseTime: decay).kr(timeScale: 0.4).range(0.9, 1.1);
        osc = SinOsc.ar(freq * fmEnv);
        sig = osc * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    SynthDef(\snare, {
        var freq, bpfFreq, amp, decay, pan, out;
        var env, noise, osc, sig;

        freq = \freq.kr(130.8); // C3
        bpfFreq = \bpfFreq.kr(261.6); // C5
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.2);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).ar(Done.freeSelf);
        noise = WhiteNoise.ar();
        osc = SinOsc.ar(freq);
        sig = noise + (osc * -3.dbamp);
        sig = BPF.ar(sig, bpfFreq) * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    SynthDef(\hihat, {
        var hpfFreq, amp, decay, pan, out;
        var env, noise, hpf, sig;

        hpfFreq = \hpfFreq.kr(8000);
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.1);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).ar(Done.freeSelf);
        noise = WhiteNoise.ar();
        hpf = HPF.ar(noise, 8000);
        sig = hpf * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(0, sig);
    }).add;

    SynthDef(\varLooper, {
        var sig;

        var id = \id.ir(0);
        var refreshRate = \refreshRate.kr(30);

        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var minAmp = \minAmp.kr(-60.dbamp);
        var maxAmp = \maxAmp.kr(-6.dbamp);
        var ampLfoFreq = \ampLfoFreq.kr(0.1);
        var recLfoFreq = \recLfoFreq.kr(0.1);
        var reverseLfoFreq = \reverseLfoFreq.kr(0.1);
        var posLfoFreq = \posLfoFreq.kr(0.1);
        var panLfoFreq = \panLfoFreq.kr(0.1);
        var posLfoFeedback = \posLfoFeedback.kr(0);
        var readPhasorSpeedsBuf = LocalBuf.newFrom(\readPhasorSpeed.ir([0.25, 4, 0.5, 2, 1])); // Curved LFO favors higher indices
        var readPhasorSpeedLfoFreq = \readPhasorSpeedLfoFreq.kr(0.1);
        var recGateDurationLfoFreq = \recGateDurationLfoFreq.kr(10);
        var fadeTime = \fadeTime.kr(0.02);

        var input = In.ar(in);
        var localIn = LocalIn.ar(2);
        var feedback = localIn[0];
        var phasorFeedback = localIn[1];

        var bufDur = BufDur.kr(buf);
        var bufRateScale = BufRateScale.kr(buf);
        var bufFrames = K2A.ar(BufFrames.kr(buf));

        var startPosLfo = SinOsc.kr(posLfoFreq + feedback * posLfoFeedback);
        var reverseLfo = LFPulse.kr(reverseLfoFreq).lag(0.05).linlin(0, 1, -1, 1);
        var panLfo = SinOsc.kr(panLfoFreq);
        var readPhasorSpeedLfo = LFSaw.kr(readPhasorSpeedLfoFreq);
        var ampLfo = VarSaw.kr(ampLfoFreq).unipolar.lincurve(0, 1, minAmp, maxAmp).clip(0, 1);

        var recTrig = Impulse.ar(recLfoFreq);
        var gateDuration = SinOsc.ar(recGateDurationLfoFreq).range(4 * fadeTime, bufDur.min((2*recLfoFreq).reciprocal)); // 16 is buf duration
        var recGate = Trig1.ar(recTrig, gateDuration); // Get duration is held until the next trigger so we can use a sine here
        var readGate = 1 - recGate;

        var lastFrame = Latch.ar(phasorFeedback, readGate);
        var loopPoint = Select.ar((lastFrame > 0) * readGate, [bufFrames, lastFrame]);

        var readSpeedBufIndex = Latch.kr(readPhasorSpeedLfo.unipolar.lincurve * BufFrames.ir(readPhasorSpeedsBuf), readGate);
        var readPhasorSpeed = Index.ar(readPhasorSpeedsBuf, readSpeedBufIndex);
        var startPos = Latch.kr(startPosLfo.unipolar(loopPoint * 0.95), readGate);

        var readPhasor = Phasor.ar(Changed.ar(readGate), bufRateScale * reverseLfo * readPhasorSpeed, end: loopPoint, resetPos: startPos);
        var recPhasor = Phasor.ar(Changed.ar(recGate), rate: bufRateScale, end: loopPoint, resetPos: -1);

        var amp = ampLfo * (readPhasorSpeed*2+1).sqrt.reciprocal * readGate.lag(fadeTime);

        var prevSig = BufRd.ar(1, buf, recPhasor) * readGate;
        var recSig = SelectX.ar(recGate.slew(fadeTime.reciprocal, fadeTime.reciprocal), [prevSig, input]);
        BufWr.ar(recSig, buf, recPhasor);

        sig = BufRd.ar(1, buf, readPhasor, interpolation: 4) * amp;
        sig = Pan2.ar(sig, panLfo);

        LocalOut.ar([K2A.ar(startPosLfo), recPhasor]);
        SendReply.kr(Impulse.kr(refreshRate), '/update', [id, recGate, loopPoint / bufFrames, readPhasor / bufFrames, recPhasor / bufFrames, amp, panLfo.unipolar]);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var in = \in.ir(0);
        var out = \out.ir(0);
        var buf = \buf.ir(0);
        var sndIn = \sndIn.ir(0);

        var phasor = Phasor.ar(rate: BufRateScale.ir(buf), end: BufFrames.ir(buf));
        var tapeWobble = LFNoise2.ar(2!2).lincurve(-1, 1, 0, BufSampleRate.ir(buf) * 0.004, 10);
        var tapeDelay = BufRd.ar(2, buf, (phasor + tapeWobble).wrap(0, BufFrames.ir(buf)), interpolation: 4);
        var sig = In.ar(in, 2).blend(tapeDelay, 0.5);
        var rev = NHHall.ar(sig, 4, 0.15);

        // Back to tape delay with some hiss, crackles and saturation
        var tapeCrackle = BPF.ar(PinkNoise.ar(1!2) * WhiteNoise.ar(1!2), 2000, 0.75) * LFNoise2.kr(0.5!2).linlin(-1, 1, -36.dbamp, -24.dbamp);
        var tapeHiss = BPF.ar(PinkNoise.ar(1!2), LFNoise1.kr(2.3587!2).linlin(-1, 1, 2000, 4000), 0.95);
        sig = sig.tanh;
        RecordBuf.ar(LPF.ar(HPF.ar(sig, 50), 10000), buf, recLevel: 1, preLevel: -36.dbamp);
        sig = sig.blend(tapeHiss, 0.025) + tapeCrackle;

        sig = sig.blend(rev, 0.5);
        sig = Compander.ar(sig, sig, 0.4, 1, 5.reciprocal, 0.005, 0.5);
        ReplaceOut.ar(out, sig);
    }).add;
    s.sync;

    OSCFunc({|msg|
        var index = msg[3].asInteger;
        s.bind { Synth(\pulse, [freq: (root + notes[index]).midicps, atk: rrand(1.0, 5.0), rel: (index+1).reciprocal*rrand(10.0, 20.0), cf: exprand(200, 2000), amp: (index/8+1).reciprocal * 0.25, pan: rrand(-1.0, 1.0), width: exprand(0.5, 0.95)], inGroup) };
    }, replyName);

    s.bind { notes.do { |note, i|
        Synth(\triggerer, [freq: (freqs[i] + rrand(-0.01, 0.01)) * 0.03, id: i, phase: exprand(0.001, 1.0)]);
    }};

    // Play bass
    Routine {
        var note = 48;
        var waitTime = 16;
        loop {
            s.bind { Synth(\bass, [freq: note.midicps, cf:40, rq: 0.5, atk: 0.25, filtAtk: 0.5, filtEnvAmp: 100, dur: waitTime, amp: -20.dbamp], postFxGroup) };
            waitTime.yield;
        };
    }.play;

    // Play arp
    Routine {
        var getNotes = {|root=36, count=6|
            ([0, 12, 24] +.x Scale.majorPentatonic.semitones).scramble[0..count] + root;
        };

        var cf = 200;
        var amp = -12;
        var notes = getNotes.();
        var waitTime = 1/3;
        loop {
            cf = (cf + (exprand(10, 200) * [-1, 1].choose)).clip(20, 400);
            amp = (amp + (exprand(0.5, 2) * [-1, 1].choose)).clip(-48, -12);
            notes.do { |note|
                s.bind { Synth(\arp, [freq: note.midicps, cf: cf, dur: waitTime*4/3, amp: amp.dbamp], postFxGroup) };
                waitTime.yield;
            };
            if (0.05.coin) { notes = getNotes.() };
            if (0.15.coin) { notes = notes.rotate(rrand(-3, 3)) };
        }
    }.play;

    // Play drums
    Routine {
        var beat = 0;
        loop {
            s.bind {
                if ((beat == 0) || (beat == 4) || (beat == 7)) { Synth(\kick, [amp: -6.dbamp], target: postFxGroup) };
                if ((beat == 2) || (beat == 6)) { Synth(\snare, [amp: -18.dbamp], target: postFxGroup) };
                Synth(\hihat, [amp: -30.dbamp], target: postFxGroup);
            };
            beat = (beat + 1) % 8;
            0.5.yield;
        }
    }.play;

    looperCount.do {|i|
        var recLfoFreq = exprand(0.01, 0.2);
        var reverseLfoFreq = exprand(0.08, 0.2);
        var startPosLfoFreq = exprand(0.1, 0.3);
        var posLfoFeedback = (0.1).coin;
        var panLfoFreq = exprand(0.1, 0.3);
        var phasorSpeedLfoFreq = exprand(0.1, 0.75);
        var ampLfoFreq = exprand(0.03, 0.2);

        Synth(\varLooper, [
            id: i,
            in: i%2, // 2 loopers for left channel and 2 for right channel
            buf: looperBuffers[i],
            recLfoFreq: recLfoFreq,
            reverseLfoFreq: reverseLfoFreq,
            posLfoFreq: startPosLfoFreq,
            posLfoFeedback: posLfoFeedback, //if (i==0) {100} {0},
            panLfoFreq: panLfoFreq,
            readPhasorSpeedLfoFreq: phasorSpeedLfoFreq,
            ampLfoFreq: ampLfoFreq,
            maxAmp: -12.dbamp,
            minAmp: -36.dbamp,
        ], looperGroup);
    };
    Synth.tail(fxGroup, \fx, [out: 0, buf: delayBuf]);
};
)