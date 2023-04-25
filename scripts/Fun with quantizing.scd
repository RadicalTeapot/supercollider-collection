~useJACK.();
(
ServerTree.removeAll;
~init = {};

s.newBusAllocators;
// ~synthBus = Bus.audio(s, 2);

s.waitForBoot({
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    ~notes = Buffer.loadCollection(s, Scale.minorPentatonic.degrees);

    SynthDef(\voice, {
        |degree=0, root=60, cf=20000, amp=1, detune=0, pwm=0.5, rel=1, spread=1, center=0, out=0|
        var quantized = (DegreeToKey.ar(~notes, degree) + root).midicps;
        var detuned = quantized + LFNoise2.ar(1!5).range(0,detune);
        var sig = VarSaw.ar(detuned, pwm);
        var env = Env.perc(0.05, rel).kr(2);
        sig = MoogFF.ar(sig, cf.clip(20, 20000));
        sig = Splay.ar(sig, spread, 1, center);
        Out.ar(out, sig * env * amp);
    }).add;

    s.sync;

    ServerTree.add(~init);
    ServerTree.run;

    s.sync;

    Pdefn(\baseSeq, Pseq([0,1,2,3,4], inf));
    Pdefn(\root, 60);
    Pdefn(\seqMult, 1);
    ~voice = Pbind(
        \instrument, \voice,
        \out, 0,
        \dur, Pwrand([
            Pseq([0.25, 0.25, 0.5, 1, Rest(1), 2], 1),
            Pseq([1, Rest(1), 0.5, 1.5], 1),
            Pseq([0.5, 0.5, 0.5, 0.5, 1, 1], 1),
            Rest(4)
        ], [1, 2, 3, 1].normalizeSum, inf),
        \degree, Pdefn(\baseSeq) * Pdefn(\seqMult),
        \root, Pdefn(\root),
        \detune, 5,
        \cf, 500 + Pwhite(0, 250, inf),
        \pwm, Pwhite(0, 1, inf),
        \amp, (1-Pexprand(0.001, 0.5, inf)) * 0.5,
        \spread, 0.25,
        \rel, 1,
    );
})
)

(
~baseArray = Array.fill(8, {rrand(0, 10)});
a = Routine({
    loop {
        ~baseArray.put(rrand(0, ~baseArray.size-1), rrand(0, 10));
        Pdefn(\baseSeq, Pseq(~baseArray, inf));
        "Changed a note".postln;
        rrand(10, 30).yield;
    };
}).play;
b = Routine({
    loop {
        Pdefn(\seqMult, rrand(0.5, 1.2));
        "Changed scale".postln;
        rrand(30, 60).yield;
    }
}).play;
Pdefn(\root, 60);
~voice.play;
)