(
var sigA, bufA;
var rhythms;
sigA = Signal.sineFill(513, [1], [0]);
bufA = Buffer.loadCollection(s, sigA.asWavetableNoWrap);

b = {
    |freq=200|
    var detune, dur, blend, p, sig;
    detune = freq.lag(0.1) * LFNoise2.ar(3!2).bipolar(0.2).midiratio;
    dur = (2*detune).reciprocal;
    blend = LFNoise2.kr(2!2).range(1,4);
    // NOTE: Using an EnvGen still results in a small discontinuity when it loops,
    // I could not get rid of it completely but it's not noticable as long as we don't
    // expect to get a pure sine tone out of it when blend = 0
    p = EnvGen.ar(Env([-1,-1,0,1], [0,dur,dur], [0,blend,-1 * blend]), Impulse.ar(detune));
    sig = Shaper.ar(bufA, p).tanh * -2.dbamp;
    sig = MoogFF.ar(sig, 2 * freq * LFNoise2.kr(3!2).bipolar(2).midiratio);
    sig = sig.blend(HPF.ar(PinkNoise.ar(1!2), 3000), 0.03);
    sig = LeakDC.ar(sig) * (FSinOsc.ar(LFNoise2.ar(0.5!2).range(2, 15)).range(0.5, 0.75) + 0.25);
    sig = sig.blend(NHHall.ar(sig, 3), 0.2);
    sig = sig * -36.dbamp;
    AnalogVintageDistortion.ar(sig, 0.5, 0.1, lowgain: 0.2); // Be careful with this, it tends to blow up!
}.play;

rhythms = [
    [1,1,1,1],
    [0.25,0.25,0.5,\,\,\],
    [0.25,0.25,\,0.5,0.5,0.5,\],
];

fork { loop {
    var time = Array.geom(4, 1, 2).choose;
    var rhythm = rhythms.choose;
    var notes = (rhythm.size).collect({ rrand(36, 60).nearestInScale(Scale.lydian.semitones)}).sort;
    if (0.5.coin) {notes = notes.reverse};
    rhythm.do({|v, i|
        switch(v,
            \, {time.yield},
            {
                (v*time).yield;
                s.bind { b.set(\freq, notes[i].midicps); };
            }
        );
    });
}}.play;
)
FreqScope.new;