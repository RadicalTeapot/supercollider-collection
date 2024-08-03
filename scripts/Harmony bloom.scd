// TODO Implement note picker with drop down menu (PopupMenu) and link notes to points (via synth by providing the list there and sending note via reply)
// Add quantized offset
// Add probability
// Add more max points (try 64)
// Expose freq control (as BPM)
// Write a smarted MIDI note on / note off (to tackle fast triggering)
// Extract all GUI as class
(
MIDIClient.init;
~midi = MIDIOut.newByName("loopMIDI Port", "loopMIDI Port");
)

(
// Constants
~triggerCount = 8;
~maxPointCount = 16;
~refreshFPS = 30;
~midiChannel = 0;
~midiNoteDuration = 0.25; // 16th note

s.waitForBoot {
    Buffer.freeAll;
    s.sync;

    ~delayBuf = Buffer.alloc(s, s.sampleRate, 2);
    s.sync;

    // Note that the synth get everything as an array so it stands as it's own independent of any GUI
    // this way replies will work either with a GUI or manual set commands
    SynthDef(\points, {
        |globalOffset=0, freq=0.25, refreshRate=10, t_reset=0|

        var fineOffsets = \fineOffsets.kr(Array.fill(~maxPointCount, 0));
        var speedOffsets = \speedOffsets.kr(Array.fill(~maxPointCount, 0));
        var triggers = \triggers.kr(Array.fill(~triggerCount, 0));
        var activePoints = \activePoints.kr(Array.fill(~maxPointCount, 1));

        var rate = (freq + speedOffsets) / (s.sampleRate/s.options.blockSize);
        var sig = Phasor.kr(t_reset, rate) + fineOffsets + globalOffset % 1;
        triggers.do {|v, i|
            var triggerCrossing = Changed.kr(PulseCount.kr(sig - rate - (i/~triggerCount) * v * activePoints));
            triggerCrossing.do { |trig, j| SendReply.kr(trig, '/triggerCrossing', [i, j]); };
        };
        SendReply.kr(Impulse.kr(refreshRate), '/pointPosUpdate', sig);
    }).add;

    SynthDef(\basic, {
        |freq=440, detune=0.1, cf=20000, rq=0.75, atk=0.025, rel=1, dur=1, amp=1, pan=0, width=0.1, out=0|
        var freqs = freq * LFNoise2.ar(3!5).bipolar(detune).midiratio;
        var sig = Saw.ar(freqs);
        var env = Env.perc(atk.max(0), rel.max(0)).kr(Done.freeSelf, timeScale: dur);
        sig = RLPF.ar(sig, cf.clip(20, 20000), rq.clip(0.0001, 1)) * rq.sqrt.reciprocal;
        sig = sig * env * amp;
        sig = Splay.ar(sig, width, center: pan);
        Out.ar(out, sig);
    }).add;

    SynthDef(\fx, {
        var sig = In.ar(\in.ir(0), 2);
        var buf = \buf.ir;
        var dlay = PlayBuf.ar(2, buf, loop: 1);
        sig = sig.blend(dlay, 0.5);
        sig = LPF.ar(sig, 5000);
        sig = LeakDC.ar(sig);
        RecordBuf.ar(sig, buf);
        sig = sig.blend(NHHall.ar(sig, 2), 0.33);
        ReplaceOut.ar(\out.ir(0), sig);
    }).add;
    s.sync;
};
)

(
var win, checkboxes, userView, globalOffset, fineOffset, speedOffset, pointCount, resetBtn,
    pointsPos, pointsTriggerState, triggerStates, activePointCount,
    synth, uiUpdateFunc, updatePointsTriggeredState;

Window.closeAll;

s.bind { synth = Synth(\points, [refreshRate: ~refreshFPS, freq: 16.reciprocal]) };

pointsPos = Array.fill(~maxPointCount, 0);
pointsTriggerState = Array.fill(~maxPointCount, 0);
triggerStates = Array.fill(~triggerCount, false);
triggerStates[0] = true;
activePointCount = 16;

win = Window.new("Test", Rect(1380, 250, 500, 150)).alwaysOnTop_(true).onClose_({
    synth.free;
    uiUpdateFunc.free;
    updatePointsTriggeredState.free;
});
userView = UserView().background_(Color.white).drawFunc_({|view|
    var width = view.bounds.width;
    var height = view.bounds.height;
    var step = width / ~triggerCount;
    var pointHeightStep = height / (activePointCount+1);

    // Draw trigger bars
    Pen.strokeColor_(Color.black);
    triggerStates.do {|v, i|
        if (v) {
            var xPos = ((i+0.5)*step);
            Pen.moveTo(xPos@0);
            Pen.lineTo(xPos@height);
        };
    };
    Pen.stroke();

    // Draw points
    Pen.fillColor_(Color.black);
    activePointCount.do { |i|
        var xPos = pointsPos[i];
        var yPos = (i+1) * pointHeightStep;
        Pen.addArc(((xPos+16.reciprocal % 1.0) * width)@yPos, 3, 0, 2pi); // Shift xpos to match drawn line offset
        Pen.perform([\stroke, \fill][pointsTriggerState[i]]);
    };

    // Reset all points trigger crossing state
    ~maxPointCount.do {|i| pointsTriggerState[i] = 0;}
});

uiUpdateFunc = OSCFunc({|msg|
    pointsPos = msg[3..];
    defer { userView.refresh };
}, '/pointPosUpdate');

updatePointsTriggeredState = OSCFunc({ |msg|
    var pointIdx = msg[4];
    pointsTriggerState[pointIdx] = 1;
}, '/triggerCrossing');

// Could replace checkboxes with buttons
checkboxes = ~triggerCount.collect {|i| CheckBox().action_({|checkbox|
    triggerStates[i] = checkbox.value;
    s.bind { synth.set(\triggers, triggerStates.collect{|v| if (v, 1, 0) }) };
    userView.refresh;
}).valueAction_(triggerStates[i]) };
globalOffset = NumberBox().step_(0.01).scroll_step_(0.01).action_({|view|
    s.bind { synth.set(\globalOffset, view.value) } }).valueAction_(0.0);
fineOffset = NumberBox().step_(0.01).scroll_step_(0.01).action_({|view|
    s.bind { synth.set(\fineOffsets, Array.series(~maxPointCount, step: view.value)) }
}).valueAction_(0.0);
speedOffset = NumberBox().step_(0.1).scroll_step_(0.1).action_({|view|
    s.bind { synth.set(\speedOffsets, Array.series(~maxPointCount, step: view.value * 0.01)) }
}).valueAction_(0.0);
pointCount = NumberBox().step_(1).clipLo_(1).clipHi_(16).action_({|view|
    activePointCount = view.value;
    s.bind { synth.set(\activePoints, ~maxPointCount.collect{|i| if (i<activePointCount, 1, 0) }) }
}).valueAction_(16);
resetBtn = Button().string_("Reset").mouseDownAction_({
    s.bind { synth.set(\t_reset, 1)} });

win.layout_(VLayout(
    HLayout(StaticText().string_("Global offset"), globalOffset),
    HLayout(StaticText().string_("Fine offset"), fineOffset),
    HLayout(StaticText().string_("Speed offset"), speedOffset),
    HLayout(StaticText().string_("Point cout"), pointCount),
    resetBtn,
    [userView.minSize_(0@100), stretch:1],
    HLayout(*checkboxes.collect {|view| [view, align: \center]})
));
win.front;
)

// Monitor, will send midi messages
(
~midi.allNotesOff(~midiChannel);
m = OSCFunc({ |msg|
    var pointIdx = msg[4].asInteger;
    fork {
        var note = Scale.minorPentatonic.performDegreeToKey(pointIdx) + 60;
        ~midi.noteOn(~midiChannel, note);
        (~midiNoteDuration).yield;
        ~midi.noteOff(~midiChannel, note);
    }

    // var notes = [48, 60] +.x Scale.minorPentatonic.semitones;
    // s.bind { Synth(\basic, [freq: notes.choose.midicps, cf: 150, dur: 0.25, pan: rrand(-0.5, 0.5), amp: 0.5]) };

}, '/triggerCrossing');
)
(
~midi.allNotesOff(~midiChannel);
m.free;
)

(
s.bind {
    ~fxGroup = Group.tail(s);
    s.sync;
    Synth(\fx, [buf: ~delayBuf], ~fxGroup)
};
x = OSCFunc({ |msg|
    var pointIdx = msg[4].asInteger;
    var notes = [48, 60] +.x Scale.minorPentatonic.semitones;
    s.bind { Synth(\basic, [freq: notes.choose.midicps, cf: 150, dur: 0.25, pan: rrand(-0.5, 0.5), amp: 0.5]) };
}, '/triggerCrossing');
)
x.free;