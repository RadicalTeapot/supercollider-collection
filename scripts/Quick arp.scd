(
SynthDef(\pad,{
    arg out=0,amp=1.0,attack=0.5,decay=0.5,note=60,ring=0.5,emit=0.5;
    var snd;
    var start=Impulse.kr(0);
    var freq=note.midicps;
    var env_main = EnvGen.ar(Env.perc(attack,decay),doneAction:2);
    var duration=attack+decay;

    var env = EnvGen.kr(Env.linen(
        Rand(0,duration*100)/100,
        Rand(0,duration*100)/100,
        (Rand(0,duration*100)/100*10),
        Rand(0.2,1.0) ));

    freq = Vibrato.kr(freq,LFNoise1.kr(1).range(1,4),0.005,1.0,1.0,0.95,0.1);

    // Cap the reverberation time at 1s to avoid booming low frequencies.
    snd = DynKlank.ar(`[[freq],[env],[ring]], PinkNoise.ar([0.1,0.1]))/(2*(ring.sqrt + 0.01));
    snd = SelectX.ar(
        SelectX.kr(2*emit, [0, VarLag.kr(LFNoise0.kr(1/4),4,warp:\sine).range(0.2,0.7), 1]),
        [snd,LPF.ar(SinOsc.ar(freq*2)*env,1000,4)],
    );

    snd=Pan2.ar(snd,VarLag.kr(LFNoise0.kr(1/5),5,warp:\sine).range(-0.75,0.75));
    snd=(snd/20)*amp;
    snd=snd.tanh*env_main;

    DetectSilence.ar(snd,0.001,2,doneAction:2);
    Out.ar(out,snd);
}).add;

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

SynthDef(\mixer, {
    |in=0, out=0, dlayTime=0.66, dcayTime=3, roomSize=0.8, dlayBlend=0.33, verbBlend=0.33|
    var sig, dlay, verb;
    sig = In.ar(in, 2);
    dlay = CombL.ar(sig, 10, dlayTime, dcayTime);
    dlay = HPF.ar(dlay, 1000);
    sig = sig.blend(dlay, dlayBlend);
    verb = FreeVerb2.ar(sig[0], sig[1], 1, roomSize);
    verb = MoogFF.ar(HPF.ar(verb, 300), 5000);
    sig = sig.blend(verb, verbBlend);
    ReplaceOut.ar(out, sig);
}).add;

~scale = Scale.dorian.degrees;
~roots = [0, 1, -2, -3];
Pbind(
    \instrument, \voice,
    \index, Pseq((0..5), inf),  // Used in Pfunc calls later
    \dur, Pseq([0.5, 0.25, 0.25, 0.25, 0.75], inf),
    \midinote, Pn(Plazy({  // Randomize arp order every time the whole sequence is run x number of times
        var arp = [0] ++ (2,4..8).scramble;  // Always start with root and a random note order after than
        var chordDegrees = ~roots +.x arp;
        PdegreeToKey(Pseq(chordDegrees, rrand(2, 8)), ~scale) + [48, 60].wchoose([0.8, 0.2]);
    })),
    \amp, 1.0 - (Pexprand(0.1, 0.5, inf) * Pfunc({|event| event.index / 5})), // First note always full amp, randomly decrease after that
    \rel, Pkey(\dur) + Pexprand(0.01, 0.1, inf),
    \envReal, Pkey(\rel) * Pwhite(0.5, 1.0, inf),
    \filterEnvAmp, Pkey(\freq) * Pwhite(0.1, 0.2, inf),
    \cutoff, Pkey(\freq) * Pmeanrand(0.6, 0.8, inf),
    \pan, Pbrown(-1, 1, 0.1, inf) * Pfunc({|event| event.index / 5}),  // First note is always centered, further diverge after that
).play;


Pbind(
    \instrument, \pad,
    \dur, Prand([4, 8], inf),
    \note, Pwrand(36 +.x [0, 7], [0.8, 0.2], inf), // root and 5th
    \amp, Pexprand(0.3, 0.5, inf),
    \attack, Pkey(\dur) * Pexprand(0.1, 0.3, inf),
    \decay, Pkey(\dur) - Pkey(\attack),
).play;


Pmono(
    \mixer,
    \dlayTime, 0.33,
    \dcayTime, 3,
    \roomSize, 0.85,
    \dlayBlend, 0.4,
    \verbBlend, 0.4,
    \addAction, 1  // Add to tail
).play;
)