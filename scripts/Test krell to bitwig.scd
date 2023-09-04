({
    var serverOptions = Server.default.options;
    serverOptions.inDevice_("ASIO : JackRouter");
    serverOptions.outDevice_("ASIO : JackRouter");
    serverOptions.numOutputBusChannels_(8);
    serverOptions.numInputBusChannels_(8);
    Server.default.reboot;
}.())

(SynthDef(\phasor, {
    var duration = \duration.ir(0.1);
    var line = Line.ar(dur: duration, doneAction: Done.freeSelf);
    var gate = Env.cutoff(0).ar(Done.none, 1);
    Out.ar(0, [line, gate]);
}).add)

(s.waitForBoot({
    loop {
        var duration = rrand(0.5, 10);
        var synth = Synth(\phasor, [duration: duration]);
        s.sync();
        (duration + 0.1).wait;
    }
}))