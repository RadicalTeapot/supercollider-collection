~useAudioInterface.();

(
{
    var wavetableFile, flatArray, arrayAsWavetable;
    // Load wavetable data an store it into an array
    wavetableFile = SoundFile.openRead(thisProcess.nowExecutingPath.dirname ++ "/data/PLAITS01.WAV");
    flatArray = FloatArray.newClear(wavetableFile.numFrames);
    wavetableFile.readData(flatArray);
    wavetableFile.close;

    // Split the flat array into sub arrays
    ~array = Array2D.fromArray(flatArray.size/256, 256, flatArray);

    // Convert the plain arrays to a wavetable format
    arrayAsWavetable = ~array.rows.asInteger.collect({|rowIndex| ~array.rowAt(rowIndex).as(Signal).asWavetable});

    // Create the buffers and load the wavetable data into them
    Buffer.freeAll;
    ~wavetableBuffers = Buffer.allocConsecutive(64, s, 512);
    ~wavetableBuffers.do({|buf, i|
        buf.loadCollection(arrayAsWavetable[i]);
    });
}.();
)

(
SynthDef(\wv, {
    |amp=0.25, freq=440, pos=0, atk=0.05, rel=1, dur=1|
    var sig, env, detune;
    detune = LFNoise2.kr(0.5!8).bipolar(0.1).midiratio;
    pos = (~wavetableBuffers.first.bufnum + pos * ~wavetableBuffers.size).clip(~wavetableBuffers.first.bufnum, ~wavetableBuffers.last.bufnum) * LFNoise2.kr(1!8).bipolar(1).midiratio;
    sig = VOsc.ar(pos, freq * detune);
    env = Env.perc(atk, rel).kr(2, timeScale: dur);
    sig = Splay.ar(sig) * env;
    sig = LeakDC.ar(sig) * amp;
    Out.ar(0, sig);
}).add;
)

(
{
    // Do kind of a Awake sequencing
    var seq1 = 11.collect({rrand(-5, 7)}).postln;
    var seq2 = 7.collect({[0,3,5,7].wchoose([10, 2, 1, 3].normalizeSum)}).postln;
    Pdefn(\pos, 0);
    Pdefn(\speed, 1);
    Pbind(
        \instrument, \wv,
        \dur, Prand([0.5, 1, Rest(0.5)], inf) * Pdefn(\speed),
        \rel, Pexprand(1, 10, inf),
        \midinote, p { var index = 0; loop { var value = (48 + seq1.wrapAt(index) + seq2.wrapAt(index)).nearestInScale(Scale.minorPentatonic.degrees); value.yield; index = index + 1; } },
        \pos, Pdefn(\pos)
    ).play;
}.();
)

(
s.newBusAllocators;
~lfoBus = Bus.control(s);
~controlBus = Bus.control(s, 4);
// ~controlBus.setnSynchronous([0.515, 0.04, 0.003, 0.25]);
~controlBus.setnSynchronous([0.118, 0.01, 0.002, 0.5]);
~lfo = {|freq=0.02|LFTri.kr(freq)}.play(outbus: ~lfoBus);
)

(
{
    var window;

    Window.closeAll;

    window = Window("Settings", Rect(200, 200, 400, 350)).front;
    window.alwaysOnTop_(true);
    window.layout = VLayout(
        GridLayout.rows(
            {
                var slider, numberbox, controlspec;
                controlspec = ControlSpec(0, 1, 'lin', 0.001, 0.0);
                slider = Slider().orientation_(\horizontal).action_({
                    var value = controlspec.map(slider.value);
                    numberbox.value_(value);
                    ~controlBus.setAt(0, value);
                });
                numberbox = NumberBox()
                .value_(~controlBus.getnSynchronous(~controlBus.numChannels)[0])
                .clipLo_(0.0)
                .clipHi_(1.0)
                .maxDecimals_(3)
                .scroll_step_(0.01)
                .maxWidth_(100)
                .action_({
                    var value = controlspec.unmap(numberbox.value);
                    slider.value_(value);
                    ~controlBus.setAt(0, numberbox.value);
                });
                numberbox.action.();
                [StaticText().string_("Position"), slider, numberbox];
            }.(),
            {
                var slider, numberbox, controlspec;
                controlspec = ControlSpec(0.0001, 1, 3, 0.0001, 0.0);
                slider = Slider().orientation_(\horizontal).action_({
                    var value = controlspec.map(slider.value);
                    numberbox.value_(value);
                    ~lfo.set(\freq, value);
                });
                numberbox = NumberBox()
                .value_(0.02)
                .clipLo_(0.0)
                .clipHi_(1.0)
                .maxDecimals_(4)
                .scroll_step_(0.01)
                .maxWidth_(100)
                .action_({
                    var value = controlspec.unmap(numberbox.value);
                    slider.value_(value);
                    ~lfo.set(\freq, value);
                });
                numberbox.action.();
                [StaticText().string_("LFO freq"), slider, numberbox];
            }.(),
            {
                var slider, numberbox, controlspec;
                controlspec = ControlSpec(0.00001, 1, 5, 0.00001, 0.0);
                slider = Slider().orientation_(\horizontal).action_({
                    var value = controlspec.map(slider.value);
                    numberbox.value_(value);
                    ~controlBus.setAt(1, value);
                });
                numberbox = NumberBox()
                .value_(~controlBus.getnSynchronous(~controlBus.numChannels)[1])
                .clipLo_(0.0)
                .clipHi_(1.0)
                .maxDecimals_(4)
                .scroll_step_(0.001)
                .maxWidth_(100)
                .action_({
                    var value = controlspec.unmap(numberbox.value);
                    slider.value_(value);
                    ~controlBus.setAt(1, numberbox.value);
                });
                numberbox.action.();
                [StaticText().string_("LFO range"), slider, numberbox];
            }.(),
            {
                var slider, numberbox, controlspec;
                controlspec = ControlSpec(0.00001, 1, 5, 0.00001, 0.0);
                slider = Slider().orientation_(\horizontal).action_({
                    var value = controlspec.map(slider.value);
                    numberbox.value_(value);
                    ~controlBus.setAt(2, value);
                });
                numberbox = NumberBox()
                .value_(~controlBus.getnSynchronous(~controlBus.numChannels)[2])
                .clipLo_(0.0)
                .clipHi_(1.0)
                .maxDecimals_(5)
                .scroll_step_(0.01)
                .maxWidth_(100)
                .action_({
                    var value = controlspec.unmap(numberbox.value);
                    slider.value_(value);
                    ~controlBus.setAt(2, numberbox.value);
                });
                numberbox.action.();
                [StaticText().string_("Rand range"), slider, numberbox];
            }.(),
            {
                var slider, numberbox, controlspec;
                controlspec = ControlSpec(0.025, 1, 'lin', 0.025, 0.0);
                slider = Slider().orientation_(\horizontal).action_({
                    var value = controlspec.map(slider.value);
                    numberbox.value_(value);
                    ~controlBus.setAt(3, value);
                });
                numberbox = NumberBox()
                .value_(~controlBus.getnSynchronous(~controlBus.numChannels)[3])
                .clipLo_(0.0)
                .clipHi_(1.0)
                .maxDecimals_(3)
                .scroll_step_(0.025)
                .maxWidth_(100)
                .action_({
                    var value = controlspec.unmap(numberbox.value);
                    slider.value_(value);
                    ~controlBus.setAt(3, numberbox.value);
                });
                numberbox.action.();
                [StaticText().string_("Speed"), slider, numberbox];
            }.()
        ),
        ~plot = SoundFileView(),
    );

    CmdPeriod.doOnce({window.close});
}.();

Pdefn(\pos, Pfunc({
    var controlValues = ~controlBus.getnSynchronous(~controlBus.numChannels);
    var pos = controlValues[0];
    pos = pos + ~lfoBus.getSynchronous().linlin(-1, 1, controlValues[1]*(-1), controlValues[1]);
    pos = pos + rrand(controlValues[2]*(-1), controlValues[2]);
    {
        var index = pos * ~wavetableBuffers.size;
        var firstIndex = (index.floor.clip(0, ~wavetableBuffers.size-1)).asInteger;
        var lastIndex = (index.ceil.clip(0, ~wavetableBuffers.size-1)).asInteger;
        ~plot.setData([
            ~array.rowAt(firstIndex),~array.rowAt(lastIndex)
        ].blendAt(index.frac), 256, samplerate: 256);
        ~plot.refresh
    }.defer;
    pos;
}));

Pdefn(\speed, Pfunc({~controlBus.getnSynchronous(~controlBus.numChannels)[3]}));

)