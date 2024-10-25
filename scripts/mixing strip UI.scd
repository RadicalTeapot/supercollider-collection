(
s = Server.default;

s.waitForBoot {
    var audioBuses, levelBuses, createStrip, testSynth, delaySend, reverbSend, outMixer;
    var mixStrip = "utils/mix strip.scd".resolveRelative.load;

    s.newBusAllocators;
    s.sync;

    audioBuses = 3.collect{ Bus.audio(s, 2) };
    levelBuses = audioBuses.collect{ Bus.control(s, 4) };
    s.sync;

    SynthDef(\test, {
        var trig = Dust.ar(1);
        var sig = Pulse.ar(48.midicps, Env.perc.ar(Done.none, trig, 0.2).range(0.9, 0.5));
        sig = MoogFF.ar(sig, 80 + Env.perc.ar(Done.none, trig, 0.5).range(0, 2000));
        sig = sig * Env.perc.ar(Done.none, trig);
        sig = SynthDef.wrap(mixStrip[\stripOutWrap].(), prependArgs: [sig!2]);
        Out.ar(\out.ir(0), sig);
    }).add;

    SynthDef(\delaySend, {
        var sig = SynthDef.wrap(mixStrip[\mixInWrap].(1));
        sig = CombL.ar(sig, 1, 1, 5);
        sig = SynthDef.wrap(mixStrip[\stripOutWrap].(), prependArgs: [sig]);
        Out.ar(\out.ir(0), sig);
    }).add;

    SynthDef(\reverbSend, {
        var sig = SynthDef.wrap(mixStrip[\mixInWrap].(2));
        sig = NHHall.ar(sig, 3, 0.8);
        sig = SynthDef.wrap(mixStrip[\stripOutWrap].(), prependArgs: [sig]);
        Out.ar(\out.ir(0), sig);
    }).add;

    mixStrip[\mixerSynthDef].(\finalMixer, 3).add;
    s.sync;

    outMixer = Synth(\finalMixer, [ins: audioBuses, globalAmp: -6.dbamp]);
    reverbSend = Synth(\reverbSend, [levelOut: levelBuses[2], in: [audioBuses[0], audioBuses[1]] , out: audioBuses[2]]);
    delaySend = Synth(\delaySend, [levelOut: levelBuses[1], in: audioBuses[0], out: audioBuses[1]]);
    testSynth = Synth(\test, [levelOut: levelBuses[0], out: audioBuses[0]]);
    s.sync;

    AppClock.sched(0, {
        var win, bounds, strips;
        Window.closeAll;

        strips = [
            mixStrip[\ui].(s, testSynth, [[delaySend, 0], [reverbSend, 0]]),
            mixStrip[\ui].(s, delaySend, [[reverbSend, 1]]),
            mixStrip[\ui].(s, reverbSend, nil, 1, 0),
        ];

        bounds = Window.availableBounds;
        win = Window(bounds: Rect(bounds.width / 2, bounds.height / 2, strips.size * 150, 300))
        .alwaysOnTop_(true)
        .onClose_({CmdPeriod.run})
        .layout_(HLayout(*(strips.collect{|strip| strip.view})))
        .front;

        fork {
            loop {
                strips.do { |strip, i|
                    defer { strips[i][\updateLevels].(*(levelBuses[i].getnSynchronous(4))) };
                };
                30.reciprocal.wait;
            };
        };
    });
};
)