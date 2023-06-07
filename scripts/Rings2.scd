~useAudioInterface.();

(
s.waitForBoot({
    var baseMelodyStream, basePadStream;

    // From here https://github.com/schollz/l_ll__l_/blob/main/lib/Engine_EmissionSpectrum.sc
    SynthDef("klank",{
        arg out=0,in,amp=1.0,attack=0.5,decay=0.5,note=60,ring=0.5,emit=0.5;
        var snd;
        var start=Impulse.kr(0);
        var freq=note.midicps;
        var env_main = EnvGen.ar(Env.perc(attack,decay),doneAction:2); //*EnvGen.ar(Env.new([1,1,0],[40,2]),start,doneAction:2);
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
        dlay = HPF.ar(dlay, 2500);
        sig = sig.blend(dlay, dlayBlend);
        verb = FreeVerb2.ar(sig[0], sig[1], 1, roomSize);
        verb = MoogFF.ar(HPF.ar(verb, 300), 5000);
        sig = sig.blend(verb, verbBlend);
        ReplaceOut.ar(out, sig);
    }).add;

    s.sync;

    Pdefn(\attack, Pexprand(0.5, 2));
    Pdefn(\decay, Pwhite(2, 10));
    basePadStream = Pbind(
        \instrument, \klank,
        \dur, Prand([0.5, 1.5, 3.5], inf),
        \note, Pn(Pdup(Pwhite(1, 5), Pshuf([24,36] +.x Scale.minorPentatonic.degrees, 1))),
        \amp, 0.5,
        \attack, Pdefn(\attack),
        \decay, Pdefn(\decay),
        \ring, Pwhite(0.5, 0.9),
        \emit, Pwhite(0.25, 0.5)
    );
    ~pad = Ppar([
        basePadStream,
        Pbind(
            \note, Pn(Pdup(Pwhite(1, 5), Pshuf(48 + Scale.minorPentatonic.degrees, 1))),
            \dur, Prand([0.5, 1, Rest(1), Rest(3)], inf),
            \amp, 0.33,
            \attack, Pdefn(\attack) * 0.5,
            \decay, Pdefn(\decay) * 0.5,
        ) <> basePadStream,
    ]);

    baseMelodyStream =  Pbind(
        \instrument, \voice,
        \dur, Pseq([Prand([0.125, 0.25, 0.5], {rrand(4, 8)}), Prand([Rest(4), Rest(8), Rest(16)])], inf),
        \midinote, Pn(Pdup(Pwhite(1, 3), Pshuf(Scale.minorPentatonic.degrees + 72))),
        \cutoff, Pkey(\freq) * 0.85,
        \filterEnvAmp, Pkey(\freq) * 0.5,
        \rel, Pexprand(0.25, 0.5, inf),
        \pan, Pmeanrand(-0.75, 0.25, inf),
        \amp, Pexprand(0.5, 2, inf)
    );
    ~melody = Ppar([
        baseMelodyStream,
        Pbind(
            \midinote, Pn(Pdup(Pwhite(1, 3), Pshuf(Scale.minorPentatonic.degrees + 60))),
            \cutoff, Pkey(\freq) * 0.75,
            \filterEnvAmp, Pkey(\freq) * 0.25,
            \envRel, Pkey(\rel) * 0.85,
            \pan, Pmeanrand(-0.25, 0.75, inf),
        ) <> baseMelodyStream,
    ]);

    Pdefn(\dlayTime, 0.66);
    Pdefn(\dcayTime, 3);
    Pdefn(\roomSize, 0.85);
    Pdefn(\dlayBlend, 0.4);
    Pdefn(\verbBlend, 0.4);
    ~mixer = Pmono(
        \mixer,
        \dlayTime, Pdefn(\dlayTime),
        \dcayTime, Pdefn(\dcayTime),
        \roomSize, Pdefn(\roomSize),
        \dlayBlend, Pdefn(\dlayBlend),
        \verbBlend, Pdefn(\verbBlend),
        \addAction, 1  // Add to tail
    );
});
)

(
~pad.play;
~melody.play;
~mixer.play;

Pdefn(\dlayTime, 0.75);
Pdefn(\dcayTime, 5);
Pdefn(\roomSize, 0.9);
)