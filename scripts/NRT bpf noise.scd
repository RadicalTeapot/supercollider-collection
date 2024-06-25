(
var score, server;
server = Server(\nrt, options: ServerOptions.new.numOutputBusChannels_(2));

score = Score([
    [0.0, ['/d_recv', SynthDef(\NRTnoise, {
        var sig, freq, out;
        sig = WhiteNoise.ar();
        freq = Line.ar(10, 20000, 1, doneAction: Done.freeSelf);
        sig = BPF.ar(sig, freq, 0.1);
        sig = Pan2.ar(sig, 0);
        Out.ar(0, sig);
    }).asBytes]],
    [0.0, (x = Synth.basicNew(\NRTnoise, server, 1000)).newMsg],
]);

score.recordNRT(
    outputFilePath: (Platform.recordingsDir++"\\noise.wav").standardizePath,
    headerFormat: "wav",
    sampleFormat: "int16",
    options: server.options,
    duration: 1,
    action: {"done".postln}
);

server.remove;
)