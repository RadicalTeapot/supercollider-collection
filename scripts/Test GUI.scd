(
Window.closeAll;
w = Window("Test", Rect(200, 500, 1200, 600)).front;
w.alwaysOnTop_(true);
w.layout = VLayout(
    GridLayout.rows(
        *(3.collect({|i|
            var text, slider, numberbox;
            [
                text = StaticText().string_("Hello "++i.asInteger),
                slider = Slider().orientation_(\horizontal).action_({|c| numberbox.value_(c.value)}),
                numberbox = NumberBox().action_({|c| slider.value_(c.value) }).maxWidth_(100),
        ]}))
    ),
    UserView().drawFunc_({|view|
        Pen.fillColor = Color.white;
        Pen.addRect(Rect(0,0,view.bounds.width, view.bounds.height));
        Pen.fill;
    }).minHeight_(100),
    p = SoundFileView().action_({|v| v.setData(512.collect{rrand(-1, 1)}, 512, samplerate: 512)}),
    StaticText().string_("Hello").align_(\center),
);
p.setData(0!512, 512, samplerate: 512);
w.refresh;

CmdPeriod.doOnce({w.close});
)