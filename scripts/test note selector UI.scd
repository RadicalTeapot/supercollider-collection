(
var win, nb, toMidiNoteString, note = 0, dragging=false, lastY = 0;

toMidiNoteString = {
    var notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    {|value|
        notes[value%12]+((value/12).asInteger - 2);
    };
}.();

Window.closeAll;
win = Window(bounds: Rect(500, 250, 100, 80)).alwaysOnTop_(true);
nb = NumberBox()
.string_(toMidiNoteString.(note))
.keyDownAction_({|view, char, modifiers, unicode, keycode, key|
    if (keycode == 38) {note = note+1};
    if (keycode == 40) {note = note+1};
    note = note.clip(0, 127);
    view.string_(toMidiNoteString.(note.asInteger));
})
.mouseDownAction_({|view, x, y, modifiers, button, clickCount|
    dragging = (button==0);
    lastY = y;
    true; // Mark event as processed
})
.mouseMoveAction_({|view, x, y, modifiers, button, clickCount|
    if (dragging) {
        var dir = (y - lastY) / 20;
        var speed = 1;
        if (modifiers == 131072) { speed = 12 }; // If shift is pressed, jump an octave
        if (dir > 1) {note = note+speed; lastY = y; };
        if (dir < -1) {note = note-speed; lastY = y; };
        note = note.clip(0, 127);
    };
    view.string_(toMidiNoteString.(note));
    true;
} )
.mouseUpAction_({|view, x, y, modifiers, button, clickCount|
    dragging = false;
    true;
});
win.layout_(VLayout(nb));
win.front;
)