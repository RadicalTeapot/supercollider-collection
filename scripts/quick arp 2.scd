(
var synth = {|freq=440, cf=20000, rq=0.8, pan=0, atk=0.01, rel=1, dur=1, amp=0.5|
    var sig = VarSaw.ar(freq);
    sig = RLPF.ar(sig, cf.clip(20, 20000), rq.clip(0.0001, 1)) * (rq.clip(0, 1)+1).reciprocal.sqrt;
    sig = sig * Env.perc(atk.max(0), rel.max(0)).ar(Done.none, timeScale: dur.max(0.0001));
    sig = Pan2.ar(sig, pan.clip(-1, 1));
    sig = sig + CombL.ar(sig, dur, dur, 5).rotate;
    sig = LeakDC.ar(sig);
    sig = sig * amp;
    DetectSilence.ar(sig, time: 1, doneAction: Done.freeSelf);
    sig;
};
var getNotes = {|root=36, count=5|
    ([0, 12, 24] +.x Scale.majorPentatonic.semitones).scramble[0..count].sort + root;
};
r = Routine {
    var cf = 400;
    var amp = -3;
    var notes = getNotes.();
    loop {
        cf = (cf + (exprand(10, 200) * [-1, 1].choose)).clip(200, 2000);
        amp = (amp + (exprand(0.5, 2) * [-1, 1].choose)).clip(-12, 6);
        notes.do { |note|
            synth.play(s, args: [freq: note.midicps, cf: cf, rel: 0.66, dur: 0.66, amp: amp.dbamp]/*, addAction: 'addToTail'*/);
            1.5.wait;
        };
        if (0.1.coin) { notes = getNotes.(count: rrand(4, 7)) };
    }
};
r.play;
)
r.stop;

s.options.memSize = 2.pow(20);