(
// Load relative returns an array
var module, path = "to load.scd".resolveRelative;
("Loading \""++path++"\"").postln;
module = path.load;
module.module_func();
)

(
var module, path = "to load.scd";
("Loading \""++path++"\"").postln;
module = path.loadRelative[0];
module.module_func();
)