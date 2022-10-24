# ==============================================================================
# Head up display
# ==============================================================================

var pow2 = func(x) { return x * x; };
var vec_length = func(x, y) { return math.sqrt(pow2(x) + pow2(y)); };
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var clamp = func(x, min, max) { return x < min ? min : (x > max ? max : x); }

var HUD = {
  canvas_settings: {
    "name": "HUD",
    "size": [1024, 1024],
    "view": [480, 360],
    "mipmapping": 1
  },
  new: func(placement)
  {
    var m = {
      parents: [HUD],
      canvas: canvas.new(HUD.canvas_settings)
    };

    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0.36, 1, 0.3, 0.02);
    
    m.root =
      m.canvas.createGroup()
              .setScale(1, 1/math.cos(25 * math.pi/180))
              .setTranslation(240, 180)
              .set("font", "LiberationFonts/LiberationMono-Regular.ttf")
              .setDouble("character-size", 18)
              .setDouble("character-aspect-ration", 0.9)
              .set("stroke", "rgba(0,255,0,0.9)");
    m.text =
      m.root.createChild("group")
            .set("fill", "rgba(0,255,0,0.9)");

    # Heading
    m.hdg =
      m.text.createChild("text")
            .setDrawMode(3)
            .set("background", "#00ff00")
            .setPadding(2)
            .setAlignment("center-top")
            .setTranslation(0, -140);

    # Airspeed
    m.airspeed =
      m.text.createChild("text")
            .setAlignment("right-center")
            .setTranslation(-180, 0);
    
    # Groundspeed
    m.groundspeed =
      m.text.createChild("text")
            .setAlignment("left-center")
            .setTranslation(-220, 90);
    
    # Vertical speed
    m.vertical_speed =
      m.text.createChild("text")
            .setFontSize(10, 0.9)
            .setAlignment("right-center")
            .setTranslation(205, 50);
    
    # Radar altidude
    m.rad_alt =
      m.text.createChild("text")
            .setAlignment("right-center")
            .setTranslation(220, 70);

    # Waterline / Pitch indicator
      m.root.createChild("path")
            .moveTo(-24, 0)
            .horizTo(-8)
            .lineTo(-4, 6)
            .lineTo(0, 0)
            .lineTo(4, 6)
            .lineTo(8, 0)
            .horizTo(24)
            .setStrokeLineWidth(0.9);
    
    # Flightpath/Velocity vector
    m.fpv = m.root.createChild("group", "FPV");
    m.fpv.createChild("path")
         .moveTo(8, 0)
         .arcSmallCCW(8, 8, 0, -16, 0)
         .arcSmallCCW(8, 8, 0,  16, 0)
         .moveTo(-8, 0)
         .horiz(-16)
         .moveTo(8, 0)
         .horiz(16)
         .setStrokeLineWidth(0.9);

    # Energy/Acceleration cues
    m.energy_cue =
      m.fpv.createChild("path")
           .setStrokeLineWidth(1);

    m.acc =
      m.fpv.createChild("path")
           .setStrokeLineWidth(1);
    
    # glide slope deviation
    m.gs_dev_group =
      m.root.createChild("group")
            .setTranslation(-120, 0)
            .set("fill", "rgba(0,255,0,0.9)");
    m.gs_dev_group.createChild("path")
                  .set("stroke-width", 3)
                  .moveTo(-4, 0)
                  .horiz(8);
    var gs_scale =
      m.gs_dev_group.createChild("path")
                    .set("stroke", "none");

    for(var i = -2; i <= 2; i += 1)
    {
      if( i == 0 )
        continue;
      
      gs_scale.moveTo(-2.75, i * 8.5)
              .arcSmallCCW(2.75,2.75,0,5.5,0)
              .arcSmallCCW(2.75,2.75,0,-5.5,0);
    }
    
    m.gs_dev =
      m.gs_dev_group.createChild("path")
                    .set("fill", "none")
                    .set("stroke-width", 2)
                    .moveTo(-12,-4)
                    .line(6,4)
                    .line(-6,4);
    
    # Horizon
    m.horizon_group = m.root.createChild("group");
    m.h_trans = m.horizon_group.createTransform();
    m.h_rot   = m.horizon_group.createTransform();
    
    # Pitch lines
    for(var i = 5; i <= 10; i += 5)
    {
      m.horizon_group.createChild("path")
                     .moveTo(24, -i * 18)
                     .horiz(48)
                     .vert(7)
                     .moveTo(-24, -i * 18)
                     .horiz(-48)
                     .vert(7)
                     .setStrokeLineWidth(1.5);
    }
    
    # Horizon line
    m.horizon_group.createChild("path")
                   .moveTo(-500, 0)
                   .horizTo(500)
                   .setStrokeLineWidth(1.5);

    m.input = {
      pitch:      "/orientation/pitch-deg",
      roll:       "/orientation/roll-deg",
      hdg:        "/orientation/heading-deg",
      speed_n:    "velocities/speed-north-fps",
      speed_e:    "velocities/speed-east-fps",
      speed_d:    "velocities/speed-down-fps",
      alpha:      "/orientation/alpha-deg",
      beta:       "/orientation/side-slip-deg",
      ias:        "/velocities/airspeed-kt",
      gs:         "/velocities/groundspeed-kt",
      vs:         "/velocities/vertical-speed-fps",
      gs_dev:     "/instrumentation/nav/gs-needle-deflection-norm",
      rad_alt:    "/instrumentation/radar-altimeter/radar-altitude-ft",
      wow_nlg:    "/gear/gear[4]/wow",
      airspeed:   "/velocities/airspeed-kt",
      target_spd: "/autopilot/settings/target-speed-kt",
      acc:        "/fdm/jsbsim/accelerations/udot-ft_sec2"
    };
    
    foreach(var name; keys(m.input))
      m.input[name] = props.globals.getNode(m.input[name], 1);
    
    return m;
  },
  update: func()
  {
    me.airspeed.setText(sprintf("%d", me.input.ias.getValue()));
    me.groundspeed.setText(sprintf("G %3d", me.input.gs.getValue()));
    me.vertical_speed.setText(sprintf("%.1f", me.input.vs.getValue() * 60.0 / 1000));
    
    var rad_alt = me.input.rad_alt.getValue();
    if( rad_alt and rad_alt < 5000 ) # Only show below 5000AGL
      rad_alt = sprintf("R %4d", rad_alt);
    else
      rad_alt = nil;
    me.rad_alt.setText(rad_alt);
    
    me.hdg.setText(sprintf("%03d", me.input.hdg.getValue()));
    me.h_trans.setTranslation(0, 18 * me.input.pitch.getValue());
    
    var rot = -me.input.roll.getValue() * math.pi / 180.0;
    me.h_rot.setRotation(rot);
    
    # flight path vector (FPV)
    var vel_gx = me.input.speed_n.getValue();
    var vel_gy = me.input.speed_e.getValue();
    var vel_gz = me.input.speed_d.getValue();
    
    var yaw = me.input.hdg.getValue() * math.pi / 180.0;
    var roll = me.input.roll.getValue() * math.pi / 180.0;
    var pitch = me.input.pitch.getValue() * math.pi / 180.0;
    
    var sy = math.sin(yaw);   var cy = math.cos(yaw);
    var sr = math.sin(roll);  var cr = math.cos(roll);
    var sp = math.sin(pitch); var cp = math.cos(pitch);

    var vel_bx = vel_gx * cy * cp
               + vel_gy * sy * cp
               + vel_gz * -sp;
    var vel_by = vel_gx * (cy * sp * sr - sy * cr)
               + vel_gy * (sy * sp * sr + cy * cr)
               + vel_gz * cp * sr;
    var vel_bz = vel_gx * (cy * sp * cr + sy * sr)
               + vel_gy * (sy * sp * cr - cy * sr)
               + vel_gz * cp * cr;

    var dir_y = math.atan2(round0(vel_bz), math.max(vel_bx, 0.01)) * 180.0 / math.pi;
    var dir_x  = math.atan2(round0(vel_by), math.max(vel_bx, 0.01)) * 180.0 / math.pi;

    me.fpv.setTranslation(dir_x * 18, dir_y * 18);

    var speed_error = 0;
    if( me.input.target_spd.getValue() != nil )
      speed_error = 4 * clamp(
        me.input.target_spd.getValue() - me.input.airspeed.getValue(),
        -15, 15
      );
    
    me.gs_dev.setTranslation(0, -(me.input.gs_dev.getValue() or 0) * 17);
    
    me.energy_cue.reset();
#    if( math.abs(speed_error) > 3 )
      me.energy_cue.moveTo(-22, 0)
                   .vert(speed_error)
                   .horiz(3)
                   .vertTo(0);
    
    var acc = me.input.acc.getValue() or 0;
    me.acc.reset()
          .moveTo(-34, -acc * 5 - 4)
          .line(8, 4)
          .line(-8, 4);

    settimer(func me.update(), 0);
  }
};

var init = setlistener("/sim/signals/fdm-initialized", func() {
  removelistener(init); # only call once
  var hud_pilot = HUD.new({"node": "HUD.l.canvas"});
  hud_pilot.update();
#  var hud_copilot = HUD.new({"node": "HUD.l.canvas.001"});
#  hud_copilot.update();
});
