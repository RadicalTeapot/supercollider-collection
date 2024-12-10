(
VSTPlugin.search;
s = Server.default;
s.waitForBoot {
    var fx;
    s.free;
    s.sync;

    SynthDef(\fx, {
        var in = In.ar(\in.ir(0), 2);
        var reverb = VSTPlugin.ar(in, 2, id: \reverb);
        var delay = VSTPlugin.ar(reverb, 2, id: \delay);
        ReplaceOut.ar(\out.ir(0), delay);
    }).add;
    s.sync;

    fx = Synth(\fx);
    ~plugins = VSTPluginController.collect(fx);
    ~plugins.reverb.open("C:/Program Files/Common Files/VST3/ValhallaSupermassive.vst3");
    ~plugins.delay.open("C:/Program Files/Common Files/VST3/Deelay.vst3");
};
)

~plugins.reverb.get(\Mix, {|v| v.postln; })
~plugins.reverb.set(\Mix, 0.2);
~plugins.reverb.editor;
~plugins.reverb.getProgramData({|data| ~reverbState = data });
~plugins.reverb.setProgramData(~reverbState);
~plugins.delay.editor;
~plugins.delay.getProgramData({|data| ~delayState = data });
~plugins.delay.setProgramData(~delayState);
