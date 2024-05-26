// preparation; essentially, allocate an impulse response buffer, then
// follow a special buffer preparation step to set up the data the plugin needs.
(
~irspectrum.free;
~fftsize = 2048;

s.waitForBoot {
    {
        var ir, irbuffer, bufsize;
        irbuffer = Buffer.readChannel(s, "~/Downloads/IR tidy living room clean.wav".standardizePath, channels: [0]);
        s.sync;
        bufsize = PartConv.calcBufSize(~fftsize, irbuffer);
        // ~numpartitions= PartConv.calcNumPartitions(~fftsize, irbuffer);

        ~irspectrum = Buffer.alloc(s, bufsize, 1);
        ~irspectrum.preparePartConv(irbuffer, ~fftsize);

        s.sync;

        irbuffer.free; // don't need time domain data anymore, just needed spectral version
    }.fork;
}
)

({
    var sig, trig, out;
    trig = Impulse.ar(2);
    sig = LFPulse.ar(Demand.ar(trig, 0, Dxrand([48, 60, 64, 67, 69, 72].midicps, inf)) * (LFNoise2.ar([0.2, 0.5, 2.33]).range(-0.1, 0.1).midiratio));
    sig = RLPF.ar(sig, (EnvGen.ar(Env([0, 1,0], [0, 0.1]), trig) * LFNoise2.ar(0.273).range(3000, 4000) + 50).clip(50, 20000), 0.5);
    sig = sig * Env.perc(releaseTime: 0.25).ar(0, trig);
    sig = (sig * 2).tanh;
    sig = sig.sum;
    sig = sig.blend(PartConv.ar(sig, ~fftsize, ~irspectrum.bufnum, 0.3), 0.01);
    sig = Pan2.ar(sig, Demand.ar(trig, 0, Dwhite(-0.5, 0.5, inf)));
    sig = CombL.ar(sig, 2, 1/3, 3);
    sig = sig + (NHHall.ar(sig, 1) * -12.dbamp);
    out = Limiter.ar(sig) * -3.dbamp;
    out;
}.play)