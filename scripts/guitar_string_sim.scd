(
~irspectrum.free;
~fftsize = 2048;

s.waitForBoot {
    {
        var ir, irbuffer, bufsize;
        irbuffer = Buffer.readChannel(s, "~/Downloads/Ovation_Celebrity_CE44_48000.wav".standardizePath, channels: [0]);
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

// Use for playing a single note
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
    sig = sig.blend(PartConv.ar(sig, ~fftsize, ~irspectrum.bufnum, 0.3), 0.2);
    sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
}).add;

// Use for a guitar string rather than individual notes
// Useful for slides, bends, detuning, decay factors
// Should also consume less CPU (max amount of notes is 6, could be a lot more when using the note synthdef)
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

    frequencies = freq * overtones;
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
)

(
var patterns;
var scale, root;
var degreeToNote, degreeToFreq;
var fretboard, noteLookup;
var lastPlayedNotes, lastUsedString, lastUsedFretColumn, stringPicker;
var strings;

s = Server.default;
Synth.tail(s, \fx);

scale = Scale.minorPentatonic.semitones;

// EADGBE tuning
root = 40;  // E2
fretboard = (root + [0, 5, 10, 15, 19, 24]) +.t (0..12); // Use only the first 12 frets
noteLookup = (root..(root+36)).collect {|note|
    var data = [];
    fretboard.do {|notes, string|
        var index = notes.indexOf(note);
        if (index != nil) { data = data.add((string: string, fret: index)) };
    };
    data;
};

lastPlayedNotes = (0).dup(6);
lastUsedString = -1;
lastUsedFretColumn = 0;
stringPicker = {|note|
    var possiblePositions, bestCandidate;
    possiblePositions = noteLookup[note - root];
    if (lastUsedString == -1) {
        bestCandidate = possiblePositions.sort({|a, b| a.fret <= b.fret })[0]; // Pick lowest fret
    } {
        bestCandidate = possiblePositions.sort({|a, b| abs(a.fret - lastUsedFretColumn) <= abs(b.fret - lastUsedFretColumn) })[0]; // Minimize horizontal movement
    };

    lastUsedString = bestCandidate.string;
    lastUsedFretColumn = bestCandidate.fret;

    bestCandidate;
};

degreeToNote = {|degree|
    var midinote;
    midinote = root + scale[degree % scale.size] + (12 * degree.div(scale.size)); // .div is integer division
    midinote;
};

degreeToFreq = {|degree|
    degreeToNote.(degree).midicps;
};

s.makeBundle(s.latency, {
    var pointCount, pos, overtones, amplitudes;
    pointCount = 100;
    pos = 0.6;
    overtones = 12;
    amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount), (overtones+1)) / pointCount;
    strings = [40, 45, 50, 55, 59, 64].collect {|note, i| Synth(\guitarString, [
        freq: note.midicps,
        amplitudes: amplitudes.drop(1),
        decay: 1.0 / (i+1),
    ]) };
});

patterns = [
    (type: \notes, pan: -0.5, \notes: [0, \, \]),
    (type: \notes, pan: 0.5, \notes: [0, \, 3, 2, \, \, 0]),
    (type: \random, pan: 0, \notes: (2..15) ++ (\).dup(10)),
];

patterns.do { |data, i|
    Routine { loop {
        var time, freq, amp, pos, duration, pan;
        var pointCount, amplitudes;

        if(data.type == \notes) { data.notes.do { |note|
            if (note != \) {
                time = rrand(0.5, 1.5);
                amp = rrand(0.33, 0.9) * 1;
                pos = rrand(0.6, 0.7);
                duration = rrand(1.0, 1.5) * time.max(1.0) * 5;
                pan = data.pan + rrand(-0.1, 0.1);
                pointCount = 100;
                amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
                freq = degreeToFreq.(note);
                s.makeBundle(s.latency, {
                    Synth(\guitar, [ // Keep those as separate notes rather than using the predefined strings for now
                        freq: freq,
                        amplitudes: amplitudes.drop(1),
                        duration: duration,
                        pan: pan,
                        decay: 3
                    ]);
                });
            };
            time.yield;
        }};

        if (data.type == \random) {
            var note, string;
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
                string = stringPicker.(degreeToNote.(note)).string;
                s.makeBundle(s.latency, {
                    strings[string].set(
                        \freq, freq,
                        \amplitudes, amplitudes.drop(1),
                        \duration, duration,
                        \trigger, 1,
                        \pan, pan,
                    );
                });
            };
            time.yield;
        };
    }}.play;
};
)