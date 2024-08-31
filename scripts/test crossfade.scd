(
// With feedback - not practical
{
    var freq = 20;
    var rate = freq / SampleRate.ir;
    var fadeTime = 0.005; // In seconds
    var offset = fadeTime * SampleRate.ir;

    // Get index of phasor to use as current phasor
    var currentPhasorIndex = LocalIn.ar;
    // Reset phasor that is the becoming the new one (signal will jump from 0 to 1 for the new current phasor when index changes)
    var phasorsResetTrigger = [1-currentPhasorIndex, currentPhasorIndex];
    // Create the two phasors reseting when appropriate
    var phasors = Phasor.ar(phasorsResetTrigger, rate);
    // Pick the current phasor
    var currentPhasor = Select.ar(currentPhasorIndex, phasors);
    // Compute the normalized value at which the current phasor should change so the transition is complete over fadeTime seconds
    // Note: ControlRate time in seconds is added to account for LocalIn / LocalOut being updated only once per block size of samples (see help of LocalIn for more details)
    var resetThreshold = 1-((fadeTime + ControlRate.ir.reciprocal) * freq);
    // Compute current phasor index value for next run
    var nextPhasorIndex = ToggleFF.ar(currentPhasor > resetThreshold);
    // Compute crossfade signal
    // Note: nextPhasorIndex is not used as it's offset by ControlRate time in seconds, crossfade instead starts when index actually changes
    var crossfade = Slew.ar(ToggleFF.ar(Changed.ar(currentPhasorIndex)), fadeTime.reciprocal, fadeTime.reciprocal);

    var sig = SelectX.ar(crossfade, phasors);
    LocalOut.ar(nextPhasorIndex);
    [phasors[0], phasors[1], nextPhasorIndex, crossfade, sig];
}.plot(0.3);
)

(
// Without feedback - much better :)
{
    var duration = 0.05;  // Time for the signal to repeat, in seconds
    var fadeTime = 0.005; // In seconds

    var resetFreq = duration.reciprocal;
    var resetTrig = Impulse.ar(resetFreq, fadeTime * resetFreq);

    // Toggle current phasor index when reseting
    var currentPhasorIndex = ToggleFF.ar(resetTrig);
    // Reset phasor that is the becoming the current one (signal will jump from 0 to 1 for the new current phasor when index changes)
    var phasorsResetTrigger = [1-currentPhasorIndex, currentPhasorIndex];

    var phasors = Phasor.ar(phasorsResetTrigger, 1, 0, SampleRate.ir); // Assuming the buffer lasts 1 sec at same sample rate as server

    var crossfade = Slew.ar(currentPhasorIndex, fadeTime.reciprocal, fadeTime.reciprocal);

    var sig = SelectX.ar(crossfade, phasors);
    [phasors[0], phasors[1], currentPhasorIndex, crossfade, sig];
}.plot(0.3, separately: true);
)

(
// Full example for buffer
s.waitForBoot {
    var buf;
    Buffer.freeAll;

    // In the case here, the amount of buffer looped is not directly controlled.
    // The loop duration is constant and controlled using freq, changing the speed
    // sets the amount of content that is read by each loop.
    // It would be quite easy to change the implementation so the amount looped is constant
    // but the loop duration is dependent on the speed.
    SynthDef(\crossfadeLooper, {
        var buf = \buf.kr(0);
        var freq = \freq.kr(1);
        var start = \start.kr(0); // Normalized
        var speed = \speed.kr(1);
        var fadeTime = \fadeTime.kr(0.01).max(freq.reciprocal * 0.5); // In seconds, independent of speed or freq
        var atk = \atk.kr(0.1);
        var rel = \rel.kr(0.1);
        var gate = \gate.kr(0);
        var amp = \amp.kr(0.5);
        var out = \out.ir(0);

        var resetTrig = Impulse.ar(freq, fadeTime * freq);
        var currentPhasorIndex = ToggleFF.ar(resetTrig);

        var phasorsResetTrigger = [1-currentPhasorIndex, currentPhasorIndex];
        var rate = BufRateScale.kr(buf) * speed;
        var bufFrames = BufFrames.kr(buf);
        var phasors = Phasor.ar(phasorsResetTrigger, rate, start * bufFrames, bufFrames);

        var crossfade = Slew.ar(currentPhasorIndex, fadeTime.reciprocal, fadeTime.reciprocal);

        var bufValues = BufRd.ar(1, buf, phasors);
        var sig = SelectX.ar(crossfade, bufValues);
        sig = sig * Env.asr(atk, 1, rel).ar(Done.freeSelf, gate);
        sig = sig.dup * amp;
        Out.ar(out, sig);
    }).add;
    s.sync;

    buf = Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01.wav");
    s.sync;

    Routine {
        loop {
            var pos = rrand(0.0, 1.0);
            var speed = [0.5, 1, 2, 4].choose * [-1, 1].choose;
            var freq = exprand(1, 8);
            var synth;
            s.bind { synth = Synth(\crossfadeLooper, [buf: buf, freq: freq, start: pos, speed: speed, gate: 1]) };
            [0.25, 0.5, 1, 2, 4].choose.wait;
            s.bind{ synth.set(\gate, 0) };
            1.wait;
        }
    }.play;
}
)