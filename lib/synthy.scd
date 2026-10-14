// Synthy audio backend, loaded only when the n.b. voice is activated.
// DSP and kinematics adapted from schollz/synthy (MIT).
(
    var root, voicesGroup, fx, fxBus, filterReply, motion;
    var settings, notes, live, pending, ready=false, generation=0, filterHz=6000;
    var api = IdentityDictionary.new;

    api[\definitions] = {
        // Resolve optional UGens at activation, never in the boot class library.
        var ladder = \MoogLadder.asClass;
        var saw = \SawDPW.asClass;
        if(ladder.isNil or: { saw.isNil }) {
            "[nb_synthy] compatibility sound: using stock UGens where needed".postln;
        };
		SynthDef("nb_synthy_fx",{
			arg in, out, reverb=0.02, hold_control=5.0, t_trig=0.0,
				lpf=6000,flang=0,lpf_lag=2,autofilter=1,level=1;
			var snd,z,y,filterpos,filterswitch,flanger;
			snd = In.ar(in,2);
			// global filter
			lpf = lpf.lag(lpf_lag);
			filterswitch=EnvGen.kr(Env.new([0,1,1,0],[0.5,hold_control,4]),gate:t_trig);
			filterpos=SelectX.kr(filterswitch,[
				LinExp.kr(VarLag.kr(LFNoise0.kr(1/6),6,warp:\sine),-1,1,3200,8000),
				lpf
			]);
			
			filterpos=Select.kr(autofilter, [lpf, filterpos]).clip(20,20000);
			// add flanger
			flanger = snd+LocalIn.ar(2); //add some feedback
			flanger= DelayN.ar(flanger,0.02,SinOsc.kr(0.1,0,0.005,0.005)); //max delay of 20msec
			LocalOut.ar(0.5*flanger);
			snd=SelectX.ar(flang,[snd,flanger]);

			SendReply.kr(Impulse.kr(5), "/nb_synthy/filter", [filterpos]);
			snd=if(ladder.notNil, {
                ladder.ar(snd.tanh,filterpos)
            }, {
                MoogFF.ar(snd.tanh,filterpos,0)
            });


			
			// reverb predelay time :
			z = DelayN.ar(snd, 0.048);
			// 7 length modulated comb delays in parallel :
			y = Mix.ar(Array.fill(7,{ CombL.ar(z, 0.1, LFNoise1.kr(0.1.rand, 0.04, 0.05), 15) }));
			// two parallel chains of 4 allpass delays (8 total) :
			4.do({ y = AllpassN.ar(y, 0.050, [0.050.rand, 0.050.rand], 1) });
			// add original sound to reverb and play it :
			snd=snd+(reverb*y);
			snd=HPF.ar(snd,20);

			// Scoped output gain, independent of the host engine.
			Out.ar(out,snd * Lag.kr(level,0.02));
		}).add;

		SynthDef("nb_synthy_osc",{
			arg out=0,hz=220,amp=0.5,gate=1,sub=0,portamento=1,
			attack=1.0,decay=0.2,sustain=0.9,release=5,
			perturb1=0,t_trig1=0,perturb2=0,t_trig2=0,bend=0;
			var snd,note,env;
			var perturb1val,perturb2val;
			note=Lag.kr(hz * bend.midiratio,portamento).cpsmidi;
			perturb1val=VarLag.kr(EnvGen.kr(Env.perc(1/30,1/30,Latch.kr(perturb1,t_trig1)),t_trig1),0.1,warp:\sine);
			perturb2val=VarLag.kr(EnvGen.kr(Env.perc(1/30,1/30,Latch.kr(perturb2,t_trig2)),t_trig2),0.1,warp:\sine).abs;
			note=note+(note*perturb1val);
			sub=Lag.kr(sub,1);
			snd=Pan2.ar(Pulse.ar((note-12).midicps,LinLin.kr(LFTri.kr(0.5),-1,1,0.2,0.8))/12*amp*sub);
			snd=snd+Mix.ar({
				var snd2;
				snd2=if(saw.notNil, { saw.ar(note.midicps) }, { Saw.ar(note.midicps) });
				snd2=LPF.ar(snd2,LinExp.kr(SinOsc.kr(rrand(1/30,1/10),rrand(0,2*pi)),-1,1,2000,12000));
				snd2=DelayC.ar(snd2, rrand(0.01,0.03), LFNoise1.kr(Rand(5,10),0.01,0.02)/15 );
				Pan2.ar(snd2,VarLag.kr(LFNoise0.kr(1/3),3,warp:\sine))/12*amp
			}!2);
			env=EnvGen.ar(Env.adsr(attack,decay,sustain,release),gate,doneAction:2);
			env=env*Clip.ar(1+(perturb2val*LFPar.ar(perturb2val*10).range(-1,0)));
			Out.ar(out,snd*env);
		}).add;

    };

    api[\defaults] = {
        settings = (sub:1, attack:1, decay:0.1, sustain:0.9, release:5,
            portamento:1, lpf:6000, hold_control:5, lpf_lag:2,
            flanger:0, reverb:0.02, detuning:1, tremolo:1, level:1, autofilter:1);
        notes = Dictionary.new;
        live = List.new;
        pending = Dictionary.new;
    };

    api[\start] = {
        var ticket;
        api[\free].value;
        api[\defaults].value;
        ticket = generation;
        Routine({
            var server = Server.default;
            try {
            api[\definitions].value;
            server.sync;
            // An old init must not recreate nodes after a script change/free.
            if(ticket == generation) {
                fxBus = Bus.audio(server, 2);
                root = Group.head(server.defaultGroup);
                voicesGroup = Group.head(root);
                fx = Synth.tail(root, \nb_synthy_fx, [\in, fxBus.index, \out, 0]);
                filterReply = OSCFunc({ |msg|
                    filterHz = msg[3].asFloat.clip(20,20000);
                }, '/nb_synthy/filter', server.addr, argTemplate:[fx.nodeID]);
                ready = true;
                settings.keysValuesDo { |key, value| api[\applyParam].value(key, value) };
                api[\applyParam].value(\lpf, settings[\lpf]);
                pending.keysValuesDo { |id, spec|
                    api[\noteOn].value(id, spec[0]);
                    api[\bend].value(id, spec[1]);
                };
                pending.clear;
                api[\startMotion].value;
            };
            } { |error|
                api[\free].value;
                "[nb_synthy] voice initialization failed; host audio left running".warn;
                error.reportError;
            };
        }).play(AppClock);
    };

    api[\applyParam] = { |key, value|
        if(ready) {
            switch(key,
                \lpf, { fx.set(\lpf, value, \t_trig, 1) },
                \flanger, { var x=value/100; fx.set(\flang, x*x*(x-1).exp) },
                \sub, { api[\updateSub].value },
                \detuning, {}, \tremolo, {},
                {
                    if([\attack,\decay,\sustain,\release,\portamento].includes(key)) {
                        voicesGroup.set(key, value);
                    } {
                        fx.set(key, value);
                    };
                }
            );
        };
    };

    api[\param] = { |key, value|
        // Only controls belonging to this voice may cross the OSC boundary.
        if(settings.notNil and: { settings.includesKey(key) }) {
            settings[key] = value;
            api[\applyParam].value(key, value);
        };
    };

    api[\updateSub] = {
        var lowest;
        if(notes.notNil and: { notes.size > 0 }) {
            lowest = notes.values.asArray.sort { |a,b| a[\pitch] < b[\pitch] }.first;
            live.do { |record|
                record[\node].set(\sub, if(record === lowest, {settings[\sub]}, {0}));
            };
        };
    };

    api[\noteOn] = { |id, velocity|
        if(velocity <= 0) {
            api[\noteOff].value(id);
        } {
            if(ready) {
                api[\allocateNote].value(id, velocity);
            } {
                if(pending.notNil) { pending[id] = [velocity, 0] };
            };
        };
    };

    api[\allocateNote] = { |id, velocity|
        var previous, oldest, node, record, pitch;
        pitch = id.mod(128);
        previous = notes.removeAt(id);
        if(previous.notNil) { previous[\node].set(\gate, -1.01, \sub, 0) };
        // Eight held notes; oldest-note stealing. Released nodes have a separate cap.
        if(notes.size >= 8) {
            oldest = live.detect { |item| notes[item[\id]] === item };
            if(oldest.notNil) {
                notes.removeAt(oldest[\id]);
                oldest[\node].set(\gate, -1.01, \sub, 0);
            };
        };
        while { live.size >= 16 } {
            oldest = live.removeAt(0);
            if(notes[oldest[\id]] === oldest) { notes.removeAt(oldest[\id]) };
            oldest[\node].free;
        };
        node = Synth.tail(voicesGroup, \nb_synthy_osc, [
            \out, fxBus.index, \hz, pitch.midicps, \amp, velocity.clip(0,1),
            \sub, 0, \attack, settings[\attack], \decay, settings[\decay],
            \sustain, settings[\sustain], \release, settings[\release],
            \portamento, settings[\portamento]
        ]);
        record = (id:id, pitch:pitch, node:node);
        notes[id] = record;
        live.add(record);
        node.onFree {
            if(live.notNil) { live.remove(record) };
            if(notes.notNil and: { notes[id] === record }) {
                notes.removeAt(id);
                api[\updateSub].value;
            };
        };
        api[\updateSub].value;
    };

    api[\noteOff] = { |id|
        var record;
        if(pending.notNil) { pending.removeAt(id) };
        if(ready) {
            record = notes.removeAt(id);
            if(record.notNil) {
                record[\node].set(\gate, 0);
                api[\updateSub].value;
            };
        };
    };

    api[\bend] = { |id, amount|
        if(ready) {
            if(notes[id].notNil) { notes[id][\node].set(\bend, amount.clip(-48,48)) };
        } {
            if(pending.notNil and: { pending[id].notNil }) { pending[id][1] = amount };
        };
    };

    api[\panic] = {
        if(pending.notNil) { pending.clear };
        if(notes.notNil) { notes.clear };
        if(live.notNil) { live.clear };
        if(voicesGroup.notNil) { voicesGroup.freeAll };
    };

    api[\free] = {
        generation = generation + 1;
        ready = false;
        if(motion.notNil) { motion.stop; motion = nil };
        if(filterReply.notNil) { filterReply.free; filterReply = nil };
        api[\panic].value;
        if(root.notNil) { root.free; root = nil };
        if(fxBus.notNil) { fxBus.free; fxBus = nil };
        voicesGroup = nil;
        fx = nil;
    };

    api[\startMotion] = {
        // The original six-joint creature, computed without screen/encoder hooks.
        // Same 15 Hz update cadence. Wall-clock phases replace the host beat clock.
        var arms = Array.fill(2, { |i|
            (u:if(i == 0, {-1}, {1}), angles:[0,0,0], x:0, y:0, z:0, w:0)
        });
        var began = Main.elapsedTime;
        var lfo = { |t, period, offset| sin((2*pi*t/period) + offset) };
        filterHz = settings[\lpf];
        motion = Routine({
            loop {
                var t = Main.elapsedTime - began;
                var posX = settings[\flanger].linlin(0,100,30,128.9).floor;
                var posY = filterHz.explin(125,16000,90,1).clip(10,128).floor;
                var points = Array.newClear(2);
                arms.do { |arm, index|
                    var i = index+1, u=arm[\u], v=0, p, q=62, e, f;
                    p = lfo.(t,i*5,i*3).linlin(-1,1,16,24);
                    if(index == 1) { p = lfo.(t,i*5,i*3).linlin(-1,1,104,112) };
                    e = posX + (index*20) - 10 + lfo.(t,i*4,i*2).linlin(-1,1,-1,2);
                    f = posY + lfo.(t,i*5,i*3).linlin(-1,1,-1,2);
                    3.do { |joint|
                        var angle = arm[\angles][joint] * 2*pi;
                        var c=cos(angle), s=sin(angle), oldU=u, m, n;
                        u = (u*c) - (v*s);
                        v = (oldU*s) + (v*c);
                        m = p + (u*25); n = q + (v*25);
                        arm[\angles][joint] = arm[\angles][joint]
                            + ((((q-arm[\w])*arm[\x]) + ((arm[\z]-p)*arm[\y])) * 0.0001);
                        p=m; q=n;
                    };
                    arm[\x]=(e-p)*0.1; arm[\y]=(f-q)*0.1; arm[\z]=p; arm[\w]=q;
                    points[index]=[p,q];
                };
                voicesGroup.set(
                    \perturb1, (points[0][0]-points[1][0]+32)/400*settings[\detuning],
                    \t_trig1, 1,
                    \perturb2, (points[0][1]-points[1][1]+3).abs.neg/10*settings[\tremolo],
                    \t_trig2, 1
                );
                (1/15).wait;
            }
        }).play(AppClock);
    };


    api;
)
