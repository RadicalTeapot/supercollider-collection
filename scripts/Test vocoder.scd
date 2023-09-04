~useAudioInterface.();

(
~getWavetableBuffers = { |filePath, tableSize=256|
    var wavetableFile, flatArray, tableCount, tablesData, buffers;

    // Load wavetable data an store it into an array
    wavetableFile = SoundFile.openRead(filePath);
    flatArray = FloatArray.newClear(wavetableFile.numFrames);
    wavetableFile.readData(flatArray);
    wavetableFile.close;

    // Get number of wavetables in the array
    tableCount = (flatArray / tableSize).asInteger;

    // Convert the array to a wavetables
    tablesData = tableCount.collect({|v, tableIndex|
        flatArray[(tableIndex*tableSize)..((tableIndex+1)*tableSize-1)].as(Signal).asWavetable
    });

    // Create the buffers and load the wavetable data into them
    buffers = Buffer.allocConsecutive(64, s, 512);
    buffers.do({|buf, i| buf.loadCollection(tablesData[i]) });

    buffers;
};
)

(
Buffer.freeAll;
t = ~getWavetableBuffers.(thisProcess.nowExecutingPath.dirname ++ "/data/ANALOG_W.WAV");
)
t[10].plot;

(
SynthDef(\vwt, {
    |amp=0.25, freq=440, carFreq=440, wtPos=0, bands=8, q=0.02|
    var sig;
    wtPos = (wtPos.clip(0, 1).linlin(0, 1, t.first.bufnum+0.01, t.last.bufnum-0.01));
    sig = VOsc.ar(wtPos.varlag(0.1), freq);
    sig = Vocoder.ar(SinOsc.ar(carFreq), sig, 8, q: q);
    Out.ar(0, (sig!2) * amp);
}).add;
)

// This can get loud, BE CAREFUL
x = Synth(\vwt,[amp: 0.01, bands: 512]);
x.set(\freq, 500, \amp, 0.1);
Routine{ var pos = 0.0; loop { x.set(\wtPos, pos); pos = (pos+0.01).frac; (0.1).yield} }.play;