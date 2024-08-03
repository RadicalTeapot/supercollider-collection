(
s.waitForBoot {
    Buffer.freeAll;
    s.sync;

    ~delayBuf = Buffer.alloc(s, s.sampleRate * 1.5/8, 2); // dotted 8th delay buffer
    s.sync;

    SynthDef(\basic, {
        |freq=440, detune=0.1, cf=20000, rq=0.75, atk=0.025, rel=1, dur=1, amp=1, pan=0, width=0.1, out=0|
        var freqs = freq * LFNoise2.ar(3!5).bipolar(detune).midiratio;
        var sig = Saw.ar(freqs);
        var env = Env.perc(atk.max(0), rel.max(0)).kr(Done.freeSelf, timeScale: dur);
        sig = RLPF.ar(sig, cf.clip(20, 20000), rq.clip(0.0001, 1)) * rq.sqrt.reciprocal;
        sig = sig * env * amp;
        sig = Splay.ar(sig, width, center: pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var sig = In.ar(\in.ir(0), 2);
        var buf = \buf.ir;
        var dlay = PlayBuf.ar(2, buf, loop: 1);
        sig = sig.blend(dlay, 0.5);
        sig = LPF.ar(sig, 5000);
        sig = LeakDC.ar(sig);
        RecordBuf.ar(sig, buf);
        sig = sig.blend(NHHall.ar(sig, 2), 0.33);
        ReplaceOut.ar(\out.ir(0), sig);
    }).add;
    s.sync;

    ~hs = HarmonySequencer.new(s);
    ~hs.gui(30, true);
}
)

(
s.bind {
    ~fxGroup = Group.tail(s);
    s.sync;
    // Synth(\fx, [buf: ~delayBuf], ~fxGroup)
};
~hs.registerPointTriggerAction({ |pointIdx, note|
    s.bind { Synth(\basic, [freq: note.midicps, cf: 150, dur:0.25, atk:0.1, rel:3, pan: rrand(-0.5, 0.5), amp: 0.75]) };
});
)

~hs.free;