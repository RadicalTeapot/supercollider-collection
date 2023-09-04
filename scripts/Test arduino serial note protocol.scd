(
p = SerialPort(
    "COM5",    //edit to match your port. SerialPort.listDevices
    baudrate: 31250,    //check that baudrate is the same as in arduino sketch
    xonxoff: true);
)
p.isOpen;

~useAudioInterface.();

(
~decomposeTo7BitNumbers = {
    |value = 0|
    var msb, lsb;
    value = value & 16383; // 0x3FF, 14bit
    msb = (value >> 7) & 127; // 0x7F, 7bit
    lsb = value & 127; // 0x7F, 7bit
    [msb, lsb];
};

~smoothDist = {
    |size, center|
    var a = Array.fill(size, {|i| abs(center - i)}).normalize;
    a.collectInPlace({|item| ((-1*cos((1-item)*pi))+1) / 2});
    a
};

~notes = [12, 24] +.x Scale.dorian.degrees;
~probabilities = ([2, 1] *.x [1, 0.1, 0.4, 0.2, 0.3, 0.6, 0.2]); // Emphasis on the lower octave and 1, b3 and 6
~weightShift = ~probabilities.collect({ 1 }); // Shift weights to avoid repeating the same note multiple times
~smoothedDist = ~probabilities.collect({1}); // Make notes further from last one less likely

// TODO use control bus to shift probabilities (using addition rather than multiplication) with a slow LFO
// TODO use control bus to modulate durations (index into an array that multiplies the dur value)

Pbind(
    \type, \rest,
    // \dur, Prand([0.125, 0.25], inf),
    // \gateLength, Pkey(\dur) * 250,
    \dur, Prand([4, 8, 16], inf),
    \note, Pwrand(~notes, (~probabilities * ~weightShift * ~smoothedDist).normalizeSum, inf),
    \gateLength, Pkey(\dur) * Pwhite(0.2, 0.5) * 1000,
).collect({
    |ev|
    var noteIndex = 0;
    var gateLengthBytes = ~decomposeTo7BitNumbers.(ev.gateLength.asInteger);
    var data = Int8Array[130, ev.note, 146, gateLengthBytes[0], gateLengthBytes[1]];
    p.putAll(data);

    ~weightShift.collectInPlace({|item, i| if (~notes[i] == ev.note) {noteIndex = i; item * 0.9} { 1 } });
    ~smoothedDist = ~smoothDist.(~weightShift.size, noteIndex).squared;

    ev;
}).play;

Pbind(
    \type, \rest,
    \dur, Pwrand([0.25, 0.5, 1], [0.5, 0.35, 0.15], inf),
    \note, Prand(Scale.minorPentatonic.degrees, inf)+24,
).collect({|ev|
    var data = Int8Array[131, ev.note, 147, 0, 20]; // Fixed gate length of 20ms
    p.putAll(data);
    ev;
}).play;

{
    var sig = SoundIn.ar(0);
    Out.ar(0, sig.dup * 0.75);
}.play
)

p.close;