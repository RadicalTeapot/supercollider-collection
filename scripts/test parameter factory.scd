(
~parameterFactory = { |initialValue=0, controlSpec=nil, isInt=false|
    // Can't use `value`, `get` or `set` as they are already used by SC
    var parameter = (
        prValue: initialValue,
        getter: { |self| self.prGetCleanValue(self.prValue) },
        setter: { |self, value|
            self.prValue = self.prGetCleanValue(value);
            self.prSetterSideEffects.do {|action| action.value(self.prValue) }; // NOTE: These are not executed in insertion order
        },
        prGetCleanValue: { |self, value| value },
        prSetterSideEffects: Dictionary(),
        registerSetterSideEffect: { |self, name, action| self.prSetterSideEffects.put(name, action) }
    );

    if (controlSpec.isNil) {
        if (isInt) {
            parameter.prGetCleanValue = { |self, value| value.asInteger };
        };
    } {
        // Could store the control spec in parameter here if needed
        if (isInt) {
            parameter.prGetCleanValue = { |self, value| controlSpec.constrain(value).asInteger; };
        } {
            parameter.prGetCleanValue = { |self, value| controlSpec.constrain(value) };
        };
    };

    parameter;
}
)

(
"No control spec, not int".postln;
p = ~parameterFactory.();
p.getter.postln;
p.setter(1.5);
p.getter.postln;

"No control spec, int".postln;
p = ~parameterFactory.(0, isInt: true);
p.getter.postln;
p.setter(1.5);
p.getter.postln;

"Control spec, not int".postln;
p = ~parameterFactory.(0, ControlSpec(2, 5, step: 0.1));
p.getter.postln;
p.setter(3.5);
p.getter.postln;
p.setter(6.5);
p.getter.postln;

"Control spec, int".postln;
p = ~parameterFactory.(0, ControlSpec(2, 5, step: 1), true);
p.getter.postln;
p.setter(3.5);
p.getter.postln;
p.setter(6.5);
p.getter.postln;

"Registering setter actions".postln;
p = ~parameterFactory.();
p.registerSetterSideEffect(\one, { |value| ("One"+value).postln });
p.registerSetterSideEffect(\two, { |value| ("Two"+value).postln });
p.setter(1);
"Done"
)