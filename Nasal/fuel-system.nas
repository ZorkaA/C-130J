# ==============================================================================
# Head down display
# ==============================================================================

var FuelPanel = {
  canvas_settings: {
    "name": "Total Fuel",
    "size": [390, 260],
    "view": [390, 260],
    "mipmapping": 1
  },
  new: func(placement)
  {
    debug.dump("Initializing Fuel Panel...");
    
    var m = {
      parents: [FuelPanel],
      canvas: canvas.new(FuelPanel.canvas_settings),
      listener: [],
      listener_poll: [],
      init: 0
    };

    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0.02, 0.04, 0.02);

    m.root =
      m.canvas.createGroup()
              .set("font", "7-Segment.ttf")
              .set("character-size", 46)
              .set("fill", "#33cc33")
              .set("alignment", "center-center");

    m.set_lbs =
      m.root.createChild("text")
            .setText("-----")
            .setTranslation(195, 72);
    m.total_lbs =
      m.root.createChild("text")
            .setText("-----")
            .setTranslation(195, 188);

    m.input = {
      total_fuel: "/consumables/fuel/total-fuel-lbs"
    };
    
    foreach(var name; keys(m.input))
      m.input[name] = props.globals.getNode(m.input[name], 1);

    return m;
  },
  update: func()
  {
    me.total_lbs.setText( sprintf("%4d0", (me.input.total_fuel.getValue() + 5) / 10) );
    settimer(func me.update(), 0.5);
  }
};

var init_fuel = setlistener("/sim/signals/fdm-initialized", func() {
  removelistener(init_fuel); # only call once
  var total_fuel = FuelPanel.new({node: "Canvas Total Fuel"});
  total_fuel.update();
});
