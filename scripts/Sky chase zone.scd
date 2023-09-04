(
ServerTree.removeAll;

~init = {
    ~synthGroup = Group.new();

    ~clock = TempoClock(110.0/60);

    ~mixer = {
        var sig = In.ar(~synthBus, 2);

        ReplaceOut.ar(0, sig);
    }.play(addAction: 'addToTail');
};

s.newBusAllocators;
~synthBus = Bus.audio(s, 2);

s.waitForBoot({
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    SynthDef(\voice, {
        |freq=440, rel=1, amp=0.1, cf=20000, pwm=0.5, out=0|
        var detune, sig, cutoff, env;
        detune = LFNoise2.kr(5!5).bipolar(-0.13);
        detune = detune * freq.linlin(0, 2000, 1, 1.1);

        sig = VarSaw.ar(freq + detune, width: XLine.ar(pwm, 0, rel));

        cutoff = cf + (Env.perc(0.05, rel * 0.5).kr() * 100) + (freq * 0.25);
        sig = MoogFF.ar(sig, cutoff.clip(20, 20000));

        env = Env.perc(releaseTime: rel).kr(2);
        sig = sig * amp * env;
        sig = Splay.ar(sig, 0.1);

        Out.ar(out, sig);
    }).add;

    s.sync;

    ServerTree.add(~init);
    ServerTree.run;

    s.sync;

    ~lead = Pbind(
        \instrument, \voice,
        \degree, /*Prand*/Pseq([
            Pseq([0,-2,-1,0,-1,-2,-3,-5], 1),
            Pseq([0, 0, -3, -2, 0, 0, 0], 1),
            Pseq([0, -2, 0, 1, 0, -1, -2, -3, -2, -3, -5], 1),
            Pseq([1, 2, 0], 1),
        ], inf),
        \dur, /*Prand*/Pseq([
            Pseq([Rest(1.5), Pn(0.25, 2), Pn(0.5, 4), 2], 1),
            Pseq([Rest(1), Pn(0.5, 2), Pn(0.25, 2), Rest(0.25), 2.25], 1),
            Pseq([Rest(0.5), Pn(0.25, 2), Pn(0.5, 4), Pn(0.25, 3), 3.25], 1),
            Pseq([1, 1, 2], 1),
        ], inf),
        \rel, Pkey(\dur),
        \cf, 1500,
        \group, ~synthGroup,
        \out, ~synthBus,
    );
});
)

(
~clock.beats_(-0.01);
~lead.play(~clock, quant: 1);
)