# ==============================================================================
# Control Display and Management Unit
# ==============================================================================

var CDMU = {
  canvas_settings: {
    "name": "CDMU",
    "size": [640, 468],
    "view": [320, 234],
    "mipmapping": 1
  },
  new: func(placement)
  {
    debug.dump("Initializing CDMU...");
    
    var m = {
      parents: [CDMU],
      canvas: canvas.new(CDMU.canvas_settings),
      init: 0
    };

    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0.02, 0.04, 0.02);

    m.root =
      m.canvas.createGroup()
              .set('font', "LiberationFonts/LiberationMono-Bold.ttf")
              .set('character-size', 12);

    m.root.createChild("text")
          .setText("Hello C-130J")
          .setAlignment("center-top")
          .setTranslation(160, 10)
          .setColor("#30ff30");
    
    return m;
  },
  update: func()
  {
#    settimer(func me.update(), 0.05);
  }
};

var init_cdmu = setlistener("/sim/signals/fdm-initialized", func() {
  removelistener(init_cdmu); # only call once
  var cdmu1 = CDMU.new({parent: "CDMS Pilot", node: "CDMS Display"});
  cdmu1.update();
});
