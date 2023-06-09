~useAudioInterface.();

(
s.waitForBoot({
    // SynthDef is from here https://schollz.com/tinker/phasedistortion/
	SynthDef("casioish",{
		arg freq=220, amp=0.5, rel=1;
		var freqBase=freq;
		var freqRes=SinOsc.kr(Rand(0,0.2),0).range(freqBase/2,freqBase*2);
		var pdbase=Impulse.ar(freqBase);
		var pd=Phasor.ar(pdbase,2*pi*freqBase/s.sampleRate,0,2pi);
		var pdres=Phasor.ar(pdbase,2*pi*freqRes/s.sampleRate,0,2pi);
		var pdi=LinLin.ar((2pi-pd).max(0),0,2pi,0,1);
		var snd=Lag.ar(SinOsc.ar(0,pdres)*pdi,1/freqBase).dup;
		snd=Splay.ar(snd);
		snd=snd*EnvGen.ar(Env.perc(0.005,rel), doneAction: 2);
		Out.ar(0,snd*amp);
	}).add;
	s.sync;
    ~voice = Pbind(
        \instrument, "casioish",
        \midinote, Pn(Pshuf(60 + Scale.minorPentatonic.degrees, 1), inf),
        \dur, Pseq([Prand([0.25, 0.5, 1], {rrand(4, 12)}), Prand([Rest(1), Rest(2), Rest(3)], 1)], inf),
        \amp, Pexprand(0.5, 1, inf),
        \rel, Pkey(\dur) * Pwhite(0.5, 2),
    );
});
)

~voice.play;