// set up the synth
(
SynthDef(\sine, {
    |freq=440, rel=1, amp=0.02, out=0|
    var detune = LFNoise2.kr(5!5).bipolar(0.13);
    var sig = SinOsc.ar(freq + detune);
    var env = Env.perc(releaseTime: rel).kr(2);
    sig = Splay.ar(sig);
    Out.ar(out, sig * env * amp);
}).add;

SynthDef(\tapeDelay, {
    |duration=1, /*delayTime=0.5, */feedback=0.8, wowFreq=3, flutterFreq=0.2, in=0|
    var input, output, wow, flutter;
    var delayBuf, frames, delayRead, delayWrite;

    // create a delay buffer
    delayBuf = LocalBuf(s.sampleRate * duration, 2).clear;
    frames = delayBuf.numFrames;

    // add wow and flutter to the delay time
    wow = LFTri.kr(wowFreq, 0).unipolar(0.0005);
    flutter = LFTri.kr(flutterFreq, 0).unipolar(0.000125);
    delayTime = delayTime + wow + flutter;

    input = In.ar(in, 2);

    delayWrite = Phasor.ar(0, 1, 0, frames);
    delayRead = Wrap.ar(delayWrite - (delayTime*s.sampleRate), 0, frames);

    // write to the delay buffer
    output = Mix([input, BufRd.ar(2, delayBuf, delayRead, interpolation: 4) * feedback.clip(0, 1)]);
    BufWr.ar(output, delayBuf, delayWrite);
    Out.ar(0, output);
}).add;
)

Synth(\tapeDelay, [feedback: 0.99, duration: 2, delayTime: 1], addAction: 'addToTail');
Synth(\sine, [rel: exprand(0.25, 3), freq: ([0, 3, 5, 7, 10].choose + 60).midicps]);
