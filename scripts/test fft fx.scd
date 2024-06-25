({
    var trigger, freq, sig;
    var chain, stream;
    var fftSize, mags, lb, phases;

    trigger= Dust.kr(1);
    freq = TChoose.kr(trigger, [28, 40] +.x Scale.lydian.semitones).midicps;
    sig = Pluck.ar(WhiteNoise.ar(0.1), trigger, freq.reciprocal, freq.reciprocal, 10, 0.7) * 10;

    fftSize = 256;
    chain = FFT(LocalBuf(fftSize), sig);
    stream = UnpackFFT(chain, fftSize);

    // Only magnitudes
    mags = stream.reshape(fftSize, 2).flop[0];
    lb = LocalBuf.newFrom(mags);
    mags = mags.collect{|mag, i| WrapIndex.kr(lb, i)};

    phases = stream.reshape(fftSize, 2).flop[1];
    stream = [mags, phases].flop.flatten;

    chain = PackFFT(chain, fftSize, stream);
    Out.ar(0, IFFT(chain).dup);
}.play(s);
)