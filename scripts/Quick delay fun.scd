(
ServerTree.removeAll;

~init = {
    s.bind({
        ~synthGroup = Group.new();
        ~repitchGroup = Group.tail();
        ~fxGroup = Group.tail;

        ~delay = Synth(\delay, [dur: 3.02, feedback: 0.5, in:~synthBus, out:~delayBus, amp: 2], ~fxGroup);

        ~mix = {
            var synth = In.ar(~synthBus, 2);
            var delay = HPF.ar(In.ar(~delayBus, 2), 500);
            var sig = synth.blend(delay, 0.33);
            var verb = HPF.ar(LPF.ar(FreeVerb2.ar(sig[0], sig[1], 1, 0.8), 1500), 60);
            var repitch = In.ar(~repitchBus, 2);
            sig = sig.blend(verb, 0.2) + repitch;
            ReplaceOut.ar(0, sig);
        }.play(~fxGroup, addAction: 'addToTail');
    });
};

s.newBusAllocators;
~synthBus = Bus.audio(s, 2);
~delayBus = Bus.audio(s, 2);
~repitchBus = Bus.audio(s, 2);

~sortByOccurence = {
    // Sort array by decreasing number of occurences
    |values = #[]|
    if (values.size > 0) {
        values = values.sort({|a, b| values.occurrencesOf(a) > values.occurrencesOf(b)});
    } {
        values
    };
};

s.waitForBoot({
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    ~notesBuf = Buffer.loadCollection(s, ~sortByOccurence.([0,3,5,7,10,0,3,7,0,7,0,0]));
    ~octavesBuf = Buffer.loadCollection(s, ~sortByOccurence.([0,0,0,12,12,-12]));

    SynthDef(\playNote, {
        |notebuf, octbuf, prob=1, rel=1, amp=0.1, root=60, cf=20000, pwm=0.5, out=0|
        var note, env, sig, frames, cutoff, detune;

        note = root;
        note = note + Index.kr(notebuf, Rand(0, prob * BufFrames.ir(notebuf)));
        note = note + Index.kr(octbuf, Rand(0, prob * BufFrames.ir(octbuf)));
        note = note.midicps;

        detune = LFNoise2.kr(5!5).bipolar(-0.13);
        detune = detune * note.linlin(0, 2000, 1, 1.1);

        sig = VarSaw.ar(note + detune, width: pwm);

        cutoff = cf + (Env.perc(0, rel * 0.5).kr() * 100) + (note * 0.25);
        sig = MoogFF.ar(sig, cutoff.clip(20, 20000));

        env = Env.perc(releaseTime: rel).kr(2);
        sig = sig * amp * env;
        sig = Splay.ar(sig, 0.1);

        Out.ar(out, sig);
    }).add;

    SynthDef(\delay, {
        |dur, feedback, in, out, amp|
        var buf = LocalBuf.new(dur * s.sampleRate, 2).clear;
        var sig = In.ar(in, 2);
        var tapA, tapB;
        RecordBuf.ar(sig, buf, 0, 1, feedback);
        tapA = PlayBuf.ar(2, buf, loop: 1);
        tapB = PlayBuf.ar(2, buf, startPos: BufFrames.ir(buf) * 0.5, loop: 1);
        Out.ar(out, (Pan2.ar(tapA, -0.75) + Pan2.ar(tapB, 0.75)) * amp);
    }).add;

    SynthDef(\repitchDelay, {
        |dur, rate, pan, in, out, amp|
        var buf = LocalBuf.new(dur * s.sampleRate, 2).clear;
        var sig = In.ar(in, 2);
        var tap;
        RecordBuf.ar(sig, buf, loop: 0);
        tap = PlayBuf.ar(2, buf, rate, doneAction: 2);
        tap = Pan2.ar(tap, pan);
        Out.ar(out, tap * amp);
    }).add;

    s.sync;

    ServerTree.add(~init);
    ServerTree.run;

    s.sync;

    Pdefn(\prob, 1);

    ~lead = Pbind(
        \instrument, \playNote,
        \dur, Prand([
            Pseq([0.25, 0.5, Rest(0.25)], {rrand(1, 4)}),
            Pseq([0.75, 0.25], {rrand(1, 4)}),
            Pseq([Rest(0.5), 0.25, 0.25], {rrand(1, 4)}),
        ], inf),
        \rel, Pwhite(0.33, 1, inf),
        \notebuf, ~notesBuf,
        \octbuf, ~octavesBuf,
        \root, 48,
        \amp, 0.5,
        \cf, Pexprand(400, 2500, inf),
        \pwm, Pmeanrand(0.1, 0.9, inf),
        \prob, Pdefn(\prob),
        \group, ~synthGroup,
        \out, ~synthBus,
    );

    ~repitch = Pbind(
        \instrument, \repitchDelay,
        \dur, Pwrand([2, 4, Rest(4)], [1, 1, 5].normalizeSum, inf),
        \rate, Prand([0.5, 0.25], inf),
        \amp, Pexprand(0.25, 0.66, inf),
        \in, ~synthBus,
        \out, ~repitchBus,
        \group, ~repitchGroup,
    );
});
)

(
Pdefn(\prob, Pdup(16, Pseq([1, 0.66, 1, 1, 0.5, 0.33], inf)));
~lead.play;
~repitch.play;
)

~octavesBuf.setn(0, ~sortByOccurence.([0,0,12,12,-12,24]));