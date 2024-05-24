(
var score, server;
server = Server(\nrt,
    options: ServerOptions.new
    .numOutputBusChannels_(2)
);

score = Score([
    [0.0, ['/d_recv', SynthDef(\NRTnoise, {
        arg t_gate;
        var sig, env, out;
        sig = WhiteNoise.ar();
        env = EnvGen.ar(Env.new([0,1], [1]), t_gate, doneAction:Done.freeSelf);
        sig = BPF.ar(sig, env*19990+10, 0.1); // Start at 10Hz to avoid discontinuities due to BPF implementation
        Out.ar(0, sig.dup)
    }).asBytes]],
    [0.0, (x = Synth.basicNew(\NRTnoise, server, 1000)).newMsg(args: [\t_gate, 1])],
]);

score.recordNRT(
    outputFilePath: "~/AppData/Local/_data/Supercollider/recordings/noise.wav".standardizePath,
    headerFormat: "wav",
    sampleFormat: "int16",
    options: server.options,
    duration: 1,
    action: {"done".postln}
);

server.remove;
)