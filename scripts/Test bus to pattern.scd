(
ServerTree.removeAll;
~init = {s.bind({
    ~lfo = {
        var sig = VarSaw.kr([1/10, 1/20]).range(0, 1);
        Out.kr(~lfoBus, sig);
    }.play;
})};

s.newBusAllocators;
~lfoBus = Bus.control(s, 2);
~notes = ([48, 60] +.x Scale.minorPentatonic.degrees).scramble;

s.waitForBoot({
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    SynthDef(\voice, {
        |atk=0.01, rel=0.5, envAtk=0.05, envRel=0.2, filterEnvAmp=0, freq=440, cutoff=20000, pan=0, amp=0.5, out=0|
        var env = Env.perc(atk, rel).kr(2);
        var filterEnv = Env.perc(envAtk, envRel).kr() * filterEnvAmp;
        var sig = LFPulse.ar(freq);
        sig = MoogFF.ar(sig, (cutoff + filterEnv).clip(20, 20000), 2 + amp * 0.25);
        sig = (sig/2)*amp;
        sig = sig.tanh*env;
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig*amp);
    }).add;
    s.sync;

    ServerTree.add(~init);
    ServerTree.run;
    s.sync;

    ~voice = Pbind(
        \instrument, \voice,
        \dur, Pwrand([0.1, 0.25, Rest(0.1)], Pfunc({
            var restWeight = ~lfoBus.getnSynchronous(2)[1];  // Get from bus second channel
            [0.1, 0.05, restWeight].normalizeSum;  // The lower the bus value the more likely a note will be played
        }), inf),
        \midinote, Pfunc({
            var index = ~lfoBus.getnSynchronous(2)[0];  // Get from bus first channel
            ~notes.at(index * ~notes.size); // Use the bus value as an index into the note array
        }),
        \amp, Pexprand(0.5, 1.2, inf),
        \rel, Pexprand(0.5, 3, inf),
        \envReal, Pkey(\rel) * Pwhite(0.1, 0.5, inf),
        \filterEnvAmp, Pkey(\freq) * Pwhite(0.1, 0.2, inf),
        \cutoff, Pkey(\freq) * Pmeanrand(0.6, 0.9, inf),
        \pan, Pmeanrand(-1, 1, inf) * Pfunc({
            (1 - ~lfoBus.getnSynchronous(2)[1]).squared * 0.5;  // Get from bus second channel
        }),
    );
});
)

~lfoBus.scope;
~voice.play;
