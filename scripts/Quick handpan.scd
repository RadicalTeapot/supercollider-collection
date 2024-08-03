MIDIClient.init;
m = MIDIOut(0, MIDIClient.destinations.at(2).uid);
m.noteOn(1, 50, 60);
m.noteOff(1, 50, 60);
m.allNotesOff(1);
(
var scale, root;

scale = Scale.lydian.semitones;
root = 50;

~pan = {
    |freq = 440, pan = 0, amp = 0.5|
    var sig, lfo;
    sig = Resonz.ar(
        WhiteNoise.ar()!2 * Env.perc(releaseTime: 0.05).ar(),
        [150, 300, 440, 600, 700, 900, 1200] / 300 * freq, // * Array.rand(6, 0.05, 0.1).midiratio,
        Line.ar(0.002, (1 / [2, 1, 0.5, 1.5, 0.8, 0.7, 2]) * 0.001, 0.01).lincurve(0.00001, 0.002, 0.00001, 0.002, [4, 2, 8, 4, 4, 2, 8] * 0.25)
    );
    lfo = SinOsc.ar([1, 2, 2, 5, 6, 6.5, 7] * Array.rand(6, 0.99, 1.01), pi/2).range([0.2, 0.5, 0.66, 0.66, 0.66, 0.8, 0.9], 1);
    sig = sig * 2000 * amp * [0.2, 1.0, 0.02, 0.075, 0.05, 0.15, 0.01].squared * lfo;
    DetectSilence.ar(sig.sum, 0.01, doneAction: Done.freeSelf);
    Splay.ar(sig.scramble, 0.5, center: pan);
};

~panRoutine = Routine { loop {
    var note = scale.performDegreeToKey((0..7).choose + 1) + root;
    var time = [1, 2, 4, 8].choose * 0.25;
    var pan = exprand(0.1, 0.5) * [-1, 1].choose;
    ~pan.play(args: [freq: note.midicps, pan: pan]);
    // m.noteOn(1, note, 100);
    time.yield;
    // m.noteOff(1, note, 0);
}};
)

(
~bowl = {
    |freq=261, pan=0, amp=1|
    var sig, exc;
    exc = PinkNoise.ar() * Env.perc(0.01, 0.03).ar();
    sig = Klank.ar([
        `[[530, 1430, 2550, 3130], [-20, -34.5, -52.5, -79.8].dbamp, [20, 10, 7, 4]],
        `[[532, 1440, 2550, 3120, 3672], [-20, -25.5, -53.5, -85.8, -72.2].dbamp, [20, 10, 7, 4]],
    ], exc, freq/530) * (-1.5).dbamp;
    sig = sig * SinOsc.kr(5 * Rand(0.9, 1.2), [0, pi * Rand(0.9, 1.1)]).range(0.3, 1);
    DetectSilence.ar(sig, doneAction: Done.freeSelf);
    Balance2.ar(sig[0], sig[1], pan) * amp;
};

~bowlRoutine = Routine { loop {
    var note = ([ 0.0, 4.0, 6.0, 9.0, 11.0 ] + 50 + 12).performDegreeToKey(rrand(0, 12));
    var time = [1,2,4,8].choose;
    var pan = exprand(0.5, 1) * [-1, 1].choose;
    ~bowl.play(args: [freq: note.midicps, pan: pan, amp: -6.dbamp]);
    time.yield;
}};
)

({
    var clock = TempoClock(80/60);
    ~panRoutine.play(clock, 4);
    ~bowlRoutine.play(clock, 2);
}.();

{ // Bass drone
    var sig;
    sig = Saw.ar(38.midicps * LFNoise2.kr(0.33.dup(5)).range(-0.1, 0.1).midiratio);
    sig = MoogFF.ar(sig, (
        38.midicps
        + LFNoise2.ar(0.1.dup(5)).range(-50, 200)
        + EnvGen.ar(Env.perc(10, 50).range(0, 600), Dust.ar(0.033))
    ).clip(20, 20000), 1);
    sig = Splay.ar(sig, 0.25).blend(SinOsc.ar(26.midicps)!2, 0.2);
    sig = sig.blend(NHHall.ar(sig, 10, lowFreq: 33), 0.25);
    sig * 0.33;
}.play;
)