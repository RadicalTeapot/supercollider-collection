(
var synth = {|freq=440, cf=20000, atk=0.1, rel=1, dur=1, filtAtk=0.1, filtRel=1, filtEnvAmp=0, rq=1, amp=0.5|
    var sig = Saw.ar(freq) * -6.dbamp + SinOsc.ar(freq/2);
    sig = RLPF.ar(sig, (cf + Env.perc(filtAtk, filtRel, filtEnvAmp).ar(timeScale: dur)).clip(20, 20000), rq.clip(0.0001, 1)) * (rq.clip(0, 1)+1).reciprocal.sqrt;
    sig = sig * Env.perc(atk, rel).ar(timeScale: dur);
    sig = sig.blend((sig*2).tanh, 0.5);
    sig = sig.dup * amp;
    DetectSilence.ar(sig, doneAction: Done.freeSelf);
    sig;
};
q = Routine {
    var note = 48;
    var waitTime = 16;
    loop {
        synth.play(s, args:[freq: note.midicps, cf:40, rq: 0.5, atk: 0.25, filtAtk: 0.5, filtEnvAmp: 100, dur: waitTime, amp: -20.dbamp], addAction: 'addToTail');
        waitTime.yield;
    };
};
q.play;
)
q.stop;