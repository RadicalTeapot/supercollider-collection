(
VSTPlugin.search;
s.waitForBoot {
    s.free;
    s.sync;

    // Rain
    SynthDef(\rain, {
        var sig = PinkNoise.ar(1!2);
        var other = PinkNoise.ar(1!2) * LFNoise1.ar(LFNoise2.ar(0.1!2).range(500, 5000));
        sig = sig * LFNoise2.ar(0.1!2).range(0.25, 1);
        sig = LPF.ar(sig, LFNoise2.ar(0.1!2).range(1000, 10000));
        other = other * LFNoise2.ar(0.1!2).range(0.25, 1);
        other = LPF.ar(other, LFNoise2.ar(0.1!2).range(1000, 10000));
        sig = sig.blend(other, 0.75);
        sig = FreeVerb2.ar(sig[0], sig[1], 0.5, 0.8);
        sig = LPF.ar(sig, LFNoise2.ar(0.1).range(1000, 2000));
        sig = HPF.ar(sig, LFNoise2.ar(0.1).range(100, 500));
        Out.ar(0, sig * \amp.kr(-6.dbamp));
    }).add;

    // Drone 
    SynthDef(\drone, {
        var base = 60;
        var trig = Dust.kr(0.02);
        var notes = Select.kr(ToggleFF.kr(trig), [
            [ -12, -5, 0, 4, 7, 24 ],
            [ -15, -9, -4, 4, 9, 24 ]
        ]);
        var amps = [0.7, 0.5, 0.4, 0.3, 0.2, 0.2] * 0.5;
        var detune = [1!5, 1!5, LFNoise2.ar(0.02!5).range(0.99, 1.01), LFNoise2.ar(0.02!5).range(0.99, 1.01), LFNoise2.ar(0.02!5).range(0.99, 1.01), LFNoise2.ar(0.02!5).range(0.99, 1.01)];
        var ampMods = [1!2, LFNoise2.ar(0.1!2).range(0.5, 1), LFNoise2.ar(0.1!2).range(0.5, 1),
            LFNoise2.ar(0.2!2).range(0.3, 1), LFNoise2.ar(0.5!2).range(0.2, 1), LFNoise2.ar(3!2).range(0.0, 1)];
        var envs = [1, 1, 1, 1, 1, Env.perc(0.01, 0.15).ar(Done.none, Dust.ar(SinOsc.kr(3).range(2, 6)))];
        var sig = Mix.ar(Splay.ar(SinOsc.ar((notes + base).midicps * detune)) * amps * ampMods * envs);
        sig = sig * Env.linen(5, 15, 20).ar(Done.none, trig);
        sig = sig * (-18.dbamp);

        Out.ar(0, VSTPlugin.ar(sig, 2) * \amp.kr(-6.dbamp));
    }).add;
    
    SynthDef(\fx, {
        var in = In.ar(0, 2);
        ReplaceOut.ar(0, VSTPlugin.ar(in, 2));
    }).add;
    s.sync;

    ~fx = VSTPluginController(Synth(\fx)).open("C:/Program Files/Common Files/VST3/Lost-Tapes.vst3");
    ~drone = Synth(\drone, [amp: 1]);
    ~rain = Synth(\rain, [amp: 1]);
    ~plugin = VSTPluginController(~drone);
    ~plugin.open("C:/Program Files/Common Files/VST3/ValhallaSupermassive.vst3");
}
)

~plugin.editor;
~plugin.getProgramData({|data| ~state = data });
~fx.editor;
~fx.getProgramData({|data| ~fxState = data });
(
~plugin.setProgramData(~state);
~fx.setProgramData(~fxState);
~rain.set(\amp, -3.dbamp);
)

