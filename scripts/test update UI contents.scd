(
// For debounce logic
var debounceTime = 0.1;
var nextAction = nil;

var screen = Window.availableBounds;
var win = Window("test", Rect((screen.width-100)/2, (screen.height+50)/2, 100, 50)).onClose_({CmdPeriod.run});

var container = View(); // Container whose content will be updated
var checkboxes = []; // Current checkboxes (used for keeping check state)
var nb = NumberBox().step_(1).scroll_step_(1).clipLo_(0).clipHi_(10).action_({|view|
    var nbValue = view.value.asInteger;
    nextAction = {
        defer {
            var values = checkboxes.collect { |cb| cb.value }.add(false); // Get current state of all checkboxes and append false for all new ones (used in collaboration with .clipAt below)
            container.removeAll; // Clear all previous children
            checkboxes = nbValue.collect{ |i| CheckBox().value_(values.clipAt(i)) }; // Create the new items
            container.layout_(HLayout(*checkboxes.collect{|cb| [cb, align: \center]})); // Assign them as new children
        }
    };
}).valueAction_(1);
win.layout_(VLayout(nb, container));
win.front;

// Debounce logic
fork { loop {
    if (nextAction.notNil) {
        nextAction.();
        nextAction = nil;
    };
    debounceTime.yield;
}};
)