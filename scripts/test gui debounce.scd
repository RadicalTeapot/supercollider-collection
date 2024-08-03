(
// Used by debounce logic
var debounceTime = 0.1; // Time between function calls
var nextAction = nil; // Storage for next function to be called

var screen = Window.availableBounds;
var win = Window("test", Rect((screen.width-100)/2, (screen.height+50)/2, 100, 50)).onClose_({CmdPeriod.run});
var nb = NumberBox().action_({|view|
    var value = view.value;
    nextAction = {("Action"+value).postln}; // Update next function to be called
});
win.layout_(
    VLayout(nb)
);
win.front;

// Handle debouncing
fork { loop {
    if (nextAction.notNil) {
        nextAction.(); // Run the next function and reset the storage value
        nextAction = nil;
    };
    debounceTime.yield; // Wait
}};
)