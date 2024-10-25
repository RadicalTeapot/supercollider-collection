(
var score, server, path, defs, baseFreq, freqs, freqCount, lfoGen, synthDefGen;
server = Server(\nrt, options: ServerOptions.new.numOutputBusChannels_(1));

baseFreq = 440;
freqCount = (22050 / baseFreq).asInteger;
freqs = Array.series(freqCount, baseFreq, baseFreq);

lfoGen = {
    var amp = Env([0, 0, 1, 0], [1, 1, 1]).ar(Done.none, \gate.kr(0)).lincurve; // DASR env
    SinOsc.ar(2).bipolar(amp).midiratio;
};

defs = (
    sine: {
        var freq = freqs[(freqCount/2).asInteger] * SynthDef.wrap(lfoGen);
        SinOsc.ar(freq);
    },
);

synthDefGen = { |func|
    SynthDef(\generator, {
        var sig = SynthDef.wrap(func);
        sig = sig * Env.asr(0.1, 1, 0.1).ar(Done.freeSelf, \gate.kr(0));
        sig = sig * \amp.kr(1);
        Out.ar(0, sig);
    });
};

score = Score([
    [0.0, ['/d_recv', synthDefGen.(defs[\sine]).asBytes]],
    [0.0, (x = Synth.basicNew(\generator, server, 1000)).newMsg(args: [\amp, -3.dbamp, \gate, 1])],
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
