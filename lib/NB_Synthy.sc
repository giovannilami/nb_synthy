// nb_synthy 0.1.1 — deferred audio loader.
// Only this small class is compiled at norns boot. The audio implementation
// is a .scd file interpreted on selection, inside an error handler.
NB_SynthyLoader {
    classvar backend;

    *loadBackend {
        var loaded = false;
        var path = this.filenameSymbol.asString.dirname +/+ "synthy.scd";
        try {
            backend = thisProcess.interpreter.executeFile(path);
            if(backend.isKindOf(IdentityDictionary).not) {
                Error("nb_synthy: could not load synthy.scd").throw;
            };
            loaded = true;
        } { |error|
            backend = nil;
            "[nb_synthy] audio code could not be loaded; host audio left running".warn;
            error.reportError;
        };
        ^loaded;
    }

    *dispatch { |method, args|
        if(backend.notNil) {
            try {
                backend[method].valueArray(args);
            } { |error|
                "[nb_synthy] voice error; freeing only Synthy".warn;
                error.reportError;
                this.free;
            };
        };
    }

    *start {
        this.free;
        if(this.loadBackend) { this.dispatch(\start, []) };
    }

    *free {
        var previous = backend;
        backend = nil;
        if(previous.notNil) {
            try { previous[\free].value } { |error| error.reportError };
        };
    }

    *initClass {
        StartUp.add {
            OSCdef(\nb_synthy_init, { this.start }, '/nb_synthy/init');
            OSCdef(\nb_synthy_free, { this.free }, '/nb_synthy/free');
            OSCdef(\nb_synthy_panic, { this.dispatch(\panic, []) }, '/nb_synthy/panic');
            OSCdef(\nb_synthy_on, { |msg|
                this.dispatch(\noteOn, [msg[1].asFloat, msg[2].asFloat])
            }, '/nb_synthy/note_on');
            OSCdef(\nb_synthy_off, { |msg|
                this.dispatch(\noteOff, [msg[1].asFloat])
            }, '/nb_synthy/note_off');
            OSCdef(\nb_synthy_bend, { |msg|
                this.dispatch(\bend, [msg[1].asFloat, msg[2].asFloat])
            }, '/nb_synthy/bend');
            OSCdef(\nb_synthy_param, { |msg|
                this.dispatch(\param, [msg[1].asSymbol, msg[2].asFloat])
            }, '/nb_synthy/param');
            ServerQuit.add({ this.free });
        };
    }
}
