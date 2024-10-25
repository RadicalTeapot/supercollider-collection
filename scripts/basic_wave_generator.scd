(
var score, server, generators, synthDefGen, path;
server = Server(\nrt, options: ServerOptions.new.numOutputBusChannels_(1));

generators = (
    sine: {SinOsc.ar(\freq.kr(440))},
    saw: {Saw.ar(\freq.kr(440))},
    square: {Pulse.ar(\freq.kr(440))},
    triangle: {VarSaw.ar(\freq.kr(440))},
);

synthDefGen = {|func|
    SynthDef(\generator, {
        var sig = SynthDef.wrap(func);
        sig = sig * Env.asr(0.01, 1, 0.01).ar(Done.freeSelf, \gate.kr(0));
        sig = sig * \amp.kr(1);
        Out.ar(0, sig);
    });
};

score = Score([
    [0.0, ['/d_recv', synthDefGen.(generators[\sine]).asBytes]],
    [0.0, (x = Synth.basicNew(\generator, server, 1000)).newMsg(args: [\gate, 1])],
    [0.9, (x.setMsg(\gate, 0))],
    [1.0, ['/d_recv', synthDefGen.(generators[\saw]).asBytes]],
    [1.0, (x = Synth.basicNew(\generator, server, 1000)).newMsg(args: [\gate, 1])],
    [1.9, (x.setMsg(\gate, 0))],
    [2.0, ['/d_recv', synthDefGen.(generators[\square]).asBytes]],
    [2.0, (x = Synth.basicNew(\generator, server, 1000)).newMsg(args: [\gate, 1])],
    [2.9, (x.setMsg(\gate, 0))],
    [3.0, ['/d_recv', synthDefGen.(generators[\triangle]).asBytes]],
    [3.0, (x = Synth.basicNew(\generator, server, 1000)).newMsg(args: [\gate, 1])],
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

        ("sox \""++(path++".wav")++"\" -n spectrogram -x 1920 -y 513 -z 80 -r -s -w hamming -o \""++(path++".png")++"\"").unixCmd({"Done generating spectogram".postln});
    }
);

server.remove;
// Uncomment if running from the CLI
// 0.exit;
)