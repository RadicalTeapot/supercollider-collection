(
s = Server.default;
s.waitForBoot {
    s.free;
    s.sync;

    SynthDef(\kick, {
        var freq, amp, decay, pan, out;
        var env, fmEnv, osc, sig;

        freq = \freq.kr(32.7); // C1
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.5);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).ar(Done.freeSelf);
        fmEnv = Env.perc(releaseTime: decay).kr(timeScale: 0.4).linlin(0,1,0.9, 1.1);
        osc = SinOsc.ar(freq * fmEnv);
        sig = osc * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    a = {  
        var trig = \trig.tr(0);
        var env = Env.perc.ar(Done.none, trig, timeScale: 0.5);
        var freq = \freq.kr(55) * [1,2,3] * LFNoise2.ar(20!3).range(env.linlin(0, 1, 0.99, 0.9), env.linlin(0, 1, 1.01, 1.1));
        var amps = (0 - [0, 6, 30]).dbamp * \amp.kr(-6.dbamp) * LFNoise2.ar(10!3).range(env.linlin(0, 1, 0.8, 0.66), env.linlin(0, 1, 1.2, 1.33));
        var sig = SinOsc.ar(freq) * amps * env.dup.linlin(0,1,0.9,1);
        Pan2.ar(Mix.ar(sig));
    }.play;

    Routine { loop {
        [33, 30, 28, 30, 26, 30, 28].do {|note|
            s.bind { a.set(\freq, note.midicps, \amp, -6.dbamp, \trig, 1); Synth(\kick, [amp: -3.dbamp, freq: 55, decay: 1]); };
            5.wait;
    } }
    }.play;
};
)

(
{
    var sig = WhiteNoise.ar.dup;
    sig = HPF.ar(sig, 1200);
    sig = LPF.ar(sig, 4000);
    sib = LPF.ar(sig, 4000);
    sig * -24.dbamp;
}.play;
)
