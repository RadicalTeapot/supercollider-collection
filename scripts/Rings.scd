(
s.waitForBoot({
    SynthDef(\voice, {
        |freq=440, amp=0.1, time=1.0, ring=0.5, out=0|
        var env = Env.linen(
            sustainTime: Rand(0.0, time),
            releaseTime: Rand(0.0, time)).kr();
        var sig = DynKlank.ar(`[[freq, freq*2, freq*3], [env, env*0.5, env*0.25], [ring, ring*0.25, ring*0.25*0.25]], Impulse.ar(0) * 0.1);
        sig = sig * amp;
        DetectSilence.ar(sig, time: 2, doneAction: 2);
        Out.ar(out, sig!2);
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

    Pdefn(\dur, Prand([0.25, 0.5, 1, Rest(0.5)], inf));
    Pdefn(\note, 60);
    Pdefn(\ring, 0.5);
    Pdefn(\time, 1);
    Pdefn(\amp, 0.1);
    ~seq = Pbind(
        \instrument, \voice,
        \dur, Pdefn(\dur),
        \midinote, Pdefn(\note),
        \ring, Pdefn(\ring),
        \time, Pdefn(\time),
        \amp, Pdefn(\amp),
    );

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
~seq.play;
~mixer.play;
)
(
Pdefn(\dur, Prand([0.25, 0.5, 1, Rest(0.5)], inf) * 0.5);
Pdefn(\ring, Pwhite(0.25, 0.99, inf));
Pdefn(\time, Pexprand(2.0, 5.0, inf));
Pdefn(\amp, Pexprand(0.5, 1, inf));
Pdefn(\note, Pn(Pdup(Pwhite(2, 4), Pshuf((0,12..24) +.x Scale.minorPentatonic.degrees + 48, 1))));
)
(
Pdefn(\dlayTime, 0.75);
Pdefn(\dcayTime, 5);
Pdefn(\roomSize, 0.9);
)