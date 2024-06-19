(
var scale, root;

scale = Scale.minorPentatonic.semitones;
root = 50;

~pan = {
    |freq = 440, pan = 0, amp = 0.5|
    var sig, lfo;
    sig = Resonz.ar(
        WhiteNoise.ar()!2 * Env.perc(releaseTime: 0.05).ar(),
        [300, 440, 600, 700, 900, 1200] / 300 * freq, // * Array.rand(6, 0.05, 0.1).midiratio,
        Line.ar(0.002, (1 / [1, 0.5, 1.5, 0.8, 0.7, 2]) * 0.001, 0.01).lincurve(0.00001, 0.002, 0.00001, 0.002, [2, 8, 4, 4, 2, 8] * 0.25)
    );
    lfo = SinOsc.ar([2, 5, 6, 6.5, 7] * Array.rand(6, 0.99, 1.01), pi/2).range([0.5, 0.66, 0.66, 0.66, 0.8, 0.9], 1);
    sig = sig * 2000 * amp * [1.0, 0.02, 0.075, 0.05, 0.15, 0.01].squared * lfo;
    DetectSilence.ar(sig.sum, 0.01, doneAction: Done.freeSelf);
    Splay.ar(sig.scramble, 0.5, center: pan);
};

fork { loop {
    var note = scale.performDegreeToKey((0..7).choose + 1) + root;
    var time = [1, 2, 4, 8].choose * 0.25;
    var pan = exprand(0.1, 0.5) * [-1, 1].choose;
    ~pan.play(args: [freq: note.midicps, pan: pan]);
    time.yield;
}};
)