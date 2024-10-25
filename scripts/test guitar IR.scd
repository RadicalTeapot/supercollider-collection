(
s = Server.default;
CmdPeriod.run;
s.waitForBoot {
    var ir, length, kernelSize, channels, sound;

    s.free;
    Buffer.freeAll;
    s.sync;

    // Load to use with convolver
    ir = Buffer.read(s, "C:/Users/Mathias/AppData/Local/_data/Recordings/IR/Marshall MF280B SE4400a C 6 0 6.wav");
    s.sync;
    length = 2.pow(ir.numFrames.log2Ceil).asInteger;
    kernelSize = (length/2).asInteger;
    channels = ir.numChannels.asInteger;
    ir.free;
    ir = Buffer(s, length, channels);
    ir.allocRead("C:/Users/Mathias/AppData/Local/_data/Recordings/IR/Marshall MF280B SE4400a C 6 0 6.wav");
    s.sync;
    ir.postln;

    // TODO Send it through convolution (see Convolution)
    SynthDef(\guitar, {
        var freq = \freq.kr(440);
        var sig = VarSaw.ar(freq, width: 0.1);
        // TODO Add fast env for pick
        var cf = (\cf.kr(20000) * [0.5,1,2,4] + freq.linlin(20, 20000, 0, 1000)) * Env.perc(\cfAtk.kr(0.001), \cfRel.kr(0.75), curve: [-1,-2,-3,-4]).ar(Done.none, timeScale: \dur.kr(1)).range(0.2, 1);
        sig = (LPF.ar(sig, cf.clip(20, 20000)) * 0.25).sum;
        // sig = LPF.ar(sig, (cf*1.5).clip(20, 20000));
        sig = CombL.ar(sig, freq.reciprocal, freq.reciprocal, 0.05);
        sig = sig * Env.perc(\atk.kr(0.01), \rel.kr(1), curve: -1).ar(Done.freeSelf, timeScale: \dur.kr(1));
        sig = Pan2.ar(sig, \pan.kr(0)) * \amp.kr(1);
        Out.ar(\out.ir(0), sig);
    }).add;

    SynthDef(\convolver, {
        var sig = In.ar(\in.ir(0), 2);
        var conv = Convolution2.ar(sig * \inAmp.kr(0.5), \buf.ir(0), kernelSize) * \outAmp.kr(0.5);
        sig = SelectX.ar(\mix.kr(1), [sig, conv]);
        ReplaceOut.ar(\out.ir(0), sig);
    }).add;
    s.sync;

    s.bind { ~convolver = Synth(\convolver, [in: 0, out: 0, mix: 1, buf: ir])};
    s.sync;
    Routine {
        var scale = Scale.minorPentatonic.semitones;
        loop {
            var note = ((0..12).choose + 48).nearestInScale(scale);
            var dur = rrand(0.125, 2);
            s.bind { Synth(\guitar, [freq: note.midicps, cf: 2000, dur: dur.max(0.5), amp: -12.dbamp])};
            dur.wait;
        }
    }.play;
}
)
~convolver.set(\mix, 1, \inAmp, 0.5, \outAmp, 0.5);