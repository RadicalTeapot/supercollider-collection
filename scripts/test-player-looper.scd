(
VSTPlugin.search;
s = Server.default;
s.waitForBoot {
    var env, offsetEnv, shaperBuf, offsetShaperBuf, soundBuf, player, channels, xfade=0.1;
    s.free;
    s.sync;

    env = Env.xyc([[0,0], [xfade, 1], [1,1]]); // Crossfade profile
    offsetEnv = Env.xyc([[0, 1-xfade], [xfade, 1], [xfade, 0], [1, 1-xfade]]); // Offset phasor profile
    shaperBuf = Buffer.loadCollection(s, env.asSignal(1024).asWavetable);
    offsetShaperBuf = Buffer.loadCollection(s, offsetEnv.asSignal(1024).asWavetable);
    soundBuf = Buffer.read(s,
        "C:/Users/Mathias/AppData/Local/_data/Recordings/Foleys/23540__loofa__thai-gong2.wav");
    s.sync;
    channels = soundBuf.numChannels;

    //{
    //    var start = 0;
    //    var end = 1;
    //    var rate = 1;
    //    var phasor = Phasor.ar(rate: rate * 200/s.sampleRate, start: start, end: end, resetPos: start);
    //    var offset = Osc.ar(offsetShaperBuf, 0, phasor.linlin(start, end, 0, 2pi)).linlin(0, 1, start, end);
    //    var mix = Osc.ar(shaperBuf, 0, phasor.linlin(start, end, 0, 2pi));
    //    [phasor, offset, mix, Select.ar(mix, [offset, phasor])]
    //}.plot;

    SynthDef(\player, {
        var start = \start.kr(0).clip(0, 1) * BufFrames.ir(soundBuf);
        var end = \end.kr(1).clip(0, 1) * BufFrames.ir(soundBuf);
        var speed = \speed.kr(1);
        var gate = Trig.ar(1, \dur.kr(1));

        var phasor = Phasor.ar(rate: BufRateScale.ir(soundBuf) * speed, start: start, end: end); // Main lookup phasor
        var lookupIndex = phasor.linlin(start, end, 0, 2pi); // For lookup using Osc phase value

        var offset = Osc.ar(offsetShaperBuf, 0, lookupIndex).linlin(0, 1, start, end); // Offset phasor using lookup profile
        var mix = Osc.ar(shaperBuf, 0, lookupIndex); // Mix between main and offset phasor using lookup profile

        var env = Env.asr(\atk.kr(0.1), 1, \rel.kr(0.1)).ar(Done.freeSelf, gate); // Global env for the player itself
        var sig = SelectX.ar(mix, [
            BufRd.ar(channels, soundBuf, offset),
            BufRd.ar(channels, soundBuf, phasor)
        ]);
        sig = sig * env * \amp.kr(-6.dbamp);
        sig = Pan2.ar(sig, \pan.kr(0));
        Out.ar(0, sig);
    }).add;

    SynthDef(\fx, {
        var in = In.ar(0, 2);
        var sig = VSTPlugin.ar(in, 2, id: \rev);
        sig = VSTPlugin.ar(sig, 2, id: \delay);
        ReplaceOut.ar(0, sig);
    }).add;

    SynthDef(\paulStretch, {
        var sig = In.ar(0, 2);
        sig = VSTPlugin.ar(sig, 2, info: 'PaulXStretch.vst3');
        Out.ar(0, sig);
    }).add;
    s.sync;

    ~fx = VSTPluginController.collect(Synth(\fx, addAction: 'addToTail'));
    s.sync;
    ~fx.rev.open("C:/Program Files/Common Files/VST3/ValhallaSupermassive.vst3");
    ~fx.delay.open("C:/Program Files/Common Files/VST3/Deelay.vst3");
    s.sync;
    ~fx.rev.setProgramData(~fxRevState);
    ~fx.delay.setProgramData(~fxDelayState);

    ~stretch = VSTPluginController(Synth(\paulStretch, addAction: 'addToTail')).open(action: { |self, success|
        if (success) { self.setProgramData(~stretchState) } { "An error occured".postln };
    });

    Routine {
        loop {
            var time = rrand(8, 30);
            var count = [1,2,4,8].wchoose([1,0.3,0.2,0.1].normalizeSum);
            count.do {
                var dur = rrand(10, 20);
                var start = exprand(0.01, 0.75) - 0.01;
                var end = rrand(start + 0.1, 1);
                var speed = [-24, -17, -12, -5, 0, 7, 12, 19, 24].wchoose([0.7,0.7,1,0.9,1.3,0.4,0.6,0.4,0.3].normalizeSum).midiratio * [-1, 1].choose;
                var pan = rrand(-1, 1);
                s.bind { Synth(\player, [speed: speed, start: start, end: end, atk: dur * 0.1, rel: dur * 0.25, dur:
                    dur, amp: 1/count, pan: pan]) };
            };
            // High pitch short-repeats
            if(0.2.coin) {
                var dur = rrand(0.5, 1);
                var start = rrand(0, 0.9);
                var end = start + rrand(0.01, 0.1);
                var speed = 24 * [-1, 1].choose;
                s.bind { Synth(\player, [speed: speed, start: start, end: end, atk: dur * 0.1, rel: dur * 0.25, dur: dur]) };
                "Extra".postln;
            };
            time.yield;
        }
    }.play;
};
)

~fx.rev.editor;
~fx.rev.getProgramData({|data| ~fxRevState = data });
~fx.delay.editor;
~fx.delay.getProgramData({|data| ~fxDelayState = data });
~stretch.editor;
~stretch.getProgramData({|data| ~stetchState = data });
