(
s = Server.default;

s.newBusAllocators;
~controlBus = Bus.control(s, 1);

s.waitForBoot({
    s.freeAll;
	Buffer.freeAll;
	s.sync;

    ~controlBus.setSynchronous(0);
    s.sync;

    SynthDef(\modulation, {
        var trigger, duration, times, sig, out;
        trigger = \trigger.tr(0);
        duration = \duration.kr(1);
        times = \times.kr([1,1]);
        out = \out.ir(0);
        sig = EnvGen.kr(Env(times: times), trigger, timeScale: duration, doneAction: Done.freeSelf);
        Out.kr(out, sig);
    }).add;
    s.sync;
})
)

(
var scale, root;
var degreeToNote, noteAsString;

scale = Scale.majorPentatonic.semitones;
root = 60;

degreeToNote = {|degree|
    root + scale[degree % scale.size] + (12 * degree.div(scale.size));
};

noteAsString = {|note|
    (['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'][note % 12] ++ (note.div(12) - 2));
};

s.makeBundle(s.latency, {
    ~controlBus.setSynchronous(0); // Make sure bus value is reset
});

Routine { loop {
    var degree, offset;
    offset = (~controlBus.getSynchronous * 10).asInteger;
    degree = (0..5).choose + offset;
    if ((offset < 1) && (0.1).coin) {
        s.makeBundle(s.latency, {
            Synth(\modulation, [trigger: 1, out: ~controlBus, duration: 3, times: #[0.1, 1]]);
            "Modulation".postln;
        });
    };
    (noteAsString.(degreeToNote.(degree)) ++ " (offset: " ++ offset ++ ")").postln;
    (0.33).yield;
}}.play)