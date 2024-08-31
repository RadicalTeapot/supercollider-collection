(
var synth = {|freq=440, cf=20000, rq=0.8, pan=0, atk=0.01, rel=1, dur=1, amp=0.5|
    var sig = VarSaw.ar(freq);
    sig = RLPF.ar(sig, cf.clip(20, 20000), rq.clip(0.0001, 1)) * (rq.clip(0, 1)+1).reciprocal.sqrt;
    sig = sig * Env.perc(atk.max(0), rel.max(0)).ar(Done.none, timeScale: dur.max(0.0001));
    sig = Pan2.ar(sig, pan.clip(-1, 1));
    sig = sig.blend(CombL.ar(sig, dur/2, dur/2, 5).rotate, 0.2);
    sig = LeakDC.ar(sig);
    sig = sig * amp;
    DetectSilence.ar(sig, time: 1, doneAction: Done.freeSelf);
    sig;
};
var getNotes = {|root=36, count=5|
    ([0, 12, 24] +.x Scale.majorPentatonic.semitones).scramble[0..count] + root;
};
r = Routine {
    var cf = 200;
    var amp = -12;
    var notes = getNotes.();
    var waitTime = 0.33;
    loop {
        cf = (cf + (exprand(10, 200) * [-1, 1].choose)).clip(20, 400);
        amp = (amp + (exprand(0.5, 2) * [-1, 1].choose)).clip(-48, -6);
        notes.do { |note|
            synth.play(s, args: [freq: note.midicps, cf: cf, dur: waitTime*4/3, amp: amp.dbamp], addAction: 'addToTail');
            waitTime.yield;
        };
        if (0.05.coin) { notes = getNotes.() };
        if (0.15.coin) { notes = notes.rotate(rrand(-3, 3)) };
    }
};
r.play;
)
r.stop;