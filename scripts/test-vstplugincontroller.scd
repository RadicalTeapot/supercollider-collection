// Look for plugins and output the keys
(
VSTPlugin.search(verbose: false, action: {
    "".postln;
    "Found the following plugins".postln;
    VSTPlugin.pluginKeys.do{ |key| ("-"+key).postln };
});
)

(
var plugin = VSTPlugin.plugins.['Deelay.vst3'];
plugin.print;
plugin.editor;
)

// With a single plugin
(
{
    var plugin;
    SynthDef(\def, {VSTPlugin.ar(Silent.ar(1), info: 'Deelay.vst3') }).add;
    s.sync;
    plugin = VSTPluginController(Synth(\def)).open(verbose: true, action: { |self, success|
        if (success) {self.editor} { "An error occured while loading the plugin".postln }
    });
}.fork;
)

// With multiple plugins
(
{
    var plugin;
    SynthDef(\def, {
        var sig = VSTPlugin.ar(Silent.ar(2), 2, id: \rev, info: 'ValhallaSupermassive.vst3');
        VSTPlugin.ar(sig, 2, id: \delay, info: 'Deelay.vst3');
    }).add;
    s.sync;
    plugin = VSTPluginController.collect(Synth(\def));
    plugin[\rev].open(verbose: true, action: { |self, success|
        if (success) {self.editor} { "An error occured while loading the plugin".postln }
    });
    plugin[\delay].open(verbose: true, action: { |self, success|
        if (success) {self.editor} { "An error occured while loading the plugin".postln }
    });
}.fork;
)
