/* Tactus — 16-step Tap Sequencer with GUI (single instrument) */

(
s.waitForBoot({

///////////////////////////////
// 1) Sound
///////////////////////////////

SynthDef(\tactusHit, { |out=0, vel=0.6|
    var amp = vel.linlin(0, 1, 0.15, 1.0);
    var env = EnvGen.kr(
        Env.perc(0.001, vel.linlin(0,1,0.06,0.14)),
        doneAction:2
    );

    var noiseAmt = vel.linlin(0, 1, 0.05, 0.35);
    var freq     = vel.linexp(0, 1, 140, 320);

    var sig = (SinOsc.ar(freq) * env)
            + (WhiteNoise.ar(noiseAmt) * env);

    Out.ar(out, (sig * amp).dup);
}).add;

SynthDef(\tactusKick, { |out=0, vel=0.6|
    var amp = vel.linlin(0, 1, 0.2, 1.0);
    var env = EnvGen.kr(Env.perc(0.001, 0.25), doneAction:2);
    var freq = vel.linexp(0, 1, 45, 70);

    var sig = SinOsc.ar(freq) * env;
    sig = sig + (BPF.ar(WhiteNoise.ar(0.15), 120, 0.5) * env);

    Out.ar(out, (sig * amp).dup);
}).add;

s.sync;

    /////////////////////////////////
    // 2) Sequencer state
    /////////////////////////////////
    ~steps = 16;
    ~pat   = Array.fill(~steps, 0.0); // 0.0 = empty, >0 = velocity
    ~step  = 0;

    ~bpm = 120;
    ~stepDur = { (60 / ~bpm) / 4 }; // 16ths

    ~isRunning  = false;
    ~writeArmed = true;

    ~zThresh = 10.0;      // you can tweak in code or add a slider later
    ~tapCooldown = 0.12;
    ~lastTap = 0.0;
	~velRange = 1.0; // how far above threshold counts as max velocity (tune 1.0–4.0)
	// Gyroscope-controlled kick layer
    ~kickLayerOn = false;   // whether kick layer is active
    ~gyroThresh  = 1.0;     // rotation threshold for gyro Z


    // UI references (assigned later)
    ~ui = IdentityDictionary.new;

    ~patString = {
        var s = "";
        ~steps.do { |i|
            s = s ++ (if(~pat[i] > 0.0) { "x" } { "." });
        };
        s
    };

    ~updateUI = {
        if(~ui[\stepText].notNil) {
            ~ui[\stepText].string = "Step: " ++ ~step;
        };
        if(~ui[\patText].notNil) {
            ~ui[\patText].string = "Pattern: " ++ ~patString.();
        };
        if(~ui[\statusText].notNil) {
            ~ui[\statusText].string =
            "Status: " ++ (if(~isRunning){"RUNNING"}{"STOPPED"}) ++
            " | Write: " ++ (if(~writeArmed){"ON"}{"OFF"}) ++
            " | BPM: " ++ ~bpm.asInteger;
        };
    };

    /////////////////////////////////
    // 3) Sequencer task (start/stop)
    /////////////////////////////////
    ~startSeq = {
        if(~seqTask.notNil) { ~seqTask.stop; };

        ~isRunning = true;

        ~seqTask = Task({
           loop {
    var v;

    v = ~pat[~step];
    if(v > 0.0) { Synth(\tactusHit, [\vel, v]); };

    ~step = (~step + 1) % ~steps;

    { ~updateUI.() }.defer;

    ~stepDur.().wait;
}

        }).play(SystemClock);

        ~updateUI.();
    };

    ~stopSeq = {
        ~isRunning = false;
        if(~seqTask.notNil) { ~seqTask.stop; };
        ~updateUI.();
    };

    ~clearPat = {
        ~pat = Array.fill(~steps, 0.0);
        ~updateUI.();
    };

    /////////////////////////////////
    // 4) OSC Tap -> write step
    /////////////////////////////////
    OSCdef(\tapZ).free;

OSCdef(\tapZ, { |msg|
    var z = msg[1].asFloat;
    var now = SystemClock.seconds;
    var vel, writeStep;

    if((z > ~zThresh) and: { (now - ~lastTap) > ~tapCooldown }) {

        ~lastTap = now;

        vel = ((z - ~zThresh) / ~velRange).clip(0.0, 1.0);

        if(~writeArmed) {
            writeStep = (~step + 1) % ~steps;
            ~pat[writeStep] = vel;
        };

        // base sound
        Synth(\tactusHit, [\vel, vel]);

        // optional kick layer
        if(~kickLayerOn) {
            Synth(\tactusKick, [\vel, vel]);
        };

        { ~updateUI.() }.defer;
    };
}, "/accelerometer/z");

	///////////////////////////////
         // 4b) Gyroscope → kick layer
    ///////////////////////////////

OSCdef(\gyroZ).free;

OSCdef(\gyroZ, { |msg|
    var gz = msg[1].asFloat;

    // rotate left → enable kick layer
    if(gz < ~gyroThresh.neg) {
        ~kickLayerOn = true;
    };

    // return to rest → disable kick layer
    if(gz.abs < 0.2) {
        ~kickLayerOn = false;
    };

}, "/gyroscope/z");


  /////////////////////////////////
    // 5) GUI
    /////////////////////////////////
    if(~ui[\win].notNil) { ~ui[\win].close; };

    ~ui[\win] = Window("Tactus — 16-step Tap Sequencer", Rect(200, 200, 520, 220)).front;
    ~ui[\win].alwaysOnTop_(true);

    ~ui[\statusText] = StaticText(~ui[\win], Rect(10, 10, 500, 20))
        .string_("Status: STOPPED | Write: ON | BPM: 120");

    ~ui[\stepText] = StaticText(~ui[\win], Rect(10, 35, 500, 20))
        .string_("Step: 0");

    ~ui[\patText] = StaticText(~ui[\win], Rect(10, 60, 500, 20))
        .string_("Pattern: " ++ ~patString.());

    // Start/Stop button
    ~ui[\startStop] = Button(~ui[\win], Rect(10, 95, 120, 30))
        .states_([
            ["Start", Color.black, Color.green(0.7)],
            ["Stop",  Color.white, Color.red(0.7)]
        ])
        .action_({ |b|
            if(b.value == 1) { ~startSeq.() } { ~stopSeq.() };
        });

    // Clear button
    ~ui[\clear] = Button(~ui[\win], Rect(140, 95, 120, 30))
        .states_([["Clear", Color.white, Color.gray(0.4)]])
        .action_({ ~clearPat.() });

    // Write Armed toggle
    ~ui[\write] = Button(~ui[\win], Rect(270, 95, 120, 30))
        .states_([
            ["Write ON",  Color.black, Color.yellow(0.8)],
            ["Write OFF", Color.white, Color.gray(0.3)]
        ])
        .value_(0)
        .action_({ |b|
            ~writeArmed = (b.value == 0);
            ~updateUI.();
        });

    // BPM slider (60–180)
    ~ui[\bpmLabel] = StaticText(~ui[\win], Rect(10, 140, 120, 20)).string_("BPM: 120");
    ~ui[\bpm] = Slider(~ui[\win], Rect(60, 140, 330, 20))
        .value_((~bpm - 60) / (180 - 60))
        .action_({ |sl|
            ~bpm = (60 + (sl.value * 120)).round(1);
            ~ui[\bpmLabel].string = "BPM: " ++ ~bpm.asInteger;
            ~updateUI.();
        });

    // Helpful note
    StaticText(~ui[\win], Rect(10, 170, 500, 40))
        .string_("OSC: /accelerometer/z (port " ++ NetAddr.langPort ++ ").\nTap writes when Write ON. Tap always gives audio feedback.");

    ~updateUI.();

});
)
