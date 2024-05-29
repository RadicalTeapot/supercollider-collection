(
s = Server.default;

s.newBusAllocators;
~controlBus = Bus.control(s, 1);

s.waitForBoot {
    s.freeAll;
    Buffer.freeAll;
    s.sync;

    {
        var ir, irbuffer, bufsize;
        ~fftsize = 2048;

        irbuffer = Buffer.readChannel(s, "~/Downloads/Ovation_Celebrity_CE44_48000.wav".standardizePath, channels: [0]);
        s.sync;

        bufsize = PartConv.calcBufSize(~fftsize, irbuffer);
        ~irspectrum = Buffer.alloc(s, bufsize, 1);
        ~irspectrum.preparePartConv(irbuffer, ~fftsize);
        s.sync;

        irbuffer.free; // don't need time domain data anymore, just needed spectral version
    }.fork; // Needs to run as a Routine (PartConv is a UGen)

    ~controlBus.setSynchronous(0);
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

    SynthDef(\modulation, {
        var trigger, duration, times, sig, out;

        trigger = \trigger.tr(0);
        duration = \duration.kr(1);
        times = \times.kr([1,1]);
        out = \out.ir(0);

        sig = EnvGen.kr(Env(times: times), trigger, timeScale: duration, doneAction: Done.freeSelf);

        Out.kr(out, sig);
    }).add;

    SynthDef(\fx, {
        var sig;
        sig = In.ar(\out.kr(0), 2);
        sig = sig + (NHHall.ar(sig, 1) * -6.dbamp);
        sig = Limiter.ar(sig);
        ReplaceOut.ar(\out.kr(0), sig);
    }).add;
    s.sync;

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

    ~degreeToNote = {|degree, scale = #[0, 3, 5, 7, 10], root = 40| // Pentatonic minor scale, E2
        var midinote;
        midinote = root + scale[degree % scale.size] + (12 * degree.div(scale.size)); // .div is integer division
        midinote;
    };

    ~degreeToFreq = {|degree, scale = #[0, 3, 5, 7, 10], root = 40| // Pentatonic minor scale, E2
        ~degreeToNote.(degree, scale, root).midicps;
    };
    s.sync;
}
)

(
var patterns;
var stringNotes, scale;
var fretboard, lastPlayedNotes, intensityTriggerChance;
var metro, beatDur;

metro = TempoClock.default;
metro.tempo = 1;
Synth.tail(s, \fx);

scale = Scale.lydian.semitones;
stringNotes = [40, 45, 50, 55, 59, 64]; // EADGBE
s.makeBundle(s.latency, {
    ~strings = (stringNotes.size).collect {|i| Synth(\guitarString, [decay: 1.0 / (i+1)]) };
    ~bassStrings = 2.collect{Synth(\guitarString)};
    ~kick = Synth(\kick);
    ~snare = Synth(\snare, [pan: 0.2, amp: -16.dbamp, decay: 0.3]);
    ~hihat = Synth(\hihat, [pan: 0.2, amp: -10.dbamp]);
});

fretboard = ~fretboard.(stringNotes);
lastPlayedNotes = (-1).dup(stringNotes.size); // For slides

patterns = [
    (type: \notes, index: 0, decay: 0.5, pan: -0.5, \notes: [12] ++ (\).dup(12)),
    (type: \notes, index: 1, decay: 3.0, pan: 0.5, \notes: [0, \, 3, 2, \, \, 0]),
    (type: \random, pan: 0, probability: 0.5),
    (type: \perc, synthVar: ~kick,   triggers: [1,\,1,\,1,0.2,1,\] ), // Can't use synth (used internally), use synthName instead
    (type: \perc, synthVar: ~snare,  triggers: [\,\,1,\,\,\,1,\] ),
    (type: \perc, synthVar: ~hihat,  triggers: [1,0.75,1,0.33,1,0.75,1,0.33] ),
];

// Reset control bus value
s.makeBundle(s.latency, {
    ~controlBus.setSynchronous(0);
    metro.beats = 0;
});
intensityTriggerChance = 0;

patterns.do { |data, i|
    var lastNote = 0;
    fork { loop {
        var time, freq, amp, pos, duration, pan;
        var pointCount, amplitudes;

        if (data.type == \perc) {
            data.triggers.do { |trigger|
                if ((trigger != \) && (trigger.coin)) { s.makeBundle(s.latency, {data.synthVar.set(\trigger, 1)}) };
                0.5.yield; // 8th notes
            };
        };

        if(data.type == \notes) { data.notes.do { |note|
            if (note != \) {
                time = [1,2,3,4].wchoose([1, 3, 2, 1.5].normalizeSum) * 0.5;
                amp = rrand(0.33, 0.9) * 1;
                pos = rrand(0.6, 0.7);
                duration = rrand(1.0, 1.5) * time.max(1.0) * 5;
                pan = data.pan + rrand(-0.1, 0.1);
                pointCount = 100;
                amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
                freq = ~degreeToFreq.(note, scale, stringNotes[0]);
                s.makeBundle(s.latency, {
                    ~bassStrings[data.index].set(
                        \freq, freq,
                        \amplitudes, amplitudes.drop(1),
                        \duration, duration,
                        \pan, pan,
                        \trigger, 1,
                        \decay, data.decay,
                    );
                });
            };
            time.yield;
        }};

        if (data.type == \random) {
            var intensity;
            intensity = ~controlBus.getSynchronous;
            time = rrand(0.4 - (intensity * 0.2), 1.3 - (intensity * 0.7)).max(0.05);
            time = (time * 8).asInteger / 8.0 + rrand(-0.02, 0.02); // Quantize time to small variations
            amp = rrand(0.33, 0.9) * 1.5 * time.max(1.0) + (intensity * 0.2);
            pos = rrand(0.7 + (intensity * 0.15), 0.9);
            duration = rrand(1.0, 1.5) * time.max(1.0) * 2 - (intensity * 0.25);
            pan = data.pan + rrand(-0.1, 0.1);
            pointCount = 100;
            amplitudes = ~naiveFFT.(~getPoints.(pos, pointCount) * amp, 13) / pointCount;
            if (data.probability.coin) {
                var data, note, string, prevNote, shouldSlide;
                lastNote = if ((0.75).coin, (lastNote + [-3, -2, -1, 0, 1, 2, 3].wchoose([1, 3, 2, 1, 2, 3, 1].normalizeSum)), (2..14).choose).clip(2, 14);
                note = lastNote + (intensity * 7).asInteger;
                note = ~degreeToNote.(note, scale, stringNotes[0]);
                string = fretboard.(note);
                prevNote = lastPlayedNotes[string];
                shouldSlide = (prevNote != -1) && (time > 0.5);
                shouldSlide = shouldSlide && (abs(prevNote - note) > 2) && (abs(prevNote - note) <= 5);
                shouldSlide = shouldSlide && ((0.02 + (intensity * 0.5)).coin);
                if (shouldSlide != true)
                {
                    s.makeBundle(s.latency, {
                        ~strings[string].set(
                            \freq, note.midicps,
                            \amplitudes, amplitudes.drop(1),
                            \duration, duration,
                            \trigger, 1,
                            \pan, pan,
                        );
                    });
                } {
                    var slideDuration, noteDuration;
                    slideDuration = time / abs(prevNote - note);
                    noteDuration = slideDuration / abs(prevNote - note);
                    (prevNote..note).do { |currentNote, i|
                        if (i == 0) {
                            s.makeBundle(s.latency, {
                                ~strings[string].set(
                                    \freq, currentNote.midicps,
                                    \amplitudes, amplitudes.drop(1),
                                    \duration, duration,
                                    \trigger, 1,
                                    \pan, pan,
                                );
                            });
                        } {
                            s.makeBundle(s.latency, {
                                ~strings[string].set(\freq, currentNote.midicps);
                            });
                        };
                        noteDuration.yield;
                    };
                    time = time - slideDuration;
                    "Slide!".postln;
                };
                lastPlayedNotes[string] = note;
            };
            if (intensity <= 0.01) {
                intensityTriggerChance = intensityTriggerChance + 0.0025;
                if (intensityTriggerChance.coin) {
                    s.makeBundle(s.latency, {
                        Synth(\modulation, [trigger: 1, out: ~controlBus, duration: 10, times: #[0.1, 1]]);
                    });
                    "Modulation".postln;
                    intensityTriggerChance = 0;
                };
            };
            time.yield;
        };
    }};
};
)