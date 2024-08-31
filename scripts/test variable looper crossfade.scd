(
{
    var fadeTime = 0.1;
    var center = LFNoise2.ar(1).range(0.25, 0.75);
    var width = LFNoise2.ar(1).unipolar(0.5);
    var start = (center - width * 0.5).clip(0, 0.9);
    var end = (center + width * 0.5).clip(start+0.05, 1);

    var speeds = LocalBuf.newFrom([-0.5, -1, -2, 0.5, 1, 2]);

    var freq = (Index.ar(speeds, LFNoise0.ar(1).unipolar(6)).reciprocal * 0.1).lag(0.05); // Lag here makes tape speed up / down sounds ;)
    var currentPhasorIndex = ToggleFF.ar(LocalIn.ar);
    var resetTrigs = [1-currentPhasorIndex, currentPhasorIndex];
    var freqs = Gate.ar(freq, resetTrigs); // Only update the speed of the current phasor, probably not needed
    var phasors = Phasor.ar(resetTrigs, rate: freqs/SampleRate.ir, resetPos: Select.ar(freq>=0, [end, start]));
    var currentPhasor = Select.ar(currentPhasorIndex, phasors);
    // Only check boundaries in direction of travel (getting "caught-up" by the other bound doesn't trigger)
    var trig = Select.ar(freq >= 0, [
        currentPhasor < (start + (ControlRate.ir.reciprocal * freq.abs)),
        currentPhasor > (end - (ControlRate.ir.reciprocal * freq))
    ]);
    var xfade = Slew.ar(currentPhasorIndex, fadeTime.reciprocal, fadeTime.reciprocal);

    trig = 1 - SetResetFF.ar(Impulse.ar(fadeTime.reciprocal), trig); // Debounce trig so it doesn't happen faster than fade time

    LocalOut.ar(trig);
    SendReply.ar(Impulse.ar(30), '/values', [start, end, phasors[0], phasors[1], currentPhasorIndex, SelectX.ar(xfade, phasors)]);
}.play;

AppClock.sched(0, {
    var win, start, end, phasorA, phasorB, currentIndex, interpPhasor;
    Window.closeAll;

    win = Window(bounds: Rect(100, 100, 600, 100))
    .alwaysOnTop_(true)
    .background_(Color.white)
    .drawFunc_({
        var rect = win.bounds;
        var width = rect.width;
        var height = rect.height;
        var pos;

        Pen.fillColor_(Color.gray(0.5));
        Pen.addRect(Rect(start * width, 0, (end - start) * width, height));
        Pen.fill;

        [start, end].do {|v|
            pos = v * width;
            Pen.strokeColor_(Color.red);
            Pen.width_(2);
            Pen.moveTo(pos@0);
            Pen.lineTo(pos@height);
            Pen.stroke;
        };

        pos = interpPhasor * width;
        Pen.strokeColor_(Color.yellow);
        Pen.width_(1);
        Pen.moveTo(pos@0);
        Pen.lineTo(pos@height);
        Pen.stroke;

        [phasorA, phasorB].do {|v, i|
            pos = v * width;
            if (i == currentIndex.asInteger) { Pen.strokeColor_(Color.green) } { Pen.strokeColor_(Color.blue) };
            Pen.width_(2);
            Pen.moveTo(pos@0);
            Pen.lineTo(pos@height);
            Pen.stroke;
        };
    })
    .onClose_({CmdPeriod.run})
    .front;

    OSCFunc({ |msg| #start, end, phasorA, phasorB, currentIndex, interpPhasor = msg[3..]; defer { win.refresh }; }, '/values');
});
)