(
{
    var size = 128; // FFT size
    var soundIn, soundOut, trig, fft, processedFft, ifft;
    var indexLFOs, windowStarts;

    trig = Dust.kr(0.5);
    windowStarts = Impulse.kr(50);
    soundIn = Saw.ar(TChoose.kr(trig, (Scale.minorPentatonic.semitones + 40)).midicps.lag(0.03));
    soundIn = MoogFF.ar(soundIn, 250 + Env.perc(releaseTime: 2.0).kr(0, trig).lag(0.05).range(0,1000));
    soundIn = soundIn * Env.perc(0.02, 5.0).kr(0, trig) * -2.dbamp;
    soundIn = soundIn + CombL.ar(soundIn, 2, 2, 10);
    fft = FFT(LocalBuf(size), soundIn);

    indexLFOs = size.collect{|i| FSinOsc.kr(sqrt(i+1), Rand(0, 2*pi)) * sqrt(i+1) };
    fft = fft.pvcollect(size, {| magnitude, phase, index |
        var mag = Demand.kr(windowStarts, 0, Unpack1FFT(fft, size, (index + indexLFOs[index]).clip(0, size-1), 0)).lag(0.1);
        [mag, phase]
    });

    ifft = IFFT(fft);
    soundOut = Pan2.ar(soundIn.blend(ifft, EnvGen.kr(Env([0,0,1], [0,1], 2), trig)));
    soundOut = soundOut.blend(NHHall.ar(soundOut, 2), EnvGen.kr(Env([0,0,1], [0,1], 2), trig).range(0.1, 0.5));
    soundOut;
}.play;
)