(
~createLooper = {
    |server, id, duration, channels=2, in=0, out=0, speed=1, xfadeDuration=0.1|
    var recorder, player;
    var path = '/play'++id;
    var frames = duration * server.sampleRate;
    var buffer = Buffer.alloc(server, frames, channels);
    buffer.zero;
    s.sync;
    recorder = {
        var gate = Trig1.ar(1, duration);
        var phase = Phasor.ar(gate, BufRateScale.ir(buffer), 0, BufFrames.ir(buffer));
        var sig = SelectX.ar(gate.lag(xfadeDuration), [BufRd.ar(channels, buffer, phase), In.ar(in, channels)]);
        BufWr.ar(sig, buffer, phase, 0);
        SendReply.ar(1-gate, path);
        FreeSelf.kr(1-gate);
        Out.ar(out, Silent.ar(channels));
    }.play;
    player = {
        // Lag here is just for fun, remove it (or make it modulable)
        var rate = \speed.kr(speed).lag(0.3);
        var trig = \trig.tr(0);
        var playGate = SetResetFF.ar(T2A.ar(trig), 0).lag(0.1);
        var phase = Phasor.ar(trig, BufRateScale.ir(buffer) * rate, 0, BufFrames.ir(buffer));
        var sig = BufRd.ar(channels, buffer, phase) * playGate * \amp.kr(-6.dbamp);
        Out.ar(out, sig);
    }.play;
    OSCFunc({player.set(\trig, 1)}, path).oneShot;
    (player: player, stopPlayer: { player.free; buffer.free; });
}
)

(
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
    s.sync;

    Routine { loop {
        var note = Scale.minorPentatonic.performDegreeToKey(rrand(0, 10));
        var root = 48;
        var pan = rrand(-1.0, 1.0);
        s.bind { Synth(\simple, [freq: (note+root).midicps, dur: 0.125, pan: pan]) };
        0.5.yield;
    }}.play;
};
)

s.bind { a = ~createLooper.(s, 0, 3, speed:2); };
r = Routine { loop { a.player.set(\speed, [-2, -1, -0.5, 0.5, 1, 2].choose); 2.yield; }}.play;
r.stop;
a.stopPlayer;
s.bind { ~createLooper.(s, 1, 10, speed:0.25); }
