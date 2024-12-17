(
s = Server.default;
s.waitForBoot {
    var env, offsetEnv, shaperBuf, offsetShaperBuf, soundBuf, player, xfade=0.1;
    s.free;
    s.sync;

    env = Env.xyc([[0,0], [xfade, 1], [1,1]]); // Crossfade profile
    offsetEnv = Env.xyc([[0, 1-xfade], [xfade, 1], [xfade, 0], [1, 1-xfade]]); // Offset phasor profile
    shaperBuf = Buffer.loadCollection(s, env.asSignal(1024).asWavetable);
    offsetShaperBuf = Buffer.loadCollection(s, offsetEnv.asSignal(1024).asWavetable);
    soundBuf = Buffer.read(s, "C:/Users/mathi/AppData/Local/_data/recordings/field_recordings/music_box_1.wav", 5.4 * s.sampleRate);
    s.sync;

    /*{
        var start = 0;
        var end = 1;
        var rate = 1;
        var phasor = Phasor.ar(rate: rate * 200/s.sampleRate, start: start, end: end, resetPos: start);
        var offset = Osc.ar(offsetShaperBuf, 0, phasor.linlin(start, end, 0, 2pi)).linlin(0, 1, start, end);
        var mix = Osc.ar(shaperBuf, 0, phasor.linlin(start, end, 0, 2pi));
        [phasor, offset, mix, Select.ar(mix, [offset, phasor])]
    }.plot;*/

    player = {
        var start = \start.kr(0).clip(0, 1) * BufFrames.ir(soundBuf);
        var end = \end.kr(1).clip(0, 1) * BufFrames.ir(soundBuf) - start;
        var speed = \speed.kr(1);
        var retrig = \trig.tr(0);
        var phasor = Phasor.ar(retrig, BufRateScale.ir(soundBuf) * speed, end: end);
        var offset = Osc.ar(offsetShaperBuf, 0, phasor.linlin(start, end, 0, 2pi)).linlin(0, 1, start, end);
        var mix = Osc.ar(shaperBuf, 0, phasor.linlin(start, end, 0, 2pi));
        SelectX.ar(mix, [
            BufRd.ar(2, soundBuf, offset + start), // Modulo not needed here as BufRd loops by default
            BufRd.ar(2, soundBuf, phasor + start)
        ]);
    }.play;

    Routine { loop {
        var time = rrand(0.2, 4);
        var start = exprand(0.01, 0.75) - 0.01;
        var end = rrand(start + 0.1, 1);
        var speed = [0.25, 0.5, 1, 2, 4].choose * [-1, 1].choose;
        s.bind { player.set(\speed, speed, \start, start, \end, end, \trig, 1) };
        time.yield;
    } }.play;
};
)