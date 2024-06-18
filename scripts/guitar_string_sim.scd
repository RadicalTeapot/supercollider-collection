(
~useDevice = {
    |inDeviceName = "JackRouter", outDeviceName = "JackRouter", prefix = "ASIO", inChannels = 4, outChannels = 4, blockSize=1024|
    var serverOptions = Server.default.options;
    serverOptions.inDevice_(prefix ++ " : " ++ inDeviceName);
    serverOptions.outDevice_(prefix ++ " : " ++ outDeviceName);
    serverOptions.numInputBusChannels_(inChannels);
    serverOptions.numOutputBusChannels_(outChannels);
    serverOptions.blockSize_(blockSize);
    Server.default.reboot;
};
~useJACK = {
    |inChannels = 4, outChannels = 4, blockSize=1024|
    ~useDevice.("JackRouter", "JackRouter", "ASIO", inChannels, outChannels, blockSize);
};
~useJACK.(2,2, 4096);
)

(
~naiveFFT = {
    |points, count|
    count.collect{
        |i|
        var real, imag;
        real = 0;
        imag = 0;
        points.do {
            |v, j|
            var angle = 2 * pi * i * (j.asFloat / points.size);
            real = real + (v * cos(angle));
            imag = imag - (v * sin(angle));
        };
        (real.squared + imag.squared).sqrt;
    }
};

~getPoints = {
    |pos, count=100|
    var ipos = (pos * count).asInteger;
    count.collect({|i| if(i<ipos, i.asFloat/ipos, (count-i).asFloat / (count-ipos)) });
};

SynthDef(\guitar, {
    var freq, decay, out, amplitudes, overtones, duration, pan; // Input variables
    var frequencies, fastDecay, slowDecay; // Internal variables
    var sig, fastEnvs, slowEnvs; // UGens

    freq = \freq.kr(164.81); // E3
    decay = \decay.kr(5);
    duration = \duration.kr(1);
    out = \out.ir(0);
    amplitudes = \amplitudes.kr((0.1).dup(12));
    pan = \pan.kr(0);
    overtones = \overtones.kr((1..12));

    frequencies = freq * overtones;
    fastDecay = (frequencies.squared * (decay * 4.0 * 10e-7) * -1).exp; // Quadratic damping
    slowDecay = (frequencies.squared * (decay * 1.0 * 10e-7) * -1).exp; // Quadratic damping

    Env.perc(releaseTime: duration * 1.1).kr(Done.freeSelf); // To cleanup the synth

    sig = SinOsc.ar(frequencies);
    fastEnvs = Env.perc(releaseTime: duration * fastDecay).ar(Done.none) * 0.33;
    slowEnvs = Env.perc(releaseTime: duration * slowDecay).ar(Done.none) * 0.66;
    sig = sig * amplitudes * (fastEnvs + slowEnvs);
    sig = (sig.sum * 2).tanh * 0.75;
    sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
}).add;

SynthDef(\bowl, {
    var freq, pan, amp, out;
    var sig, exc;
    freq = \freq.kr(261);
    pan = \pan.kr(0);
    amp = \amp.kr(-6.dbamp);
    out = \out.ir(0);

    exc = PinkNoise.ar() * Env.perc(0.01, 0.03).ar();
    sig = Klank.ar([
        `[[530, 1430, 2550, 3130], [-20, -34.5, -52.5, -79.8].dbamp, [20, 10, 7, 4]],
        `[[532, 1440, 2550, 3120, 3672], [-20, -25.5, -53.5, -85.8, -72.2].dbamp, [20, 10, 7, 4]],
    ], exc, freq/530) * amp;
    sig = sig * SinOsc.kr(5 * Rand(0.9, 1.2), [0, pi * Rand(0.9, 1.1)]).range(0.3, 1);

    DetectSilence.ar(sig, doneAction: Done.freeSelf);
    Balance2.ar(sig[0], sig[1], pan);
    Out.ar(out, sig);
}).add;

SynthDef(\fx, {
    var sig;
    sig = In.ar(\out.kr(0), 2);
    sig = sig + (NHHall.ar(sig, 1) * -6.dbamp);
    sig = Limiter.ar(sig);
    ReplaceOut.ar(\out.kr(0), sig);
}).add;
)

(
var patterns;
var scale, root;
var degreeToFreq;

scale = Scale.minorPentatonic.semitones;
root = 40;  // E2

degreeToFreq = {|degree|
    var midinote;
    midinote = root + scale[degree % scale.size] + (12 * degree.div(scale.size)); // .div is integer division
    midinote.midicps;
};

patterns = [
    (type: \notes, pan: -0.5, \notes: [0, \, \]),
    (type: \notes, pan: 0.5, \notes: [0, \, 3, 2, \, \, 0]),
    (type: \random, pan: 0, \notes: (2..10) ++ (\).dup(10)),
    (type: \bowl, \notes: (0..12) + 12)
];

s = Server.default;
Synth.tail(s, \fx);

patterns.do { |data, i|
    Routine { loop {
        var time, freq, amp, pos, duration, pan;
        var pointCount, amplitudes;

        switch(data.type,
            \notes, { data.notes.do { |note|
                if (note != \) {
                    time = rrand(0.5, 1.5);
                    amp = rrand(0.33, 0.9) * 1.5;
                    pos = rrand(0.6, 0.7);
                    duration = rrand(1.0, 1.5) * time.max(1.0) * 5;
                    pan = data.pan + rrand(-0.1, 0.1);
                    pointCount = 100;
                    amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
                    freq = degreeToFreq.(note);
                    s.makeBundle(s.latency, {
                        Synth(\guitar, [
                            freq: freq,
                            amplitudes: amplitudes.drop(1),
                            duration: duration,
                            pan: pan,
                            decay: 3
                        ]);
                    });
                };
                time.yield;
            }},
            \bowl, {
                var note = scale.performDegreeToKey(data.notes.choose) + root;
                var time = [1,2,4,8].choose;
                var pan = exprand(0.5, 1) * [-1, 1].choose;
                s.bind { // same as s.makeBundle(s.latency, {})
                    Synth(\bowl, [freq: note.midicps, amp: (-1.5).dbamp, pan: pan]);
                };
                time.yield;
            },
            \random, {
                var note;
                time = rrand(0.2, 1.5);
                amp = rrand(0.33, 0.9) * 1.5 * time.max(1.0);
                pos = rrand(0.7, 0.9);
                duration = rrand(1.0, 1.5) * time.max(1.0) * 2;
                pan = data.pan + rrand(-0.1, 0.1);
                pointCount = 100;
                amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
                note = data.notes.choose;
                if (note != \) {
                    freq = degreeToFreq.(note);
                    s.makeBundle(s.latency, {
                        Synth(\guitar, [
                            freq: freq,
                            amplitudes: amplitudes.drop(1),
                            duration: duration,
                            pan: pan,
                            decay: (1.5 - time) / 10.0]);
                    });
                };
                time.yield;
        });
    }}.play;
};
)