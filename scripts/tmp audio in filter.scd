~useAudioInterface.();

(
s.newBusAllocators;
~ampBus = Bus.control(s);
~ampBus.value_(0.1);

~brfCfBus = Bus.control(s);
~brfQBus = Bus.control(s);
~brfCfBus.value_(1000);
~brfQBus.value_(80);

{
    var sig = SoundIn.ar([2,3]);
    var amp = In.kr(~ampBus);

    // Filter out 1kHz hum
    var brfCf = In.kr(~brfCfBus);
    var brfQ = (In.kr(~brfQBus).reciprocal).clip(0.0001, 1);
    sig = BRF.ar(sig, brfCf.clip(20, 20000), brfQ);
    sig = BRF.ar(sig, (brfCf*3).clip(20, 20000), brfQ);
    sig = BRF.ar(sig, (brfCf*2).clip(20, 20000), brfQ);
    sig = BRF.ar(sig, (brfCf*4).clip(20, 20000), brfQ);

    Out.ar(0, sig * amp);
}.play;
)
