(
var loadConvolutionBuffers = { |server, path, fftSize|
    var irBuffers;
    var buffers = [Buffer.readChannel(server, path, channels: [0]), Buffer.readChannel(server, path, channels: [1])];
    server.sync;
    irBuffers = buffers.collect{ |buf|
        var irBufferSize = PartConv.calcBufSize(fftSize, buf);
        var irBuffer = Buffer.alloc(server, irBufferSize, 1);
        irBuffer.preparePartConv(buf, fftSize);
    };
    server.sync;
    buffers.do{|buf| buf.free };
    irBuffers;
};

s = Server.default;
s.waitForBoot {
    var fftSize = 2**14, path="C:/Users/mathi/AppData/Local/_data/recordings/Impulse responses/Saint Peter's Cathedral Saintes - Bitwig.wav", irBuffers, delayBuf;
    s.free;
    Buffer.freeAll;
    s.sync;

    irBuffers = loadConvolutionBuffers.(s, path, fftSize);
    delayBuf = Buffer.alloc(s, 2 * s.sampleRate, 2);
    s.sync;

    {
        var sig = VarSaw.ar(\freq.kr(440)!2);
        sig = sig * Env.perc.ar(Done.none, Impulse.ar(0.1));
        sig = sig.blend(PartConv.ar(sig, fftSize, irBuffers, 0.5), 0.2);
        sig = sig.blend(Splay.ar(BufCombN.ar(delayBuf, sig, [1, 1.5], 5), 0.75), 0.2);
    }.play;
}
)