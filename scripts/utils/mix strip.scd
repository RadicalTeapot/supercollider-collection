(
var mixerGenerator = {|name=\mixer, inCount=1|
    SynthDef(name, {
        var inputs = \ins.ir(0.dup(inCount));
        var out = \out.ir(0);
        var globalAmp = \globalAmp.kr(1);
        var sig = Mix(In.ar(inputs, 2)) * globalAmp;
        Out.ar(out, sig);
    });
};

var stripOutWrapGenerator = {{|sig|
    var amp = \amp.kr(1, 0.01);
    var pan = \pan.kr(0, 0.01);
    var out = \levelOut.ir(0);
    var updateTrig, updateAmp, updatePeak;

    sig = Splay.ar(sig, 1-(pan.abs), center: pan);
    sig = sig * amp;

    // For reporting
    updateTrig = Delay1.kr(Impulse.kr(10));
    updateAmp = Amplitude.kr(sig, releaseTime: 0.1).lag(0.1);
    updatePeak = Peak.kr(sig, updateTrig).lag(0, 3);

    Out.kr(out, [updateAmp[0], updatePeak[0], updateAmp[1], updatePeak[1]]);
    sig;
}};

var mixInWrapGenerator = { |inputCount=1|
    var wrap;
    if (inputCount == 1) {
        wrap = {
            In.ar(\in.ir(0), 2) * \inputAmp.kr([0]);
        }
    } {
        wrap = {
            var inputs = In.ar(\in.ir(0.dup(inputCount)), 2) * \inputAmp.kr(0.dup(inputCount));
            Mix.ar(inputs);
        }
    };
    wrap;
};

var stripUI = { |server, synth, sends=#[[]], defaultAmp = (-10.dbamp), defaultPan = 0.0|
    var ampSpec, ampWarning, ampCritical;
    var resetOnDblClick, updateLevels;
    var containerView, layout;
    var panSpec, panResetOnDblClick, panKnob;
    var ampValue, ampSlider, lAmpView, rAmpView;

    var title = synth.defName;

    ampSpec = ControlSpec(0.001, 1, \exponential);
    ampWarning = ampSpec.unmap(0.6);
    ampCritical = ampSpec.unmap(0.9);

    resetOnDblClick = {|resetValue=0.0|
        {|view, x, y, modifiers, buttonNumber, clickCount|
            if ((buttonNumber == 0) && (clickCount == 2)) {
                view.valueAction_(resetValue);
            };
        };
    };

    updateLevels = { |lAmp, lPeak, rAmp, rPeak|
        lAmpView.value = ampSpec.unmap(lAmp);
        lAmpView.peakLevel = ampSpec.unmap(lPeak);
        rAmpView.value = ampSpec.unmap(rAmp);
        rAmpView.peakLevel = ampSpec.unmap(rPeak);
    };

    containerView = UserView.new.background_(Color.gray(0.8));
    layout = VLayout();

    panSpec = ControlSpec(-1, 1);
    panResetOnDblClick = resetOnDblClick.(panSpec.unmap(0.0));
    panKnob = Knob.new.mode_(\vert).centered_(true).action_({ |view|
        server.bind { synth.set(\pan, panSpec.map(view.value)) };
    }).mouseDownAction_(panResetOnDblClick).valueAction_(panSpec.unmap(defaultPan));
    layout.add(StaticText.new.string_("Pan").align_(\center));
    layout.add(panKnob);

    ampValue = NumberBox.new;
    ampSlider = Slider.new.maxWidth_(20).orientation_(\vertical).action_({ |view|
        var mapped = ampSpec.map(view.value);
        ampValue.value_(mapped.ampdb);
        server.bind { synth.set(\amp, mapped) };
    }).valueAction_(ampSpec.unmap(defaultAmp));

    lAmpView = LevelIndicator.new.warning_(ampWarning).critical_(ampCritical).style_(\continuous)
    .drawsPeak_(true).background_(Color.black);
    rAmpView = LevelIndicator.new.warning_(ampWarning).critical_(ampCritical).style_(\continuous)
    .drawsPeak_(true).background_(Color.black);

    layout.add(HLayout(ampSlider, lAmpView, rAmpView));
    layout.add(ampValue);

    if (sends.size > 0) {
        var sendResetOnDblClick = resetOnDblClick.();
        var sendLayout = VLayout();
        sends.collect { |sendData, i|
            var send = sendData[0];
            var sendIndex = sendData[1];
            var knob = Knob.new.mode_(\vert).mouseDownAction_(sendResetOnDblClick).action_({ |view|
                server.bind{ send.seti(\inputAmp, sendIndex, ampSpec.map(view.value)) };
            });
            sendLayout.add(StaticText.new.string_(send.defName).align_(\center));
            sendLayout.add(knob);
        };
        sendLayout.add(nil, 100);
        layout = HLayout(layout, sendLayout);
    };

    layout = VLayout(StaticText().string_(title).align_(\center).background_(Color.white), layout);
    containerView.layout_(layout);

    ampValue.action_({|view| ampSlider.valueAction = ampSpec.unmap(view.value.dbamp) });
    (view: containerView, updateLevels: updateLevels);
};

(mixerSynthDef: mixerGenerator, stripOutWrap: stripOutWrapGenerator, mixInWrap: mixInWrapGenerator, ui: stripUI)
)