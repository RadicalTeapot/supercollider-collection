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
		// Create groups and (permanent) synths here
		~synthGroup = Group.new();
		~bufferGroup = Group.new(~synthGroup, 'addAfter');

		// Recorder
		~recorder = Synth(\recorder, [in: ~synthBus, bufnum: ~recodingBuffer, gate: 0, plev: 0], ~bufferGroup);

		// Player
		~player = Synth(\player, [out: ~playerBus, bufnum: ~recodingBuffer, rate: 0.5], ~synthGroup);

		~mixAndOut = {
			var sig = In.ar(~synthBus, 2);
			sig = sig + In.ar(~playerBus, 2);
			Out.ar(0, sig);
		};
	});

};

~performanceEvents = [
	{
		~recorder.set(\gate, 1);
		~player.set(\t_trigger, 1);
		a = ~voice.play;
		b = ~mixAndOut.play(~bufferGroup);
	},
	{
		~recorder.set(\gate, 0);
		a.stop;
	},
	{
		c = Routine({
			inf.do({
				var rate = [0.125, 0.25, 0.5, 1].choose;
				~player.set(\rate, rate);
				// ~player.set(\t_trigger, 1);
				(rate.reciprocal).yield;
			});
		}).play;
	},
	{
		c.stop;
		~recorder.set(\gate, 0);
		b.free;
	},
];
~performanceEventCounter = 0;

s.newBusAllocators;
~synthBus = Bus.audio(s, 2);
~playerBus = Bus.audio(s, 2);

s.waitForBoot({
	// Cleanup
	s.freeAll;
	Buffer.freeAll;
	s.sync;

	// Create and load buffers
	s.newBufferAllocators;
	~recordingBuffer = Buffer.alloc(s, s.sampleRate * 4, 2);
	s.sync;

	// Add synthdefs
	SynthDef(\recorder, {
		var sig;
		sig = In.ar(\in.ir(0), 2);
		RecordBuf.ar(sig, \bufnum.ir(0), recLevel: \rlev.kr(1), preLevel: \plev.kr(0.5), run: \gate.kr(0));
	}).add;

	SynthDef(\player, {
		|bufnum = 0, t_trigger=0, rate=1|
		var sig;
		var frames=BufFrames.kr(bufnum);
		var duration=BufDur.kr(bufnum);
		var lagRate = Lag.kr(rate, \lag.kr(0.25));
		var pos = [
			Phasor.ar(t_trigger, rate: lagRate, start: 0, end: frames, resetPos: 0),
			// Phasor.ar(t_trigger, rate: lagRate, start: 0, end: frames, resetPos: frames/2),
		];
		var read = [
			BufRd.ar(2, bufnum, pos[0], 1, 4),
			// BufRd.ar(2, bufnum, pos[1], 1, 4),
		];

		// sig = SelectX.ar(LFTri.ar(duration.reciprocal * max(0.0001, lagRate-1), 1), read);
		sig = read[0];
		Out.ar(\out.ir(0), sig);
	}).add;

	s.sync;

	// Run start command
	ServerTree.add(~runOnServerRestart);
	ServerTree.run;

	s.sync;

	// Create patterns / PBinds here
	~voice = Pbind(
		\dur, 0.25,
		\degree, Pseq([0, 3, 5, 7, 10], inf),
		\amp, 0.25,
		\out, ~synthBus,
	);
});
)

// Perform
(
~performanceEvents[~performanceEventCounter].value;
~performanceEventCounter = (~performanceEventCounter + 1) % ~performanceEvents.size;
)

{LFTri.ar(1.reciprocal, 1).unipolar(1)}.plot(1);