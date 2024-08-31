(
s.waitForBoot {
    var buf;

    Buffer.freeAll;
    s.sync;

    buf = Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01.wav");
    s.sync;
    // buf.postln;

    SynthDef(\crossfadeLooper, {
        var buf = \buf.kr(0);
        var speed = \speed.kr(1);
        var startPosition = \startPosition.kr(0).clip(0, 1); // Normalized
        var duration = \duration.kr(1).max(0); // In seconds
        var fadeTime = \fadeTime.kr(0.01); // In seconds
        var gate = \gate.kr(0);
        var atk = \atk.kr(0.01);
        var rel = \rel.kr(1);
        var dur = \dur.kr(1);
        var amp = \amp.kr(0.5);
        var out = \out.ir(0);

        var samples = BufSamples.kr(buf);
        var rate = BufRateScale.kr(buf) * speed;
        var start = startPosition * samples;
        var end = (duration / (rate.abs)) * samples;

        var phasors = Phasor.ar(rate: rate, start: 0, end: end, resetPos: 0) + start + [0, end];
        var bufValues = BufRd.ar(1, buf, phasors);

        // Trigger when time left before phasor loops is equal to fade time
        var trig = Select.ar(rate >= 0, [
            phasors[0] < (fadeTime * rate.abs * end + start),
            phasors[0] > ((1 - (fadeTime * rate)) * end + start)
        ]);
        var slope = fadeTime.reciprocal;
        var fadeSig = Env.linen(fadeTime, duration - fadeTime, fadeTime).ar(Done.none, trig);

        var sig = SelectX.ar(fadeSig, bufValues);
        sig = sig * Env.asr(atk, 1, rel).ar(Done.freeSelf, gate, dur);
        sig = sig * amp;
        Out.ar(out, sig!2);
    }).add;

    SynthDef(\crossfadeOneShot, {
        var buf = \buf.kr(0);
        var speed = \speed.kr(1);
        var startPosition = \startPosition.kr(0).clip(0, 1); // Normalized
        var fadeTime = \fadeTime.kr(0.01); // In seconds
        var gate = \gate.kr(0);
        var atk = \atk.kr(0.01);
        var duration = \duration.kr(1).max(0); // In seconds
        var rel = \rel.kr(1);
        var dur = \dur.kr(1);
        var amp = \amp.kr(0.5);
        var out = \out.ir(0);

        var samples = BufSamples.kr(buf);
        var rate = BufRateScale.kr(buf) * speed;
        var start = startPosition * samples;
        var end = ((atk+duration+rel) * dur / (rate.abs)) * samples;

        var phasors = Phasor.ar(rate: rate.abs, start: start, end: start+end) + [0, fadeTime];
        var bufValues = BufRd.ar(1, buf, phasors);

        // Trigger when time left before phasor loops is equal to fade time
        var trig = Select.ar(rate >= 0, [
            phasors[0] < (fadeTime * rate.abs * end + start),
            phasors[0] > ((1 - (fadeTime * rate)) * end + start)
        ]);
        var slope = fadeTime.reciprocal;
        var fadeSig = Slew.ar(ToggleFF.ar(trig), slope, slope);

        var sig = SelectX.ar(fadeSig, bufValues);
        sig = sig * Env.linen(atk, duration - atk - rel, rel).ar(Done.freeSelf, timeScale: dur);
        sig = sig * amp;
        Out.ar(out, sig!2);
    }).add;
    s.sync;

    Routine {
        loop {
            var pos = rrand(0.0, 1.0);
            var dur = rrand(0.02, 0.1);
            var fade = 0.01;
            var speed = rrand(1.0, 5.0);
            rrand(5, 15).do {
                s.bind { Synth(\crossfadeOneShot, [buf: buf, speed: speed, startPosition: pos, duration: dur, fadeTime: fade, rel: 0.01]) };
                (dur+(2*fade)).yield;
            };
            1.yield;
        }
    }.play;
};
)