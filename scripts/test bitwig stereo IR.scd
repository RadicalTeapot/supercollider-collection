(
CmdPeriod.run;
s.waitForBoot {
    var irLeft, irRight;
    var fftsize = (2**13).asInteger; // Higher values reduces CPU usage but increases delay between signal and convolved response
    Buffer.freeAll;

    s.sync;

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
        var irBufs = \irBufs.ir(#[0, 1]);
        var dryWet = \dryWet.kr(0.33);
        var wetAmp = \wetAmp.kr(0.05);
        var out = \out.ir(0);
        var sig = In.ar(in, 2);
        sig = sig.blend(PartConv.ar(sig, fftsize, irBufs, wetAmp), dryWet);
        sig = Compander.ar(sig, sig, 0.4, 1, 5.reciprocal, 0.005, 0.1);
        sig = sig.blend(CombL.ar(sig.rotate, 2, 1, 3), 0.15);
        sig = Compander.ar(sig, sig, 0.05, 1, 0.8, 1, 5);
        ReplaceOut.ar(out, sig);
    }).add;
    s.sync;

    fork {
        var ir, irInLeft, irInRight, bufsize, path;
        path = "C:/Users/mathi/AppData/Local/_data/recordings/Impulse responses/Saint Peter's Cathedral Saintes - Bitwig.wav";
        // path = "C:/Users/mathi/AppData/Local/_data/recordings/Impulse responses/Aluminium Foil - Bitwig.wav";
        #irInLeft, irInRight = [Buffer.readChannel(s, path, channels: 0), Buffer.readChannel(s, path, channels: 1)];
        s.sync;

        bufsize = PartConv.calcBufSize(fftsize, irInLeft);
        irLeft = Buffer.alloc(s, bufsize, 1);
        irLeft.preparePartConv(irInLeft, fftsize);

        bufsize = PartConv.calcBufSize(fftsize, irInRight);
        irRight = Buffer.alloc(s, bufsize, 1);
        irRight.preparePartConv(irInRight, fftsize);
        s.sync;

        irInLeft.free;
        irInRight.free;
        NetAddr.localAddr.sendMsg('/irLoadingDone');
    };

    OSCFunc({
        var fx;
        s.bind { fx = Synth(\fx, [irBufs: [irLeft, irRight], dryWet: 0.33, wetAmp: -36.dbamp]) };
        Routine {
            loop {
                var count = rrand(2, 17); // How many notes in a burst
                var restTime = count / 4 + rrand(0, 3); // How long to wait between bursts, longer for longer bursts
                var speed = [2, 4, 8].choose.reciprocal; // Base interval size for each burst
                var root = [36, 48, 60].choose; // Root note for each burst
                var width = rrand(4, 12); // How many degrees for the variation
                var next = 0;
                count.do {
                    var time = [1, 2].choose * speed;
                    var offset = rrand(0, 0.02);
                    var note = (Scale.minorPentatonic.performDegreeToKey(next) + root).midicps;
                    var amp = (rrand(-12, -6) - 3).dbamp;
                    var pan = exprand(0.001, 1) * [-1, 1].choose;
                    var pw = exprand(0.5, 1);
                    next = (
                        next + (
                            exprand(1, 3).asInteger      // Jump in halfsteps or steps
                            * [0, 1].wchoose([0.2, 0.8]) // 20% chance to repeat last note
                    )).fold(width * -0.5, width * 0.5);  // Bounce between top and bottom of range
                    offset.yield;
                    if (0.8.coin) {
                        s.bind { Synth.before(fx, \pluck, [
                            freq: note, detune: 0.1, pw: pw, dur: time, cf: 500, cfEnvAmt: 0.5, rq: 0.5, amp: amp, pan: pan]) };
                    };
                    (time - offset).yield;
                };
                restTime.yield;
            }
        }.play;
    }, '/irLoadingDone');
}
)