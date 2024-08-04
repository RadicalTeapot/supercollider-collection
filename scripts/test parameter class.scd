(
var param;

"No Get or Set test".postln;
param = Parameter(0);
"- Get call: ".post; param.value.postln;
"- Set call".postln; param.value = 1;
"- Get call: ".post; param.value.postln;

"".postln;
"Get test".postln;
param = Parameter(0, { |value| "Get value override: ".post; value+1 });
"- Get call: ".post; param.value.postln;

"".postln;
"Set test".postln;
param = Parameter(0, set: { |value| "Set value override".postln; value.asInteger });
"- Get call: ".post; param.value.postln;
"- Set call: ".post; param.value = 1.598;
"- Get call: ".post; param.value.postln;

"".postln;
"Get and Set test".postln;
param = Parameter(0, { |value| "Get value override: ".post; value }, { |value| "Set value override".postln; value.asInteger });
"- Get call: ".post; param.value.postln;
"- Set call; ".post; param.value = 1.60985;
"- Get call: ".post; param.value.postln;
)