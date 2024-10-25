(
var score, server, path;
server = Server(\nrt, options: ServerOptions.new.numOutputBusChannels_(1));

score = Score([
    [0.0, ['/d_recv', SynthDef(\generator, {
        var count = 24;
        var sig = count.collect { |i|
            var lfoAmp = Env([0, 0, 1, 0, 0], [1, 1, 1, 1]).ar(Done.none, \gate.kr(0)).lincurve * i.bilin(count*0.5, count * 0.25, count * 0.75, 1.0, 0.0, 0.0);
            var lfo = SinOsc.ar(4, i*2).bipolar(lfoAmp).midiratio;
            var freq = 440 * (i+1) * 2 * lfo;
            SinOsc.ar(freq) * count.reciprocal * 0.8;
        }.sum;
        sig = sig * Env.asr(0.1, 1, 0.1).ar(Done.freeSelf, \gate.kr(0));
        sig = sig * \amp.kr(1);
        Out.ar(0, sig);
    }).asBytes]],
    [0.0, (x = Synth.basicNew(\generator, server, 1000)).newMsg(args: [\gate, 1])],
    [3.9, (x.setMsg(\gate, 0))],
]);

path = "~/AppData/Local/_data/Supercollider/recordings/test".standardizePath;
score.recordNRT(
    outputFilePath: path++".wav",
    headerFormat: "wav",
    sampleFormat: "int16",
    options: server.options,
    duration: 4,
    action: {
        "Done generating, making spectogram".postln;

        ("sox \""++(path++".wav")++"\" -n spectrogram -x 1920 -y 1025 -z 80 -r -s -w hamming -o \""++(path++".png")++"\"").unixCmd({"Done generating spectogram".postln});
    }
);

server.remove;
// Uncomment if running from the CLI
// 0.exit;
)

(0..24).bilin(12, 0, 24, 1.0, 0.0, 0.0)