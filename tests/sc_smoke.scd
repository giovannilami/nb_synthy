// Run with lib/NB_Synthy.sc included in the sclang class-library config.
// Optional NB_SYNTHY_TEST_OUT sets a directory for the offline OSC score.
(
var backend, directory, score;
try {
    if(NB_SynthyLoader.loadBackend.not) { Error("loader failed").throw };
    NB_SynthyLoader.free;
    backend = thisProcess.interpreter.executeFile(
        thisProcess.nowExecutingPath.dirname.dirname +/+ "lib/synthy.scd"
    );
    backend[\definitions].value;
    if(SynthDescLib.global.at(\nb_synthy_fx).isNil or: {
        SynthDescLib.global.at(\nb_synthy_osc).isNil
    }) { Error("missing SynthDefs").throw };
    backend[\defaults].value;
    backend[\noteOn].value(60, 0.6); // queued before audio allocation
    backend[\bend].value(60, 2);
    backend[\noteOff].value(60);
    backend[\panic].value;
    backend[\free].value;
    backend[\free].value; // idempotent cleanup, including before allocation
    "PASS loader, SynthDefs, pre-init notes, repeated cleanup".postln;
    directory = "NB_SYNTHY_TEST_OUT".getenv;
    if(directory.notNil) {
        score = [
            [0.0, [\d_recv, SynthDescLib.global.at(\nb_synthy_fx).def.asBytes]],
            [0.0, [\d_recv, SynthDescLib.global.at(\nb_synthy_osc).def.asBytes]],
            [0.05, [\g_new, 1, 0, 0]],
            [0.1, [\s_new, \nb_synthy_fx, 1000, 1, 1, \in, 16, \out, 0, \reverb, 0.02]],
            [0.2, [\s_new, \nb_synthy_osc, 1001, 0, 1, \out, 16, \hz, 220, \amp, 0.6, \sub, 1, \attack, 0.05, \release, 0.3]],
            [0.3, [\s_new, \nb_synthy_osc, 1002, 0, 1, \out, 16, \hz, 330, \amp, 0.5, \attack, 0.05, \release, 0.3]],
            [0.8, [\n_set, 1001, \bend, 2, \portamento, 0.1, \perturb1, 0.002, \t_trig1, 1]],
            [1.0, [\n_set, 1000, \flang, 0.3, \autofilter, 0, \lpf, 1200]],
            [1.4, [\n_set, 1001, \gate, 0]],
            [1.5, [\n_set, 1002, \gate, 0]],
            [3.0, [\g_freeAll, 1]],
            [3.5, [\c_set, 0, 0]]
        ];
        Score.write(score, directory +/+ "smoke.osc");
        "PASS offline audio score written".postln;
    };
    0.exit;
} { |error|
    error.reportError;
    1.exit;
};
)
