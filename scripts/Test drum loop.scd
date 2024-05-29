(
s = Server.default;
s.waitForBoot {
    s.freeAll;
    s.sync;

    SynthDef(\kick, {
        |freq = 60, amp = 0.8, decay = 0.5|
        var env = EnvGen.kr(Env.perc(0.01, decay), doneAction: Done.freeSelf);
        var osc = SinOsc.ar(freq * EnvGen.kr(Env.perc(0.01, decay), timeScale: 0.4).range(0.9, 1.1));
        var kick = osc * env * amp;
        Out.ar(0, kick!2);
    }).add;

    SynthDef(\snare, {
        |amp = 0.8, decay = 0.3|
        var env = EnvGen.kr(Env.perc(0.01, decay), doneAction: Done.freeSelf);
        var noise = WhiteNoise.ar() * env;
        var osc = SinOsc.ar(164) * env; // E3
        var snare = (noise + (osc * -3.dbamp)) * amp;
        snare = BPF.ar(snare, 1320); // E6
        Out.ar(0, snare!2);
    }).add;

    SynthDef(\hihat, {
        |amp = 0.6, decay = 0.1|
        var env = EnvGen.kr(Env.perc(0.01, decay), doneAction: Done.freeSelf);
        var noise = WhiteNoise.ar();
        var hpf = HPF.ar(noise, 8000);
        var hihat = hpf * env * amp;
        Out.ar(0, hihat!2);
    }).add;

    SynthDef(\master, {
        var sig;
        sig = In.ar(\out.kr(0), 2);
        sig = sig + (NHHall.ar(sig, 1) * -12.dbamp);
        sig = Limiter.ar(sig);
        ReplaceOut.ar(\out.kr(0), sig);
    }).add;
    s.sync;
};
)

(
var patterns, bpm, beats;

Synth.tail(s, \master);

bpm = 75;
beats = 60.0 / bpm;

patterns = [
    (synthName: \kick,   triggers: [1,\,1,\,1,\,1,\] ), // Can't use synth (used internally), use synthName instead
    (synthName: \snare,  triggers: [\,\,1,\,\,\,1,\] ),
    (synthName: \hihat,  triggers: [1,1,1,1,1,1,1,1] ),
];

// patterns = [
//     (synthName: \kick,   triggers: [1,\,1,\,1,1,1,\] ),
//     (synthName: \snare,  triggers: [\,\,1,\,\,\,1,\] ),
//     (synthName: \hihat,  triggers: [1,\,1,\,1,\,1,\] ),
// ];

patterns.do { |pattern|
    fork {
        loop {
            pattern.triggers.do { |trigger|
                if (trigger != \ ) { s.makeBundle(s.latency, {Synth(pattern.synthName)}) };
                (beats / 2).yield; // 8th notes
            };
        };
    };
};
)