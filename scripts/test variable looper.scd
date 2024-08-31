(
{
    var center = LFNoise2.ar(1).range(0.25, 0.75);
    var width = LFNoise2.ar(1).unipolar(0.5);
    var start = (center - width * 0.5).clip(0, 0.9);
    var end = (center + width * 0.5).clip(start+0.05, 1);

    var speeds = LocalBuf.newFrom([-0.5, -1, -2, 0.5, 1, 2]);

    var freq = Index.ar(speeds, LFNoise0.ar(1).unipolar(6)).reciprocal * 0.1;
    var resetTrig = LocalIn.ar;
    var phasor = Phasor.ar(resetTrig, rate: freq/SampleRate.ir, start: start, end: end, resetPos: Select.ar(freq >=0, [end, start]));
    var trig = Select.ar(freq >= 0, [
        phasor < (start + (ControlRate.ir.reciprocal * freq.abs)),
        phasor > (end - (ControlRate.ir.reciprocal * freq))
    ]);

    LocalOut.ar(trig);
    SendReply.ar(Impulse.ar(30), '/values', [start, end, phasor]);
}.play;

AppClock.sched(0, {
    var win, start, end, phasor;
    Window.closeAll;

    win = Window(bounds: Rect(100, 100, 300, 100))
    .alwaysOnTop_(true)
    .background_(Color.white)
    .drawFunc_({
        var rect = win.bounds;
        var width = rect.width;
        var height = rect.height;

        Pen.fillColor_(Color.gray(0.5));
        Pen.addRect(Rect(start * width, 0, (end - start) * width, height));
        Pen.fill;

        [start, end, phasor].do {|v, i|
            var pos = v * width;
            Pen.strokeColor_([Color.red, Color.red, Color.green][i]);
            Pen.width_(2);
            Pen.moveTo(pos@0);
            Pen.lineTo(pos@height);
            Pen.stroke;
        }
    })
    .onClose_({CmdPeriod.run})
    .front;

    OSCFunc({ |msg| #start, end, phasor = msg[3..]; defer { win.refresh }; }, '/values');
});
)