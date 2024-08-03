(
var synthsToClear = Array.new();
var clearRoutine = Routine({while ({synthsToClear.size > 0}) {
    s.bind {
        var removed = Array.new();
        synthsToClear.do { |synth, i| if (synth.isRunning) {
            synth.free;
            removed = removed.add(i);
        } };
        removed.reverseDo { |index| synthsToClear.removeAt(index) };
    };
    "Cleared".postln;
    s.latency.yield;
};
"Done clearing".postln;
});

var currentSynths = Array.new();

var screen = Window.availableBounds;
var win = Window("test", Rect((screen.width-100)/2, (screen.height+50)/2, 100, 50)).onClose_({CmdPeriod.run});
var nb = NumberBox().action_({
    // Register current synths to be cleared
    synthsToClear = synthsToClear.addAll(currentSynths);

    // Set new current synths
    currentSynths = 16.collect { |i|
        var synth = SynthDef(("synth"++i).asSymbol, {
            Phasor.kr(ControlDur.ir) + Array.interpolation(16) % 1;
        }).play(s);
        NodeWatcher.register(synth); // Register synth so it's state can be tracked later
        synth;
    };
    if (clearRoutine.isPlaying.not) {clearRoutine.reset.play;}
});
win.layout_(
    VLayout(nb)
);
win.front;
)