# ==============================================================================
# Navigation helpers
# ==============================================================================

# ADF
#
# /instrumentation/adf[#]/mode = "adf"
# /instrumentation/adf[#]/ident
# /instrumentation/adf[#]/in-range
# /instrumentation/adf[#]/indicated-bearing-deg
# /instrumentation/adf[#]/frequencies/selected-khz

# ==============================================================================
# Crew alerting system
# ==============================================================================
var CAS =
{
  #
  #
  # @param dt Update interval (sec)
	new: func(node, file, lines, dt = 0.5)
	{
		var m = {
		  parents: [CAS],
		  _types: ['caution', 'warning', 'status'],
		  _colors: [[1,0,0], [1,1,0], [1,1,1]],
		  _msg: {},
		  _dt: dt
		};
		m.lines = lines;
		m.node = aircraft.makeNode(node);
		m.file = file;
		m.reload();
		return m;
	},
	reload: func(file = nil)
	{
	  # clear old messages
	  foreach(var type; me._types)
		  me._msg[type] = [];

	  # and load new ones
		me.file = file == nil ? me.file : file;
    var messages = io.read_properties(me.file).getChildren("message");

    foreach(var message; messages)
		{
			var type = message.getNode("type", 1).getValue();
			if( me._msg[type] == nil )
			{
			  debug.warn("Unknown message type: " ~ type);
			  continue;
			}

			append
			(
			  me._msg[type],
			  {
				  text: message.getNode("text", 1).getValue(),
				  condition: message.getNode("condition", 1),
				  active: 0,
				  line: -1  # line where the message is currently displayed
			  }
			);
		}
	},
	check: func
	{
	  var cur_line = 0;
		for(var i = 0; i < size(me._types); i += 1)
		{
		  var type = me._types[i];
		  var color = me._colors[i];

			foreach(var msg; me._msg[type])
			{
				if( props.condition(msg.condition) )
				{
					if( msg.line != cur_line )
					{
					  msg.line = cur_line;

					  if( !msg.active )
					  {
					    print(msg.text);
					    msg.active = 1 + 10;
					    setprop("sim/sound/cas-msg-status", 0);
					    setprop("sim/sound/cas-msg-status", 1);
					  }

					  if( msg.active > 1 )
					  {
					    me.lines[cur_line].setColorFill(color)
					                      .setColor(0,0,0)
					                      .setDrawMode
					                      (
					                        canvas.Text.TEXT
					                      + canvas.Text.FILLEDBOUNDINGBOX
					                      )
					                      .setPadding(2);
					  }
					  else
					  {
					    me.lines[cur_line].setColor(color)
					                      .setDrawMode(canvas.Text.TEXT);
					  }

					  me.lines[cur_line].setText(msg.text)
					                    .show()
                              .update();
					}

					if( msg.active > 1 )
					{
					  msg.active -= me._dt;

					  if( msg.active <= 1 )
					  {
					    msg.active = 1;

					    me.lines[cur_line].setColor(color)
					                      .setDrawMode(canvas.Text.TEXT)
					                      .update();
					  }
					}

					cur_line += 1;
			  }
			  else
			  {
			    if( msg.active )
			    {
			      print("!" ~ msg.text);
			      msg.active = 0;
			      msg.line = -1;
			    }
			  }

			  if( cur_line == size(me.lines) )
			  {
			    # TODO  handle overflow
			    print("CAS overflow");
			    break;
			  }
			}

		  if( cur_line == size(me.lines) )
		    break;
		}

    for(; cur_line < size(me.lines); cur_line += 1)
      me.lines[cur_line].hide();
	},
	update: func
	{
#		debug.benchmark("check", func me.check(), 10);
    me.check();
		settimer(func me.update(), me._dt);
	}
};

# ==============================================================================
# Head down display
# ==============================================================================

var HDD = {
  canvas_settings: {
    "name": "HDD",
    "size": [768, 1024],
    "view": [768, 1024],
    "mipmapping": 1
  },
  new: func(placement)
  {
    debug.dump("Initializing HDD...");

    var m = {
      parents: [HDD],
      canvas: canvas.new(HDD.canvas_settings),
      listener: [],
      listener_poll: [],
      init: 0
    };

    var font_mapper = func(family, weight)
    {
      if( family == "Ubuntu Mono" and weight == "bold" )
        return "UbuntuMono-B.ttf";
    };

    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0.02, 0.04, 0.02);

    m.root = m.canvas.createGroup();
    canvas.parsesvg
    (
      m.root,
      "Instruments/EICAS.svg",
      {'font-mapper': font_mapper}
    );
    var acaws = m.root.getElementById("ACAWS_10");
    acaws.setText("THE NEW API IS COOL!");
    acaws.setColor(1,0,0);

    m.eng = setsize([], 4);
    for(var i = 0; i < 4; i += 1)
    {
      var eng = m.root.getElementById("eng" ~ (i + 1));

      m.eng[i] = {
        box: eng.getElementById("box"),
        msg: eng.getElementById("msg")
      };
      m.eng[i].box.hide();
      m.eng[i].msg.setText("");

      m.connect
      (
        "/fdm/jsbsim/propulsion/engine[" ~ i ~ "]/power-hp",
        func(d, val)
        {
          var hp_rad = val * (248.3/4600) * math.pi/180;
          d.arc._node.getNode("cmd[1]").setIntValue
          (
            hp_rad < math.pi ? canvas.Path.VG_SCWARC_TO_REL
                             : canvas.Path.VG_LCWARC_TO_REL
          );
          d.arc._node.getNode("coord[5]").setDoubleValue(49 * math.sin(hp_rad));
          d.arc._node.getNode("coord[6]").setDoubleValue(49 * (1 - math.cos(hp_rad)));
          d.dial.setRotation(hp_rad);
          d.text.setText(sprintf("%.0f", val));
        },
        {
          arc: eng.getElementById("arc_hp"),
          dial: eng.getElementById("dial_hp"),
          text: eng.getElementById("readout_hp")
        }
      );
      m.connect
      (
        "/fdm/jsbsim/propulsion/engine[" ~ i ~ "]/itt-c",
        func(d, val)
        {
          d.dial.setRotation(val * (248.3/960) * math.pi/180);
          d.text.setText(sprintf("%.0f", val));
        },
        {
          dial: eng.getElementById("dial_mgt"),
          text: eng.getElementById("readout_mgt")
        }
      );
      m.connect
      (
        "/engines/engine[" ~ i ~ "]/n1",
        func(d, val)
        {
          d.dial.setRotation(val * (248.3/103) * math.pi/180);
          d.text.setText(sprintf("%.0f", val));
        },
        {
          dial: eng.getElementById("dial_ng"),
          text: eng.getElementById("readout_ng")
        }
      );
      m.connect
      (
        "/engines/engine[" ~ i ~ "]/thruster/rpm",
        func(ob, val) ob.setText(sprintf("%.0f", val * 100.0 / 1057)),
        eng.getElementById("NP")
      );
      m.connect
      (
        "/engines/engine[" ~ i ~ "]/fuel-flow_pph",
        func(ob, val) ob.setText(sprintf("%.0f", val)),
        eng.getElementById("FF")
      );
      m.connect
      (
        "/engines/engine[" ~ i ~ "]/oil-pressure-psi",
        func(d, val) d.setText(sprintf("%.1f", val)),
        eng.getElementById("E_PSI")
      );
      m.connect
      (
        "/engines/engine[" ~ i ~ "]/oil-temperature-degf",
        func(d, val) d.setText(sprintf("%.0f", (val - 32) * 5.0/9)),
        eng.getElementById("TEMP")
      );
    }

    m.acaws = setsize([], 15);
    for(var i = 0; i <= 14; i += 1)
      m.acaws[i] = m.root.getElementById("ACAWS_" ~ i);

    m.input = {
      pitch:    "/orientation/pitch-deg",
      roll:     "/orientation/roll-deg",
      hdg:      "/orientation/heading-deg",
      speed_n:  "velocities/speed-north-fps",
      speed_e:  "velocities/speed-east-fps",
      speed_d:  "velocities/speed-down-fps",
      alpha:    "/orientation/alpha-deg",
      beta:     "/orientation/side-slip-deg",
      ias:      "/velocities/airspeed-kt",
      gs:       "/velocities/groundspeed-kt",
      vs:       "/velocities/vertical-speed-fps",
      rad_alt:  "/instrumentation/radar-altimeter/radar-altitude-ft",
      wow_nlg:  "/gear/gear[4]/wow"
    };

    foreach(var name; keys(m.input))
      m.input[name] = props.globals.getNode(m.input[name], 1);

    return m;
  },
  connect: func(prop, cb, data = nil)
  {
    var node = props.globals.getNode(prop);
    if( 1 or node.getAttribute("tied") )
    {
      print("New tied connection for " ~ prop);
      append(me.listener_poll, [
        node,
        data,
        cb,
        node.getValue()
      ]);
    }
    else
    {
      print("New listener connection for " ~ prop);
      append(me.listener, [
        prop,
        data,
        cb,
        setlistener(prop, func(p) cb(data, p.getValue()), 1, 0)
      ]);
    }
  },
  update: func()
  {
    if( me.init < 3 )
    {
      if( (me.init += 1) == 3 )
      {
        foreach(var lp; me.listener)
        {
          # lp = [prop, data, callback, last_value]
          lp[2](lp[1], getprop(lp[0]));
        }
      }
    }
    foreach(var lp; me.listener_poll)
    {
      # lp = [node, data, callback, last_value]
      var val = lp[0].getValue();
      if( lp[3] != val )
      {
        lp[2](lp[1], val);
        lp[3] = val;
      }
    }

#    if( getprop("/sim/fail") )
#    {
#      me.acaws[msg_index].setText("NAC 1 OVERHEAT");
#      me.acaws[msg_index].setColor(1,0,0);
#      msg_index += 1;
#
#      if( getprop("/engines/engine[0]/oil-pressure-psi") < 20 )
#      {
#        me.acaws[msg_index].setText("ENG 1 OIL PRESS LOW");
#        me.acaws[msg_index].setColor(1,1,0);
#        msg_index += 1;
#      }
#
#      setprop("/controls/engines/engine[0]/cutoff", 1);
#      me.eng[0].msg.setText("FAIL");
#    }

    settimer(func me.update(), 0.1);
  }
};

var init_hdd = setlistener("/sim/signals/fdm-initialized", func() {
  removelistener(init_hdd); # only call once
  var hdd1 = HDD.new({parent: "HDD 2", node: "PFD-Screen"});
  hdd1.update();

  var acaws = CAS.new("instrumentation/eicas-messages/page[0]", getprop("/sim/aircraft-dir") ~ "/Systems/acaws.xml", hdd1.acaws);
  acaws.update();

  var font_mapper = func(family, weight)
  {
    if( family == "Ubuntu Mono" and weight == "bold" )
      return "UbuntuMono-B.ttf";
  };

  var pfd = canvas.new({
    "name": "PFD",
    "size": [768, 1024],
    "view": [768, 1024],
    "mipmapping": 1
  });
  pfd.addPlacement({parent: "HDD 1", node: "PFD-Screen"});
  pfd.setColorBackground(0.02, 0.04, 0.02);

  var pfd_root = pfd.createGroup();
  canvas.parsesvg
  (
    pfd_root,
    "Instruments/PFD.svg",
    {'font-mapper': font_mapper}
  );

  var rose = pfd_root.getElementById("rose");
  rose.updateCenter();
  foreach(var c; rose.getChildren())
    if( isa(c, canvas.Text) )
      c.updateCenter();
  var hdg_readout = pfd_root.getElementById("hdg");
  var horizon = pfd_root.getElementById("horizon");
  horizon.updateCenter();
  h_trans = horizon.createTransform();
  h_rot   = horizon.createTransform();
  var bank_indicator = pfd_root.getElementById("bank_indicator");

  var ias_1 = pfd_root.getElementById("ias_readout_1");
  var ias_10 = pfd_root.getElementById("ias_readout_10")
                       .getChildren()[1].set("text", "3\n4")
                                        .set("line-height", 0.85);
  var agl = pfd_root.getElementById("agl_readout");
  var hdg_bug = pfd_root.getElementById("hdg_bug");
  var hdg_bug_readout = pfd_root.getElementById("hdg_bug_readout");

  var ptr_1 = pfd_root.getElementById("brg_ptr_1").updateCenter();
  var ptr_1_freq = pfd_root.getElementById("brg_ptr_1_freq");
  var ptr_1_ident = pfd_root.getElementById("brg_ptr_1_ident");

  var tcas_vs_box = [
    pfd_root.getElementById("tcas_vs_box_t").hide(),
    pfd_root.getElementById("tcas_vs_box_b").hide()
  ];

  var updatePFD = func()
  {
    var hdg_deg = getprop("/orientation/heading-deg");
    hdg_readout.set("text", sprintf("%03d", hdg_deg));
    var hdg = hdg_deg * math.pi / 180.0;
    rose.setRotation(-hdg);
    foreach(var c; rose.getChildren())
      if( isa(c, canvas.Text) )
        c.setRotation(hdg);

    var roll = getprop("/orientation/roll-deg") * math.pi / 180.0;
    h_rot.setRotation(-roll, horizon.getCenter());
    bank_indicator.setRotation(-roll);

    var pitch = getprop("/orientation/pitch-deg");
    # 10 deg -> 124 px
    h_trans.setTranslation(0, pitch * 12.4);

    var ias = getprop("/velocities/airspeed-kt");
    var ias_round = int(ias + 0.5);
    var offset = ias - ias_round;
    ias_1.setTranslation(0, offset * 34);

    var last_digit = ias_round - 10 * int(ias_round / 10) + 1;
    foreach(var c; ias_1.getChildren())
    {
      c.set("text", sprintf("%d", math.mod(last_digit, 10)));
      last_digit -= 1;
    }
    ias_1.update();

    agl.set("text", sprintf("%d", getprop("/instrumentation/radar-altimeter/radar-altitude-ft")));

    var hdg_bug_deg = getprop("/autopilot/settings/heading-bug-deg");
    if( hdg_bug_deg != nil )
    {
      hdg_bug.setRotation(hdg_bug_deg * math.pi / 180.0);
      hdg_bug_readout.set("text", sprintf("%03d", hdg_bug_deg));
    }

    ptr_1_freq.set("text", sprintf("%d", getprop("/instrumentation/adf[0]/frequencies/selected-khz")));
    if( !getprop("/instrumentation/adf[0]/in-range") )
    {
      ptr_1.hide();
      ptr_1_ident.set("text", "-----");
    }
    else
    {
      var brg = hdg_deg
              + getprop("/instrumentation/adf[0]/indicated-bearing-deg");
      ptr_1.show()
           .setRotation(brg * math.pi / 180);
      ptr_1_ident.set("text", getprop("/instrumentation/adf[0]/ident"));
    }

    settimer(updatePFD, 0.1);
  };
  updatePFD();

  var sys_status = canvas.new(HDD.canvas_settings);
  sys_status.addPlacement({parent: "HDD 3", node: "PFD-Screen"});
  sys_status.setColorBackground(0.02, 0.04, 0.02);

  var root = sys_status.createGroup();
  canvas.parsesvg
  (
    root,
    "Instruments/SYSTEM-STATUS.svg",
    {'font-mapper': font_mapper}
  );

  var gen_apu = root.getElementById("gen_apu");
  gen_apu.getElementById("gen_apu_volts_a")
         .set("fill", "#ffffff")
         .set("text", "OFF");
  foreach(var id; ["volts_b", "volts_c", "load"])
    gen_apu.getElementById("gen_apu_" ~ id).hide();

  var echs = canvas.new({
    "name": "ECHS MFCD",
    "size": [1024, 768],
    "view": [1024, 768],
    "mipmapping": 1
  });
  echs.addPlacement({parent: "Actiview 104L", node: "Screen"});
  echs.setColorBackground(0.02, 0.04, 0.02);
  var echs_root = echs.createGroup();
  canvas.parsesvg
  (
    echs_root,
    "Instruments/ECHS-MFCD.svg",
    {'font-mapper': font_mapper}
  );

  var map = canvas.new(HDD.canvas_settings);
  map.addPlacement({parent: "HDD 5", node: "PFD-Screen", 'capture-events': 1});
  map.setColorBackground(1.0, 1.0, 1.0);

  var g = map.createGroup()
             .set("fill", "#646464");
  g.createChild("path")
   .moveTo(256 * 1.5 - 10, 256 * 2)
   .horiz(20)
   .move(-10,-10)
   .vert(20)
   .set("stroke", "red")
   .set("stroke-width", 2)
   .set("z-index", 1);

  # http://polymaps.org/docs/
  # https://github.com/simplegeo/polymaps
  # https://github.com/Leaflet/Leaflet

  var maps_base = getprop("/sim/fg-home") ~ '/cache/maps';

  # http://otile1.mqcdn.com/tiles/1.0.0/map
  # http://otile1.mqcdn.com/tiles/1.0.0/sat
  # http://a.tile.openstreetmap.org
  var makeUrl =
    string.compileTemplate('http://otile1.mqcdn.com/tiles/1.0.0/map/{z}/{x}/{y}.jpg');

  var makePath =
    string.compileTemplate(maps_base ~ '/osm-{type}/{z}/{x}/{y}.jpg');
#    string.compileTemplate(maps_base ~ '/ofm-{type}/{z}/{x}/{y}.png');

  var num_tiles = [4, 5];
  var tiles = setsize([], num_tiles[0]);
  for(var x = 0; x < num_tiles[0]; x += 1)
  {
    tiles[x] = setsize([], num_tiles[1]);
    for(var y = 0; y < num_tiles[1]; y += 1)
      tiles[x][y] = g.createChild("image", "map-tile");
  }

  var last_tile = [-1,-1];
#  var last_path = "/ofm/LOWW_2-3";
  var last_type = "ENR";

#  setprop("/map/path", last_path);
  setprop("/map/zoom", 10);
  setprop("/map/type", last_type);

  var updateTiles = func()
  {
    var lat = getprop('/position/latitude-deg');
    var lon = getprop('/position/longitude-deg');
    var zoom = getprop("/map/zoom");

    var n = math.pow(2, zoom);
    var offset = [
      n * ((lon + 180) / 360) - 1.5,
      (1 - math.ln(math.tan(lat * math.pi/180) + 1 / math.cos(lat * math.pi/180)) / math.pi) / 2 * n - 2
    ];
    var tile_index = [int(offset[0]), int(offset[1])];
#    var path = getprop("/map/path");
    var type = getprop("/map/type");

    var ox = tile_index[0] - offset[0];
    var oy = tile_index[1] - offset[1];

    for(var x = 0; x < num_tiles[0]; x += 1)
      for(var y = 0; y < num_tiles[1]; y += 1)
        tiles[x][y].setTranslation(int((ox + x) * 256 + 0.5), int((oy + y) * 256 + 0.5));

    if(    tile_index[0] != last_tile[0]
        or tile_index[1] != last_tile[1]
#        or path != last_path
        or type != last_type )
    {
      for(var x = 0; x < num_tiles[0]; x += 1)
        for(var y = 0; y < num_tiles[1]; y += 1)
        {
          var pos = {
            z: zoom,
            x: int(offset[0] + x),
            y: int(offset[1] + y),
            type: type
          };

          (func {
          var img_path = makePath(pos);
          var tile = tiles[x][y];

          if( io.stat(img_path) == nil )
          {
            var img_url = makeUrl(pos);
            print('requesting ' ~ img_url);
            http.save(img_url, img_path)
                .done(func {print('received image ' ~ img_path); tile.set("src", img_path);})
                .fail(func (r) print('Failed to get image ' ~ img_path ~ ' ' ~ r.status ~ ': ' ~ r.reason));
          }
          else
          {
            print('loading ' ~ img_path);
            tile.set("src", img_path)
          }
          })();
        }

      last_tile = tile_index;
#      last_path = path;
      last_type = type;
    }

    settimer(updateTiles, 5);
  };
  updateTiles();
});
