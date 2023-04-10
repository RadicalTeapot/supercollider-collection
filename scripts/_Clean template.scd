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
	});
};


~performanceEvents = [
	// Fill with array of functions to call to move the performance along
];
~performanceEventCounter = 0;

s.newBusAllocators;
// Allocate buses

s.waitForBoot({
	// Cleanup
	s.freeAll;
	Buffer.freeAll;
	s.sync;

	// Create and load buffers
	s.sync;

	// Add synthdefs
	s.sync;

	// Run start command
	ServerTree.add(~runOnServerRestart);
	ServerTree.run;

	s.sync;

	// Create patterns / PBinds here
});
)

// Perform
(
~performanceEvents[~performanceEventCounter].value;
~performanceEventCounter = (~performanceEventCounter + 1) % ~performanceEvents.size;
)