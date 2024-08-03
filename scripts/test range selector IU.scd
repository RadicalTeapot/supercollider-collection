(
var win, loLabel, loNote, hiLabel, hiNote, rangeSlider, toMidiNoteString;
loNote = 0;
hiNote = 127;

toMidiNoteString = {
    var notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    {|value|
        notes[value%12]+((value/12).asInteger - 2);
    };
}.();

loLabel = NumberBox()
.clipLo_(0).clipHi_(127).step_(1).scroll_step_(1).ctrl_scale_(12).shift_scale_(24).alt_scale_(1).decimals_(0)
.string_(toMidiNoteString.(loNote))
.focusGainedAction_({|view| view.value_(loNote)})
.focusLostAction_({|view| view.string_(toMidiNoteString.(loNote))})
.keyDownAction_({|view, char, modifiers, unicode, keycode, key| if (keycode == 27) {view.focus(false)}}) // defocus on esc key
.action_({ |view| loNote = view.value.asInteger; rangeSlider.lo_(loNote/127); });

hiLabel = NumberBox()
.clipLo_(0).clipHi_(127).step_(1).scroll_step_(1).ctrl_scale_(12).shift_scale_(24).alt_scale_(1).decimals_(0)
.string_(toMidiNoteString.(hiNote))
.focusGainedAction_({|view| view.value_(hiNote)})
.focusLostAction_({|view| view.string_(toMidiNoteString.(hiNote))})
.keyDownAction_({|view, char, modifiers, unicode, keycode, key| if (keycode == 27) {view.focus(false)}}) // defocus on esc key
.action_({|view| hiNote = view.value.asInteger; rangeSlider.hi_(hiNote/127); });

rangeSlider = RangeSlider()
.step_(127.reciprocal).lo_(loNote).hi_(hiNote).ctrl_scale_(12).shift_scale_(24).alt_scale_(1)
.action_({|view|
    loNote = (view.lo * 127).floor.asInteger; loLabel.string_(toMidiNoteString.(loNote));
    hiNote = (view.hi * 127).floor.asInteger; hiLabel.string_(toMidiNoteString.(hiNote));
});

Window.closeAll;
win = Window.new(bounds: Rect(100, 300, 400, 70))
.alwaysOnTop_(true)
.layout_(
    VLayout(
        rangeSlider.orientation_(\horizontal),
        HLayout([loLabel, align: \left], [hiLabel, align: \right])
    )
)
.front;
)