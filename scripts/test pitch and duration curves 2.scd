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
    SynthDef(\kick, {
        var trigger, freq, amp, decay, pan, out;
        var env, fmEnv, osc, sig;

        trigger = \trigger.tr(0);
        freq = \freq.kr(41); // E1
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.5);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(gate: trigger);
        fmEnv = Env.perc(releaseTime: decay).kr(gate: trigger, timeScale: 0.4).range(0.9, 1.1);
        osc = SinOsc.ar(freq * fmEnv);
        sig = osc * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    SynthDef(\snare, {
        var trigger, freq, bpfFreq, amp, decay, pan, out;
        var env, noise, osc, sig;

        trigger = \trigger.tr(0);
        freq = \freq.kr(164); // E3
        bpfFreq = \bpfFreq.kr(1320); // E6
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.2);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(gate: trigger);
        noise = WhiteNoise.ar();
        osc = SinOsc.ar(freq);
        sig = noise + (osc * -3.dbamp);
        sig = BPF.ar(sig, bpfFreq) * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(out, sig);
    }).add;

    SynthDef(\hihat, {
        var trigger, hpfFreq, amp, decay, pan, out;
        var env, noise, hpf, sig;

        trigger = \trigger.tr(0);
        hpfFreq = \hpfFreq.kr(8000);
        amp = \amp.kr(-6.dbamp);
        decay = \decay.kr(0.1);
        pan = \pan.kr(0);
        out = \out.ir(0);

        env = Env.perc(releaseTime: decay).kr(gate: trigger);
        noise = WhiteNoise.ar();
        hpf = HPF.ar(noise, 8000);
        sig = hpf * env;
        sig = Pan2.ar(sig, pan) * amp;

        Out.ar(0, sig);
    }).add;
    s.sync;
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

~fretboard = {|notes = #[40, 45, 50, 55, 59, 64], maxFret = 24| // EADGBE tuning
    var board, noteLookup;
    var lastUsedString, lastUsedFretColumn, stringPicker;

    board = notes +.t (0..maxFret);
    noteLookup = (notes[0]..(notes.wrapAt(-1)+maxFret)).collect {|note|
        var data = [];
        board.do {|notes, string|
            var index = notes.indexOf(note);
            if (index != nil) { data = data.add((string: string, fret: index)) };
        };
        data;
    };

    lastUsedString = -1;
    lastUsedFretColumn = 0;
    stringPicker = {|note|
        var possiblePositions, bestCandidate;
        possiblePositions = noteLookup[note - notes[0]];
        if (lastUsedString == -1) {
            bestCandidate = possiblePositions.sort({|a, b| a.fret <= b.fret })[0]; // Pick lowest fret
        } {
            bestCandidate = possiblePositions.sort({|a, b| abs(a.fret - lastUsedFretColumn) <= abs(b.fret - lastUsedFretColumn) })[0]; // Minimize horizontal movement
        };

        lastUsedString = bestCandidate.string;
        lastUsedFretColumn = bestCandidate.fret;

        bestCandidate.string;
    };

    stringPicker;
};
)

(
var contours, rhythms, scale, root, data, fretboards, dataIndex, arrayToEnv, chordRoot, drumPatterns;
var stringNotes;

stringNotes = [40, 45, 50, 55, 59, 64]; // EADGBE
scale = Scale.lydian.semitones;
root = 40; // E3
s.makeBundle(s.latency, {
    Synth.tail(s, \fx);
    ~guitars = [
        (stringNotes.size).collect {|i| Synth(\guitarString, [decay: 1.0 / (i+1)]) },
        (stringNotes.size).collect {|i| Synth(\guitarString, [decay: 1.0 / (i+1) + 0.5]) }
    ];
    ~bass = Synth(\guitarString, [\decay: 2]);
    ~kick = Synth(\kick);
    ~snare = Synth(\snare, [pan: 0.2, amp: -16.dbamp, decay: 0.3]);
    ~hihat = Synth(\hihat, [pan: 0.2, amp: -10.dbamp]);
});

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

rhythms = [
    [1, 1, 1, 1], // "four_quarters":
    [2, 2], // "two_halves":
    [4], // "whole_note":
    (0.5)!8, // "eight_eighths":
    [1, 0.5, 0.5, 1, 0.5, 0.5], // "syncopated_eighths":
    [1, 0.5, 0.5, 1, 1], // "quarter_and_eighths":
    [0.5, 0.5, 1, 0.5, 0.5, 1], // "eighths_and_quarters":
    [4/3, 4/3, 4/3], // "quarter_triplets":
    (2/3)!6 // "eighth_triplets":
];

drumPatterns = [
    (synthVar: ~kick,   triggers: [1,\,1,\,1,0.2,1,\] ), // Can't use synth (used internally), use synthName instead
    (synthVar: ~snare,  triggers: [\,\,1,\,\,\,1,\] ),
    (synthVar: ~hihat,  triggers: [1,0.75,1,0.33,1,0.75,1,0.33] ),
];

arrayToEnv = {|array, curve = \lin|
    Env.pairs(array.collect {|v, i| [i / (array.size-1), v]}, curve);
};


data = [
    (pan: -0.33, root: root + 12, decay: 0.2),
    (pan: 0.33, root: root, decay: 0.5),
];
fretboards = [
    ~fretboard.(stringNotes),
    ~fretboard.(stringNotes)
];
dataIndex = 0;

// Bass
fork { loop {
    var amp = rrand(0.33, 0.9);
    var pos = rrand(0.6, 0.7);
    var pointCount = 100;
    var amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
    chordRoot = rrand(0, 7);
    s.makeBundle(s.latency, {
        ~bass.set(
            \freq, ~degreeToNote.(chordRoot, scale, root-12).midicps,
            \amplitudes, amplitudes.drop(1),
            \duration, 10.0,
            \trigger, 1,
        );
    });
    4.yield;
}};

// Guitars
fork { loop {
    var durations = rhythms.choose;
    var contour = contours.choose;
    var notes = durations.collect { |v, i| ~degreeToNote.(contour[i % contour.size] + chordRoot, scale, data[dataIndex].root) };
    var offset = rrand(0, 7) / 8.0;

    offset.yield;
    durations.do { |duration, i|
        var time = duration / 4.0 + rrand(-0.015, 0.015);
        var amp = rrand(0.33, 0.9);
        var pos = rrand(0.8, 0.9);
        var pan = data[dataIndex].pan + rrand(-0.1, 0.1);
        var pointCount = 100;
        var amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
        var string = fretboards[dataIndex].(notes[i]);
        if (i == (durations.size - 1)) { duration = 2 };
        s.makeBundle(s.latency, {
            ~guitars[dataIndex][string].set(
                \freq, notes[i].midicps,
                \amplitudes, amplitudes.drop(1),
                \duration, duration * 2,
                \pan, pan,
                \trigger, 1,
            );
        });
        time.max(0.001).yield;
    };
    (1 - offset).yield;
    dataIndex = 1 - dataIndex;
}};

// Drums
drumPatterns.do { |data, i|
    fork { loop {
        data.triggers.do { |trigger|
            if ((trigger != \) && (trigger.coin)) { s.makeBundle(s.latency, {data.synthVar.set(\trigger, 1)}) };
            0.5.yield; // 8th notes
        };
    }};
};
)