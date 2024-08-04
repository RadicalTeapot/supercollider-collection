({
    var sig = (PinkNoise.ar(1!2) * WhiteNoise.ar(1!2) * -4.dbamp) + (PinkNoise.ar(1!2) * -2.dbamp);
    var lfo1 = FSinOsc.kr(0.05);
    var lfo2 = FSinOsc.kr(0.01 + lfo1.range(0, 0.1));
    sig = BPF.ar(sig, 500 * (LFNoise2.kr(lfo2.exprange(0.025, 0.1)!2).unipolar(0.25).midiratio), lfo1.range(0.5, 0.8)) * sqrt(lfo1.range(0.75, 1));
    sig * -6.dbamp;
}.play;

a = {
    |note=60|
    var mod = FSinOsc.kr(4.514);
    var freq = note.lag(0.2).midicps * LFNoise2.kr(3.0492!5).bipolar(0.1).midiratio * mod.bipolar(0.3).midiratio;
    var sig = VarSaw.ar(freq);
    sig = MoogFF.ar(sig, (200 + note.lag(0.5).midicps) * mod.bipolar(0.25).midiratio);
    Splay.ar(sig.scramble);
}.play;

fork { loop {
    var time = [1, 2, 4, 8].choose;
    var note = Scale.minorPentatonic.semitones.choose + 48;
    time.yield;
    s.bind { a.set(\note, note) };
}};
)