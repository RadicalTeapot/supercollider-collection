(
var player = {
    |server, path, xfade=0.05|
    var synth, channels, env, updateStartEnd;
    var buf = Buffer.read(server, path);
    server.sync;
    channels = buf.numChannels;

    s.bind { synth = {
        var frames = BufFrames.ir(buf);
        var fade = BufSampleRate.ir(buf) * xfade;
        var start = \start.kr(0).clip(0, 1) * frames;
        var end = \end.kr(0).clip(0, 1) * frames;
        var phasor = Phasor.ar(\reset.tr(1), BufRateScale.ir(buf) * \speed.kr(1), start, end, start);
        var env = Env([0,1,1,0],[fade,abs(end-start-(2*fade)),fade]).as(LocalBuf);
        var offsetPhasor = Phasor.ar(\reset.tr(1), BufRateScale.ir(buf) * \speed.kr(1), start, end, end-fade);
        var offsetEnv = Env([0,0,1,0], [abs(end-start-(2*fade)), fade, fade]).as(LocalBuf);
        var sig = (BufRd.ar(channels, buf, phasor) * BufRd.ar(1, env, phasor)) + (BufRd.ar(channels, buf, offsetPhasor)
            * BufRd.ar(1, offsetEnv, offsetPhasor));
        Pan2.ar(sig);
    }.play;
    };
    (synth: synth, stopSynth: {|self| server.bind { synth.free; buf.free; }});
};
s = Server.default;
s.waitForBoot {
    s.free;
    Buffer.freeAll;
    s.sync;

    player.(s, "C:/Users/Mathias/AppData/Local/_data/Recordings/Loops/Thumb_Piano/Thumb_Piano01(120BPM).wav");
};
)

(
{
    var buf = Env([0,1,0], [0.5, 0.5]).discretize(16).as(LocalBuf);
    var phasor = Phasor.ar(rate: BufRateScale.ir(buf) * 10, start: 0, end: BufFrames.ir(buf));
    BufRd.ar(1, buf, phasor);
}.plot(0.1);
)
