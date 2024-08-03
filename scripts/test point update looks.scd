(
CmdPeriod.run;
Window.closeAll;
s.waitForBoot {
    SynthDef(\points, {
        |refreshFPS = 30|
        var sig = Phasor.kr(rate: ControlDur.ir);
        SendReply.kr(sig - 0.2, '/posTrig', 1);
        SendReply.kr(Impulse.kr(refreshFPS), '/update', sig);
    }).play(s);
    s.sync;

    AppClock.sched(0, {
        var win, userView, screen, width=400, height=400;
        var pointPos = 0, pointMiddleTrig = 0;
        screen = Window.availableBounds;
        win = Window(bounds: Rect((screen.width - width)/2, (screen.height-height)/2, width, height)).alwaysOnTop_(true);
        userView = UserView().background_(Color.white).drawFunc_({
            var yPos, xPos = pointPos;
            var radius = 5;
            var trigLinePos = 0.2;

            Pen.strokeColor_(Color.black);
            Pen.fillColor_(Color.black);
            Pen.moveTo((trigLinePos * width)@0);
            Pen.lineTo((trigLinePos * width)@height);

            yPos = 0.2;
            Pen.addArc((xPos * width)@(yPos * height), radius, 0, 2pi);
            Pen.stroke;
            if (pointMiddleTrig > 0.66) {
                Pen.addArc((xPos * width)@(yPos * height), radius, 0, 2pi);
                Pen.fill;
            };

            yPos = 0.4;
            Pen.addArc((xPos * width)@(yPos * height), radius, 0, 2pi);
            Pen.stroke;
            Pen.addArc((xPos * width)@(yPos * height), radius * pointMiddleTrig * 2, 0, 2pi);
            Pen.fill;

            yPos = 0.6;
            Pen.fillColor_(Color.gray(1.0 - pointMiddleTrig));
            Pen.addArc((xPos * width)@(yPos * height), radius, 0, 2pi);
            Pen.perform([\stroke, \fill][pointMiddleTrig.ceil.asInteger]);
            pointMiddleTrig = (pointMiddleTrig-0.1).max(0);
        });
        win.layout_(VLayout(userView.minSize_(0, 400)));
        win.front.onClose_({CmdPeriod.run});

        OSCFunc({ |msg|
            pointPos = msg[3];
            defer { userView.refresh };
        }, '/update');

        OSCFunc({ |msg|
            pointMiddleTrig = 1;
        }, '/posTrig');
    });
};
)