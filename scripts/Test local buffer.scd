(
SynthDef(\test, {|dur, amp|
    var notes = ([-24, -12] +.x Scale.minorPentatonic.degrees).midiratio;
    var maxDur = 3;
    var readRate = TChoose.kr(1, notes);

    var buf = LocalBuf(s.sampleRate * maxDur, 1).clear;
    var writePhasor = Phasor.ar(0, BufRateScale.ir(buf), 0, BufFrames.ir(buf));
    var readPhasor = Phasor.ar(0, BufRateScale.ir(buf) * readRate, 0, BufFrames.ir(buf));
    var env = Env.perc(0.05, dur - 0.05).kr(2);
    var sig;

    BufWr.ar(SinOsc.ar(440) * amp, buf, writePhasor);
    sig = BufRd.ar(1, buf, readPhasor, 1, 4);
    sig = sig * env;
    sig = Pan2.ar(sig, 0);
    Out.ar(0, sig);
}).add;
)

(
a = Pbind(\instrument, \test, \dur, Pwhite(0.25, 1.0, inf), \db, Pwhite(-12.0, -6.0, inf));
b = a.play;
)
b.stop;