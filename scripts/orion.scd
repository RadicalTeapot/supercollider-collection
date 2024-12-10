(
s = Server.default;
s.waitForBoot {
    var metronome = TempoClock.new(130/60, -1);
    s.free;
    s.sync;

    SynthDef(\kick, {
        var freq, amp, decay, pan, out;
        var env, fmEnv, osc, sig;

        freq = \freq.kr(41); // E1
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.5);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(Done.freeSelf);
        fmEnv = Env.perc(releaseTime: decay).kr(Done.none, timeScale: 0.4).range(0.9, 1.1);
        osc = SinOsc.ar(freq * fmEnv);
        sig = osc * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    SynthDef(\snare, {
        var freq, bpfFreq, amp, decay, pan, out;
        var env, noise, osc, sig;

        freq = \freq.kr(164); // E3
        bpfFreq = \bpfFreq.kr(1320); // E6
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.2);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(Done.freeSelf);
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

        env = Env.perc(releaseTime: decay).kr(Done.freeSelf);
        noise = WhiteNoise.ar();
        hpf = HPF.ar(noise, 8000);
        sig = hpf * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    SynthDef(\guitar, {
        var freq, cf, amp, atk, rel, dur, out;
        var sig;
        freq = \freq.kr(440);
        cf = \cf.kr(20000);
        atk = \atk.kr(0.01);
        rel = \rel.kr(1);
        dur = \dur.kr(1);
        amp = \amp.kr(-6.dbamp);
        out = \out.ir(0);

        freq = freq + LFNoise2.kr(0.1!2).bipolar(1);
        sig = (Saw.ar(freq)*0.8)+(Pulse.ar(freq*0.5)*0.2);
        //sig = Saw.ar(freq);
        sig = LPF.ar(sig, cf.clip(20, 20000));
        sig = LPF.ar(sig, (cf*2).clip(20, 20000));
        sig = (sig*3).tanh * 0.5;
        sig = sig * Env.perc(atk, rel).kr(Done.freeSelf, timeScale: dur);
        sig = Splay.ar(sig, 1) * amp;
        Out.ar(out, sig);
    }).add;

    {
        loop {
            s.bind { Synth(\kick, [amp: 0.dbamp]) };
            2.wait;
        }
    }.fork(metronome);

    {
       1.wait;
       loop {
           s.bind { Synth(\snare, [amp: -6.dbamp]) };
           2.wait;
       }
    }.fork(metronome);

    {
        loop {
            [
                (pattern: [0,0,0,0,7,\], rep:1),
                (pattern: [0,0,0,0,9,\], rep:1),
                (pattern: [0,0,0,0,10,\], rep:1),
                (pattern: [0,0,0,0,0,\], rep:1),
                (pattern:[0,0,1,\], rep: 1),
                (pattern:[1,1,0,\], rep: 1),
                (pattern: [0,0,0,0,10,\], rep:1),
                (pattern: [0,0,0,0,9,\], rep:1),
                (pattern: [0,0,0,0,7,\], rep:1),
                (pattern: [0,0,0,0,0,\], rep:1),
                (pattern:[0,0,1,\], rep: 1),
                (pattern:[1,1,0,\], rep: 1),
            ].do { |ev|
                ev.rep.do { ev.pattern.do { |n|
                    if (n != \) { s.bind { Synth(\guitar, [amp: 3.dbamp, freq: (40+n).midicps, dur: 0.2, cf:1000]) } };
                    0.25.wait;
                } }
            }
        }
    }.fork(metronome);

    {
        loop {
            [
                (pattern: [0,0,0,0], notes: [0,0,0,0], dur:0.25, amp:-18.dbamp),
                (pattern: [0], notes: [[7,16]], dur:(0.25*6), amp: -6.dbamp),
                (pattern: [0], notes: [[0,9]], dur:(0.25*6), amp: -6.dbamp),
                (pattern: [0], notes: [[10,19]], dur:(0.25*8), amp: -6.dbamp),
                (pattern: [\], notes: [0], dur:(0.25*8), amp: -6.dbamp),
                (pattern: [0,0,0,0], notes: [0,0,0,0], dur:0.25, amp: -18.dbamp),
                (pattern: [0], notes: [[10,19]], dur:(0.25*6), amp: -6.dbamp),
                (pattern: [0], notes: [[0,9]], dur:(0.25*6), amp: -6.dbamp),
                (pattern: [0], notes: [[7,16]], dur:(0.25*8), amp: -6.dbamp),
                (pattern: [\], notes: [0], dur:(0.25*8), amp: -6.dbamp)
            ].do { |ev|
                ev.pattern.do { |p, i|
                    if (p != \) {
                        s.bind {
                            ev.notes.do { |n| Synth(\guitar, [amp: ev.amp, freq: (40+n).midicps, dur:
                                ev.dur, cf:4000]) }
                        };
                    };
                    ev.dur.wait;
                }
            }
        }
    }.fork(metronome);
}
)
