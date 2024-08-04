(
var observerManager, win, guiControl;
observerManager = ObserverManager.new;
~parameter = (
    prValue: 0,
    key: \testParameter,
    getter: { |self| self.prValue },
    setter: { |self, value| self.prValue = value; observerManager.notifyObservers(self.key, self.prValue); self }
);

Window.closeAll;
win = Window(bounds: Rect(500, 150, 250, 100)).alwaysOnTop_(true).front;
guiControl = NumberBox().value_(~parameter.getter).action_({|view| ~parameter.setter(view.value)});
win.layout_(VLayout(guiControl));

observerManager.addObserver(~parameter.key, ObserverFactory.guiObserver(\testParameterGui, guiControl));
)

~parameter.setter(20);
~parameter.getter;