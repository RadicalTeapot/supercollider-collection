(
var win, userView, oscFunc, pos = 0.5;

{
    var sig = Phasor.kr(rate: 1/(s.sampleRate / s.options.blockSize));
    SendReply.kr(Impulse.kr(30), '/uiUpdate', sig);
    Silent.ar(1);
}.play;

Window.closeAll;

win = Window.new("Test", Rect(1450, 150, 400, 50)).alwaysOnTop_(true).toFrontAction_({
    oscFunc = OSCFunc({ |msg| pos = msg[3] }, '/uiUpdate', s.addr);
}).endFrontAction_({
    oscFunc.free;
});

userView = UserView().background_(Color.white).frameRate_(30).animate_(true).drawFunc_({|view|
    var width = view.bounds.width;
    var height = view.bounds.height;
    var x = pos * width;
    Pen.strokeColor_(Color.black);
    Pen.moveTo(x@0);
    Pen.lineTo(x@height);
    Pen.stroke;
});

win.layout_(VLayout(
    userView.minSize_(0@50)
));
win.front;
)