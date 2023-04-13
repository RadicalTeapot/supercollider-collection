(
~setupInOuts = {
	// Set input and output devices to JACK and allocate 4 outputs bus by default
	var serverOptions = Server.default.options;
	serverOptions.inDevice_("ASIO : JackRouter");
	serverOptions.outDevice_("ASIO : JackRouter");
	serverOptions.numOutputBusChannels_(4);
	Server.default.reboot;
};
// ~setupInOuts.();

ServerTree.removeAll;

~runOnServerRestart = {
	s.bind({
		~synthGroup = Group.head();
		~bufferGroup = Group.tail();
		~mixGroup = Group.tail();

		// Recorder
		~recorder = Synth(\recorder, [inputBus: ~synthBus, bufnum: ~recodingBuffer, gate: 1, plev: 0.9, amp: 2], ~bufferGroup);

		// Loopers
		~loopers = [
			Synth(\looper, [bufnum: ~recordingBuffer, bus: ~looperBus, panRange: 0.2, amp: 3, baseRate: 0.25], ~synthGroup),
			Synth(\looper, [bufnum: ~recordingBuffer, bus: ~looperBus, panRange: 0.5, amp: 2, baseRate: 0.5], ~synthGroup),
			Synth(\looper, [bufnum: ~recordingBuffer, bus: ~looperBus, panRange: 1, amp: 1, baseRate: 2, timescale: 1], ~synthGroup),
			Synth(\looper, [bufnum: ~recordingBuffer, bus: ~looperBus, panRange: 1, amp: 0.5, baseRate: 4, timescale: 2], ~synthGroup),
		];

		~lfos = [0.01, 0.033, 0.1, 1].collect({ |v, i| Synth(\triLFO, [freq:  v, bus: i]); i; });

		~fxAndMix = {
			var synthSig, looperSig, sig;

			synthSig = In.ar(~synthBus, 2);
			synthSig = LPF.ar(synthSig, In.kr(~lfos[0]).range(200, 2000).clip(20, 20000));
			synthSig = synthSig * (0.1 + In.kr(~lfos[1]).unipolar(0.1).clip(0, 0.1));
			synthSig = CombN.ar(synthSig, 10, 0.66, In.ar(~lfos[1]).range(5, 10));

			looperSig = In.ar(~looperBus, 2);
			looperSig = LPF.ar(looperSig, In.kr(~lfos[1]).range(600, 200).clip(20, 20000));
			looperSig = HPF.ar(looperSig, In.kr(~lfos[0]).range(50, 80).clip(20, 20000));
			looperSig = looperSig * (0.75 + In.kr(~lfos[2]).unipolar(0.25).clip(0, 0.25));

			sig = synthSig + looperSig;
			sig = FreeVerb2.ar(sig[0], sig[1], In.kr(~lfos[0]).range(0.7, 0.4), 0.9);

			Out.ar(0, sig);
		};

		~simpleMix = {
			Out.ar(0, In.ar(~synthBus, 2));
			Out.ar(2, In.ar(~looperBus, 2));
		};
	});
};

~performanceEvents = [
	// Fill with array of functions to call to move the performance along
	{
		a = ~lead.play;
		// b = ~fxAndMix.play(~mixGroup);
		b = ~simpleMix.play(~mixGroup);
	},
	{
		a.stop;
		b.free;
		~recordingBuffer.zero;
	}
];
~performanceEventCounter = 0;

s.newBusAllocators;
~synthBus = Bus.audio(s, 2);
~looperBus = Bus.audio(s, 2);

s.waitForBoot({
	var notes;
	// Cleanup
	s.freeAll;
	Buffer.freeAll;

	s.sync;

	// -----------------------------------------------
	s.newBufferAllocators;
	~recordingBuffer = Buffer.alloc(s, s.sampleRate * 17, 2);  // Prime number for length to make sure it's not grid aligned

	s.sync;

	// -----------------------------------------------
	// Define synths
	SynthDef(\recorder, {
		var sig;
		sig = In.ar(\inputBus.ir(0), 2);
		RecordBuf.ar(sig, \bufnum.ir(0), recLevel: \rlev.kr(1), preLevel: \plev.kr(0.5), run: \gate.kr(0));
	}).add;

	SynthDef(\player, {
		var sig;
		sig = PlayBuf.ar(2, \bufnum.ir(0), loop: 1);
		Out.ar(\bus.ir(0), sig);
	}).add;

	SynthDef(\looper,{
		// main arguments
		arg bufnum,bus=0,baseRate=1.0,amp=1.0,timescale=0.2,panRange=1;
		// variables to store UGens later
		var volume;
		var switch=0,snd,snd1,snd2,pos,pos1,pos2,posStart,posEnd,index;
		// store the number of frames and the duraiton
		var frames=BufFrames.kr(bufnum);
		var duration=BufDur.kr(bufnum);
		// LFO for the start point <-- tinker
		var lfoStart=SinOsc.kr(timescale/Rand(30,60),Rand(hi:2*pi)).range(1024,frames-10240);
		// LFO for the window lenth <-- tinker
		var lfoWindow=SinOsc.kr(timescale/Rand(60,120),Rand(hi:2*pi)).range(4096,frames/2);
		// LFO for the rate (right now its not an LFO)
		var lfoRate=baseRate;//*Select.kr(SinOsc.kr(1/Rand(10,30)).range(0,4.9),[1,0.25,0.5,1,2]);
		// LFO for switching between forward and reverse <-- tinker
		var lfoForward=Demand.kr(Impulse.kr(timescale/Rand(5,15)),0,Drand([0,1],inf));
		// LFO for the volume <-- tinker
		var lfoAmp=SinOsc.kr(timescale/Rand(10,30),Rand(hi:2*pi)).range(0.05,0.5);
		// LFO for the panning <-- tinker
		var lfoPan=SinOsc.kr(timescale/Rand(10,30),Rand(hi:2*pi)).range(-1,1) * panRange;

		// calculate the final rate
		var rate=Lag.kr(lfoRate*(2*lfoForward-1),1)*BufRateScale.kr(bufnum);

		// modulate the start/stop
		posStart = lfoStart;
		posEnd = Clip.kr(posStart + lfoWindow,0,frames-1024);

		// LocalIn collects the a trigger whenever the playhead leaves the window
		switch=ToggleFF.kr(LocalIn.kr(1));

		// playhead 1 has a play position and buffer reader
		pos1=Phasor.ar(trig:1-switch,rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
		snd1=BufRd.ar(2,bufnum,pos1,1.0,4);

		// playhead 2 has a play position and buffer reader
		pos2=Phasor.ar(trig:switch,  rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
		snd2=BufRd.ar(2,bufnum,pos2,1.0,4);

		// current position changes according to the swtich
		pos=Select.ar(switch,[pos1,pos2]);

		// send out a trigger anytime the position is outside the window
		LocalOut.kr(
			Changed.kr(Stepper.kr(Impulse.kr(20),max:1000000000,
				step:(pos>posEnd)+(pos<posStart)
			))
		);

		// crossfade bewteen the two sounds over 50 milliseconds
		snd=SelectX.ar(Lag.kr(switch,0.05),[snd1,snd2]);

		// apply the volume lfo
		volume = amp*lfoAmp*EnvGen.ar(Env.new([0,1],[Rand(1,10)],4));

		// do the panning
		snd=Balance2.ar(snd[0],snd[1],lfoPan);

		// final output
		Out.ar(bus,snd*volume/5);
	}).add;

	SynthDef(\triLFO, {
		var sig = LFTri.kr(\freq.ir(1));
		Out.kr(\bus.kr(0), sig);
	}).add;

	s.sync;

	// -----------------------------------------------
	ServerTree.add(~runOnServerRestart);
	ServerTree.run;

	s.sync;

	// -----------------------------------------------
	notes = Scale.minorPentatonic.degrees;
	~lead = Pbind(
		\dur, Pwrand([1,2,4,Rest(2)], [1, 3, 3, 2].normalizeSum, inf),
		\sustain, 0.5,
		\note, (
			Pn(Pshuf(notes, {rrand(4, 8)}), inf)  // Shuffle the notes after 4 to 8 repeats
			+
			Pdup(Pwhite(1, 3)*notes.size, Pseq([-12,-5,0,Prand([0, -7, 7])], inf)))+12,  // Repeat the current note in seq between 1 and 3 time the note count. Since this is a multiple of the note count, it effectively changes transposition only after a whole set of shuffled note is played
		\pan, Pmeanrand(-0.7, 0.7, inf),
		\amp, Pwrand([0.75, 0], [8, 2].normalizeSum, inf),
		\group, ~synthGroup,
		\out, ~synthBus,
	);

});
)

// Perform
(
~performanceEvents[~performanceEventCounter].value;
~performanceEventCounter = (~performanceEventCounter + 1) % ~performanceEvents.size;
)