(
s = Server.default;

s.waitForBoot {
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    {
        var ir, irbuffer, bufsize, path;
        ~fftsize = 2048;

        path = thisProcess.nowExecutingPath.dirname ++ "/../assets/IR/Ovation_Celebrity_CE44_48000.wav";
        irbuffer = Buffer.readChannel(s, path, channels: [0]);
        s.sync;

        bufsize = PartConv.calcBufSize(~fftsize, irbuffer);
        ~irspectrum = Buffer.alloc(s, bufsize, 1);
        ~irspectrum.preparePartConv(irbuffer, ~fftsize);
        s.sync;

        irbuffer.free; // don't need time domain data anymore, just needed spectral version
    }.fork;
    s.sync;

    SynthDef(\guitarString, {
        var freq, decay, out, amplitudes, overtones, duration, pan, trigger; // Input variables
        var frequencies, fastDecay, slowDecay; // Internal variables
        var sig, fastEnvs, slowEnvs; // UGens

        freq = \freq.kr(164.81) + \detune.kr(0); // E3 + constant detuning for this string
        decay = \decay.kr(5);
        duration = \duration.kr(1);
        out = \out.ir(0);
        amplitudes = \amplitudes.kr((0.1).dup(12));
        pan = \pan.kr(0);
        overtones = \overtones.kr((1..12));
        trigger = \trigger.tr(0);

        frequencies = freq * overtones * (LFNoise2.kr(1.0 * overtones) * (0.033 * overtones)).midiratio; // Spectral detuning (just for fun ;)), remove to restore proper string sound
        fastDecay = (frequencies.squared * (decay * 4.0 * 10e-7) * -1).exp; // Quadratic damping
        slowDecay = (frequencies.squared * (decay * 1.0 * 10e-7) * -1).exp; // Quadratic damping

        sig = SinOsc.ar(frequencies);
        fastEnvs = Env.perc(releaseTime: duration * fastDecay).ar(Done.none, trigger) * 0.33;
        slowEnvs = Env.perc(releaseTime: duration * slowDecay).ar(Done.none, trigger) * 0.66;
        sig = sig * amplitudes * (fastEnvs + slowEnvs);
        sig = (sig.sum * 2).tanh * 0.75;
        sig = sig.blend(PartConv.ar(sig, ~fftsize, ~irspectrum.bufnum, 0.3), 0.2);
        sig = Pan2.ar(sig, pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var sig;
        sig = In.ar(\out.kr(0), 2);
        sig = sig + (NHHall.ar(sig, 1) * -6.dbamp);
        sig = Limiter.ar(sig);
        ReplaceOut.ar(\out.kr(0), sig);
    }).add;
    s.sync;
};

// Return closest value in array if value is in array, otherwise return the value itself
~getClosestValueInArray = { |value, array|
    var returnValue = nil;
    // Note we don't check bounds since the array is not assumed to be sorted
    array.slide(2, 1).pairsDo { |a, b, i|
        if ((returnValue == nil) && (value > a) && (value <= b)) {
            var mapped = (value - a) / (b - a);
            if (mapped <= 0.5,
                returnValue = array[i.div(2)],
                returnValue = array[i.div(2) + 1]);
        };
    };
    if (returnValue == nil) { returnValue = value };
    returnValue;
};

~degreeToNote = {|degree, scale = #[0, 3, 5, 7, 10], root = 40| // Pentatonic minor scale, E2
    var midinote;
    midinote = root + scale[degree % scale.size] + (12 * degree.div(scale.size)); // .div is integer division
    midinote;
};

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
)

(
var contours, rhythms, scale, root, rhythmValues, arrayToEnv;

contours = [
    [0, 1, 2, 3],  // Upward steps
    [3, 2, 1, 0],  // Downward steps
    [0, 2, 3, 2, 0],  // Up then down
    [3, 2, 0, 2, 3],  // Down then up
    [0, 2, 1, 3, 2],  // Wave pattern
    [0, 0, 0, 0],  // No movement
    [0, 1, 2, 3],  // Stepwise motion
    [0, 2, 4, 5]  // Leaps
];

scale = Scale.major.semitones;
root = 40; // E3

rhythmCurve = Env.pairs([[0, 0.25],[0.2, 0.25],[0.75, 0.125], [1, 0.125]]);
rhythmValues = 1 / [16, 8, 4, 2, 1];

arrayToEnv = {|array, curve = \lin|
    Env.pairs(array.collect {|v, i| [i / (array.size-1), v]}, curve);
};

s.makeBundle(s.latency, {
    Synth.tail(s, \fx);
    ~guitar = Synth(\guitarString, [\decay: 0.5]);
});

fork { loop {
    var pitchOffsetCurve = arrayToEnv.(contours.choose);
    var time = 0;
    var data = (durations: [], notes: []);
    var chordRoot = rrand(0, 7);
    while {time < rhythmCurve.duration} {
        var duration = ~getClosestValueInArray.(rhythmCurve.at(time), rhythmValues);
        var note = ~degreeToNote.(pitchOffsetCurve.at(time) + chordRoot, scale, root);
        data.durations = data.durations.add(duration);
        data.notes = data.notes.add(note);
        time = time + duration;
    };

    data.notes.do { |note, i|
        var time = data.durations[i];
        var amp = rrand(0.33, 0.9);
        var pos = rrand(0.6, 0.7);
        var duration = time * 5;
        var pan = rrand(-0.1, 0.1);
        var pointCount = 100;
        var amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
        s.makeBundle(s.latency, {
            ~guitar.set(
                \freq, note.midicps,
                \amplitudes, amplitudes.drop(1),
                \duration, duration,
                \pan, pan,
                \trigger, 1,
                \decay, data.decay,
            );
        });
        time.max(0.001).yield;
    };
    2.yield;
}};
)