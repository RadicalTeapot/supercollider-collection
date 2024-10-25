(
CmdPeriod.run;
s.waitForBoot {
    var looperCount, looperBuffers, inGroup, looperGroup, fxGroup, postFxGroup, delayBuf, hitBufs, gongBufs;
    var audioBuses, levelBuses;
    var mixStrip = "utils/mix strip.scd".resolveRelative.load;
    var replyName = '/trigger';
    var root = 36;
    var notes = [0, 12, 19, 24, 28, 31, 38, 48 ]; // Add9
    var freqs = [8, 4, 2, 2, 1, 1, 1, 1].reciprocal;
    looperCount = 8;

    Buffer.freeAll;
    s.newBusAllocators;
    s.sync;

    looperBuffers = looperCount.collect { Buffer.alloc(s, 16 * s.sampleRate) };
    inGroup = Group.new;
    looperGroup = Group.after(inGroup);
    fxGroup = Group.after(looperGroup);
    postFxGroup = Group.after(fxGroup);
    delayBuf = Buffer.alloc(s, s.sampleRate * 2, 2);
    hitBufs = 3.collect { |i|
        Buffer.read(s, "C:/Users/Mathias/AppData/Local/_data/Recordings/Cleaned/wood hits/Hit"+(i+1)+"clean.wav");
    };
    gongBufs = ["Hit hard - F2", "Regular hit - F2", "Ring long - F2"].collect {|name| Buffer.read(s, "C:/Users/Mathias/AppData/Local/_data/Recordings/Cleaned/gong/thai gong/"++name++".wav") };
    s.sync;

    SynthDef(\triggerer, {
        var freq = \freq.kr(1);
        var phase = \phase.kr(0);
        var triggerId = \triggerId.ir(0);

        var rate = freq / SampleRate.ir;
        var phasor = Phasor.ar(rate: rate) + phase % 1;

        SendReply.ar(phasor - rate, replyName, [triggerId]);
    }).add;

    SynthDef(\pad, {
        var freq = \freq.kr(440);
        var detune = \detune.kr(0.01); // In semitones
        var tremolo = \tremolo.kr(0.01); // In semitones
        var pw = \pw.kr(0.5).clip(0, 1);
        var cf = \cf.kr(20000).clip(20, 20000);
        var atk = \atk.kr(0.01);
        var rel = \rel.kr(1);
        var dur = \dur.kr(1);
        var pan = \pan.kr(0).clip(-1, 1);
        var amp = \amp.kr(0.5);
        var vibrato = \vibrato.kr(0.2).clip(0, 1);
        var out = \out.ir(0);

        var tremoloFreq = Rand(3.0, 4.5);
        var vibratoFreq = Rand(3.0, 4.5);

        var sig = Pulse.ar(freq * LFNoise1.kr(3!5).bipolar(detune).midiratio * SinOsc.kr(tremoloFreq).bipolar(tremolo).midiratio, pw);
        sig = MoogFF.ar(sig, cf);
        sig = sig * Env.perc(atk , rel).ar(Done.freeSelf, timeScale: dur);
        sig = Splay.ar(sig, 0.5, center: pan);
        sig = sig * amp * SinOsc.ar(vibratoFreq).range(1 - vibrato, 1);
        Out.ar(out, sig);
    }).add;

    SynthDef(\bass, {
        var trig = \trig.tr(0);
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
        var cfEnv = Env.perc(filtAtk, filtRel, filtEnvAmp).kr(Done.none, trig, timeScale: dur);
        var filtAmp = (rq+1).reciprocal.sqrt;
        sig = RLPF.ar(sig, (cf + cfEnv).clip(20, 20000), rq) * filtAmp;
        sig = sig + sub;
        sig = sig.blend((sig*2).tanh, satBlend);
        sig = sig * Env.perc(atk, rel).ar(Done.none, trig, timeScale: dur);
        sig = Pan2.ar(sig, pan) * amp;
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

    SynthDef(\woodHits, {
        var speed = \speed.kr(1);
        var freq = \freq.kr(15);
        var atk = \atk.kr(0.01);
        var rel = \rel.kr(1.0);
        var hitRel = \hitRel.kr(0.05);
        var dur = \dur.kr(1);
        var trig = \trig.tr(0);
        var buf = \buf.kr(0);
        var amp = \amp.kr(1);
        var cf = \cf.kr(20000);
        var pan = \pan.kr(0);
        var out = \out.ir(0);

        var trigs = Impulse.ar(freq);
        var envs = Env.perc(0.01, hitRel).ar(Done.none, trigs);
        var sig = PlayBuf.ar(2, buf, speed, trigs, loop: 0);
        sig = BPF.ar(sig, cf.clip(20, 20000));
        sig = sig * envs * Env.perc(atk, rel).ar(Done.none, trig, timeScale: dur);
        sig = Balance2.ar(sig[0], sig[1], pan);
        sig = sig.blend(CombL.ar(sig.rotate, 0.25, 0.25, 5), 0.2);
        sig = sig * amp;
        Out.ar(out, sig);
    }).add;

    SynthDef(\gong, {
        var buf = \buf.kr(0);
        var speed = \speed.kr(0);
        var amp = \amp.kr(1);
        var pan = \pan.kr(0);
        var out = \out.ir(0);

        var sig = PlayBuf.ar(2, buf, speed, doneAction: Done.freeSelf);
        sig = sig * amp * Line.ar(dur: 0.01);
        sig = Balance2.ar(sig[0], sig[1], pan);
        Out.ar(out, sig);
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

    // Start triggering synths
    s.bind { notes.do { |note, i|
        Synth(\triggerer, [triggerId: i, freq: (freqs[i] + rrand(-0.01, 0.01)) * 0.03, phase: exprand(0.001, 1.0)]);
    }};

    // Play pad when trigger is received
    OSCFunc({|msg|
        var index = msg[3].asInteger;
        s.bind { Synth(\pad, [freq: (root + notes[index]).midicps, atk: rrand(1.0, 5.0), rel: (index+1).reciprocal*rrand(10.0, 20.0), cf: exprand(200, 2000), amp: (index/8+1).reciprocal * 0.25, pan: rrand(-1.0, 1.0), width: exprand(0.5, 0.95)], inGroup) };
    }, replyName);

    // Play wood hits
    Routine {
        var waitTime = 7;
        var synths;
        s.bind{ synths = [postFxGroup, inGroup].collect {|target| Synth(\woodHits, target: target) } };
        loop {
            var note = [84, 96].wchoose([0.33, 0.66]);
            var speed = (note - 99.5).midiratio; // Speed was tuned for 1st hit, do so for other hits
            var buf = hitBufs.choose;
            var amp = rrand(-20, -12);
            var pan = rrand(0, 0.5);
            var cf = rrand(1000, 3000);
            var rel = rrand(1.2, 1.8);
            var hitRel = rrand(0.05, 0.15);
            s.bind { synths.do { |synth, i|
                synth.set(
                    \trig, 1,
                    \speed, speed,
                    \buf, buf,
                    \amp, (amp - (i*1.5)).dbamp,
                    \pan, pan,
                    \cf, cf / ((i+1) * 2), // over 1 for post fx and over 4 for fx
                    \rel, rel,
                    \hitRel, hitRel
                )
            }};
            waitTime.yield;
        };
    }.play;

    // Play gong
    Routine {
        var waitTime = 24;
        loop {
            var choice = [(note: 36, amp: -6), (note: 48, amp: -9)].choose;
            var speed = (choice.note - 53).midiratio;
            var amp = (choice.amp + rrand(0, -6)).dbamp;
            s.bind { Synth(\gong, [buf: gongBufs.choose, speed: speed, amp: amp, pan: rrand(-0.5, 0)], postFxGroup) };
            waitTime.yield;
        };
    }.play;

    // Play bass
    Routine {
        var note = 48;
        var waitTime = 16;
        var bass;
        s.bind { bass = Synth(\bass, [freq: note.midicps, cf:40, rq: 0.5, atk: 0.25, filtAtk: 0.5, filtEnvAmp: 100, dur: waitTime, amp: -20.dbamp], postFxGroup) };
        loop {
            s.bind { bass.set(\trig, 1) };
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