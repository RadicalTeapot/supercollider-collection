(
AppClock.sched(0, {
    var window, bounds, views;
    Window.closeAll;
    views = 4.collect { |i|
        var param = ObservableParameter(0.5);
        var enabled = ObservableParameter(1);
        var isDragging = false;
        var userView = UserView()
        .background_(Color.white)
        .mouseDownAction_({ |view, x, y, mods, button|
            if (button == 0) { isDragging = true }; // Left click
            if (button == 1) { enabled.value = 1 - enabled.value; } // Right click
        })
        .mouseUpAction_({ isDragging = false; })
        .mouseMoveAction_({ |view, x, y| param.value = x / view.bounds.width; })
        .drawFunc_({ |view|
            var bounds = view.bounds;

            Pen.fillColor = Color.hsv(i*0.2, 0.2 * enabled.value, 0.8);
            Pen.addRect(Rect(2, 2, (bounds.width-4) * param.value, bounds.height-4));
            Pen.fill;

            Pen.width = 2;
            Pen.strokeColor = Color.black;
            Pen.addRect(Rect(2, 2, bounds.width-4, bounds.height-4));
            Pen.stroke;
        });
        param.register(\uiUpdate, { defer { userView.refresh }});
        enabled.register(\uiUpdate, { defer { userView.refresh }});
        userView;
    };
    bounds = Window.availableBounds;
    window = Window(bounds: Rect(bounds.width/2 - 250, bounds.height/2, 500, 250))
    .front
    .alwaysOnTop_(true)
    .background_(Color.white)
    .onClose_({CmdPeriod.run})
    .layout_(VLayout(*views));
});
)