# ==============================================================================
# APU
# ==============================================================================

var APU = {
  canvas_settings: {
    "name": "Total Fuel",
    "size": [210, 110],
    "view": [210, 110],
    "mipmapping": 1
  },
  new: func(placement, prop)
  {
    debug.dump("Initializing APU Panel...");
    
    var m = {
      parents: [APU],
      canvas: canvas.new(APU.canvas_settings),
      input: props.globals.getNode(prop, 1)
    };

    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0.02, 0.04, 0.02);

    m.label =
      m.canvas.createGroup()
              .createChild("text")
              .set("font", "7-Segment.ttf")
              .set("character-size", 40)
              .set("fill", "#33cc33")
              .set("alignment", "center-baseline")
              .setText("---")
              .setTranslation(105, 95);

    return m;
  },
  update: func()
  {
    me.label.setText( sprintf("%3.0f", me.input.getValue()) );
    settimer(func me.update(), 0.5);
  }
};

var Voltmeter = {
  canvas_settings: {
    "name": "Voltmeter",
    "size": [240, 110],
    "view": [240, 110],
    "mipmapping": 1
  },
  new: func(placement, prop)
  {
    debug.dump("Initializing Voltmeter...");
    
    var m = {
      parents: [Voltmeter],
      canvas: canvas.new(Voltmeter.canvas_settings),
      input: props.globals.getNode(prop, 1)
    };

    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0.02, 0.04, 0.02);

    m.label =
      m.canvas.createGroup()
              .createChild("text")
              .set("font", "7-Segment.ttf")
              .set("character-size", 40)
              .set("fill", "#33cc33")
              .set("alignment", "center-baseline")
              .setText("--.-")
              .setTranslation(120, 95);

    return m;
  },
  update: func()
  {
    me.label.setText( sprintf("%2.1f", me.input.getValue()) );
    settimer(func me.update(), 0.5);
  }
};

var init_apu = setlistener("/sim/signals/fdm-initialized", func() {
  removelistener(init_apu); # only call once
  var apu_egt = APU.new({node: "Canvas APU EGT"}, "/systems/apu/egt-degc");
  var apu_rpm = APU.new({node: "Canvas APU RPM"}, "/systems/apu/rpm");
  var dc_volt = Voltmeter.new({node: "Canvas DC Voltmeter"}, "/systems/electrical/suppliers/battery");
  apu_egt.update();
  apu_rpm.update();
  dc_volt.update();
});
