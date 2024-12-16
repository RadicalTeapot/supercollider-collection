(
~crateLooper = {
    |server, id, duration, channels=2, in=0, out=0, speed=1, xfadeDuration=0.1|
    var recorder, player;
    var path = '/play'++id;
    var frames = duration * server.sampleRate;
    var buffer = Buffer.alloc(server, frames, channels);
    buffer.zero;
    s.sync;

    recorder = {
        var gate = Trig1.ar(1, duration);
        var fade = Env.asr(xfadeDuration, 1, xfadeDuration, 0).ar(Done.none, gate);
        var phase = Phasor.ar(gate, BufRateScale.ir(buffer), 0, BufFrames.ir(buffer));
        var done = Done.kr(fade);
        var sig = SelectX.ar(fade, [BufRd.ar(channels, buffer, phase), In.ar(in, channels)]);
        BufWr.ar(sig, buffer, phase, 1);
        SendReply.kr(done, path);
        FreeSelf.kr(done);
        Out.ar(out, Silent.ar(channels));
    }.play(addAction: 'addToTail');

    player = {
        // Lag here is just for fun, remove it (or make it modulable)
        var rate = \speed.kr(speed).lag(0.3);
        var trig = \trig.tr(0);
        var playGate = SetResetFF.ar(T2A.ar(trig), 0).lag(0.1);
        var phase = Phasor.ar(trig, BufRateScale.ir(buffer) * rate, 0, BufFrames.ir(buffer));
        var sig = BufRd.ar(channels, buffer, phase) * playGate * \amp.kr(-6.dbamp);
        Out.ar(out, sig);
    }.play(addAction: 'addToTail');

    OSCFunc({"Done recording".postln; player.set(\trig, 1)}, path).oneShot;
    (
        player: player,
        stopPlayer: { player.free; buffer.free; },
        writeToDisk: {|self, outPath|
            outPath = outPath.standardizePath;
            ("Writing buffer to"+outPath).postln;
            buffer.write(outPath, "wave", completionMessage: { "Done writing".postln });
        },
    );
};
)

(
VSTPlugin.search;
s = Server.default;
s.waitForBoot {
    var looper;
    s.free;
    Buffer.freeAll;
    s.sync;

    SynthDef(\simple, {
        var sig = SinOsc.ar(\freq.kr(440));
        sig = sig * Env.perc(0.1).ar(Done.freeSelf, timeScale: \dur.kr(1));
        sig = Pan2.ar(sig, \pan.kr(0));
        sig = sig * \amp.kr(-6.dbamp);
        Out.ar(\out.ir(0), sig);
    }).add;

    SynthDef(\drone, {
        Out.ar(0, LFSaw.ar(220!2) * \amp.kr(-6.dbamp));
    }).add;

    SynthDef(\fx, {
        var in = In.ar(0, 2);
        var sig = VSTPlugin.ar(in, 2, id: \rev);
        sig = VSTPlugin.ar(sig, 2, id: \delay);
        ReplaceOut.ar(0, sig);
    }).add;
    s.sync;

    //Synth(\drone);

    r = Routine { loop {
        var note = Scale.minorPentatonic.performDegreeToKey(rrand(0, 10));
        var root = 48;
        var pan = rrand(-1.0, 1.0);
        s.bind { Synth(\simple, [freq: (note+root).midicps, dur: 0.125, pan: pan]) };
        0.5.yield;
    }}.play;

    s.bind { a = ~createLooper.(s, 0, 4, speed:1); };
    Routine { loop { a.player.set(\speed, [-2, -1, -0.5, 0.5, 1, 2].choose); 2.yield; }}.play;

    s.bind { 
        var fx = Synth(\fx, addAction: 'addToTail');
        s.sync;
        ~fx = VSTPluginController.collect(fx);
        ~fx.rev.open("C:/Program Files/Common Files/VST3/ValhallaSupermassive.vst3");
        ~fx.delay.open("C:/Program Files/Common Files/VST3/Deelay.vst3");
        s.sync;
        ~fx.rev.setProgramData(~fxRevState);
        ~fx.delay.setProgramData(~fxDelayState);
    };
    s.meter(0, 2);
};
)

r.stop;
~fx.rev.editor;
~fx.rev.getProgramData({|data| ~fxRevState = data });
~fx.delay.editor;
~fx.delay.getProgramData({|data| ~fxDelayState = data });

//a.writeToDisk("C:/Users/Mathias/AppData/Local/_data/Recordings/Tests/minimal-looper.wav");
//r.stop;
//a.stopPlayer;
//s.bind { ~createLooper.(s, 1, 10, speed:0.25); }
//
//
//{Env.asr(0.1, 1, 0.1, 0).ar(Done.freeSelf, Trig1.ar(1, 0.2))}.plot(0.3)
