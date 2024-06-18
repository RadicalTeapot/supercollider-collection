(
~bowl1 = {
    |freq=261, pan=0|
    var sig, exc;
    exc = PinkNoise.ar() * Env.perc(0.01, 0.03).ar();
    sig = Klank.ar([
        `[[530, 1430, 2550, 3130], [-20, -34.5, -52.5, -79.8].dbamp, [20, 10, 7, 4]],
        `[[532, 1440, 2550, 3120, 3672], [-20, -25.5, -53.5, -85.8, -72.2].dbamp, [20, 10, 7, 4]],
    ], exc, freq/530) * (-1.5).dbamp;
    sig = sig * SinOsc.kr(5 * Rand(0.9, 1.2), [0, pi * Rand(0.9, 1.1)]).range(0.3, 1);
    DetectSilence.ar(sig, doneAction: Done.freeSelf);
    Balance2.ar(sig[0], sig[1], pan);
})

(
~bowl2 = {
    var sig, hitEnv, env, lfo;
    sig = SinOsc.ar([187.5, 515.625, 984.375, 1312.5]);
    lfo = SinOsc.ar([2.14, 4.919, 6.339, 0.5], phase: pi/2).range(0.5, 1);
    env = Env.perc(releaseTime: [20.8, 54.417, 34.88, 1.13]).ar();
    hitEnv = Env.perc(releaseTime: 0.5).ar().dup(4);
    sig = sig * (env + hitEnv) * lfo * [0.207, 0.116, 0.014, 0.006] * 3;
    Splay.ar(sig.scramble, 0.5);
};
~bowl2.play;
)

(
Routine { loop {
    var note = (Scale.minorPentatonic.semitones + 52).performDegreeToKey(rrand(0, 12));
    var time = [1,2,4,8].choose;
    var pan = exprand(0.5, 1) * [-1, 1].choose;
    ~bowl1.play(args: [freq: note.midicps, pan: pan]);
    time.yield;
}}.play)