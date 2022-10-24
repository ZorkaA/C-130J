# ==============================================================================
# Avionics management unit
# ==============================================================================

var Screen = {
  canvas_settings: {
    "name": "AMU",
    "size": [512, 512],
    "view": [480, 320],
    "mipmapping": 1,
  },
  new: func(placement)
  {
    var m = {
      parents: [Screen],
      canvas: canvas.new(Screen.canvas_settings),
      text_style: {
        'font': "LiberationFonts/LiberationMono-Bold.ttf",
        'character-size': 34,
        'character-aspect-ratio': 1.044
      }
    };

    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0, 0.05, 0);
    m.root = m.canvas.createGroup();

    m.title = m.root.createChild("text");
    m.title._node.setValues(m.text_style);
    m.title.setColor(0,1,0);
    m.title.setAlignment("center-center");

    # Left and right text rows
    m.l = {
      x: 8.25,
      align: "left-center",
      rows: setsize([], 4)
    };
    m.r = {
      x: 471.75,
      align: "right-center",
      rows: setsize([], 4)
    };

    for(var i = 0; i < 4; i += 1)
    {
      var y = 16 + (2 * i + 1) * 32;
      m.l.rows[i] = {
        y: y,
        texts: []
      };
      m.r.rows[i] = {
        y: y + 32,
        texts: []
      };
    }

    return m;
  },
  setRow: func(side, row_index, config)
  {
    # config can either be just the title as single string or an array with two
    # elements where the first element is the title and the second parameter is
    # passed to the callback function for hardware key presses

    var row_config = config[side ~ row_index];
    var label = row_config;
    var property = nil;

    if( typeof(row_config) == 'hash' )
    {
      label = row_config['label'];
      action = row_config['action'];

      if( action != nil )
      {
        var fgcmd = action['fgcmd'];
        if( fgcmd != nil )
        {
          var args = action['args'];
          if( typeof(args) == 'hash' )
            property = args['property'];
          action = func { fgcommand(fgcmd, props.Node.new(args)) };
        }

        me.commands[side ~ row_index] = action;
      }
    }

    if( typeof(label) == 'scalar' )
      label = [label];

    var row = me[side].rows[row_index - 1];
    var num_texts_old = size(row.texts);
    var num_texts_new = label != nil ? size(label) : 0;

    # remove unneeded texts
    for(var i = num_texts_new; i < num_texts_old; i += 1)
      row.texts[i].del();
    setsize(row.texts, num_texts_new);

    # update/create new texts
    var offset = 0;
    var i_start = (side == 'l') ? 0 : num_texts_new - 1;
    var i_end = (side == 'l') ? num_texts_new : -1;
    var dir = (side == 'l') ? 1 : -1;
    for(var i = i_start; i != i_end; i += dir)
    {
      var el_text = row.texts[i];
      if( el_text == nil )
      {
        el_text = me.root.createChild("text");
        el_text.setAlignment(me[side].align);
        el_text.setColor(0, 1, 0, 0.5);
        el_text.setColorFill(0, 1, 0);
        el_text._node.setValues(me.text_style);
        row.texts[i] = el_text;
      }

      el_text.setDrawMode(1);
      el_text.setTranslation(me[side].x + offset, row.y);
      el_text.setColor(0, 1, 0);

      var text = label[i];
      if( typeof(text) == 'vector' )
      {
        (func {
          var text = el_text;
          var prop = property;
          var fun = label[i][1];

          var listener = setlistener(prop, func(p) {
            fun(text, p.getValue())
          }, 1, 0);

          if( me.listener[side ~ row_index] == nil )
            me.listener[side ~ row_index] = [listener];
          else
            append(me.listener[side ~ row_index], listener);
        })();

        text = text[0];
      }
      offset += dir * size(text) * 30.75/1.59;
      el_text.setText(text);
      el_text.update();

#      offset += dir * size(text) * 30.75/1.59;
    }
  },
  setCallback: func(callback)
  {
    me.callback = callback;
  },
  setPage: func(config)
  {
    me.title.setText(config['title']);
    # move to full character position (move half character width on odd length)
    me.title.setTranslation(241 - math.mod(size(config['title']), 2) * 0.5 * 30.75/1.59, 16);
    me.title.update();

    me.commands = {};

    if( me['listener'] != nil )
    {
      foreach(var name; keys(me.listener))
      {
        foreach(var listener; me.listener[name])
          removelistener(listener);
      }
    }
    me.listener = {};

    for(var i = 1; i <= 4; i += 1)
    {
      me.setRow('l', i, config);
      me.setRow('r', i, config);
    }
  },
  onKeyPress: func(key)
  {
    if( typeof(me.callback) != 'func' )
      return;

    var type = substr(key, 0, 3);
    var name = substr(key, 4);

    if( type != "LSK" )
      return;

    var cmd = me.commands[name];
    if( typeof(cmd) == 'func' )
      cmd();
    else if( cmd != nil )
      me.callback(cmd);
  }
};

var AMU = {
  new: func()
  {
    debug.dump("Initializing AMU...");

    var m = {
      parents: [AMU],
      screen_left: Screen.new({"node": "AMU Screen.l"}),
      screen_right: Screen.new({"node": "AMU Screen.r"}),
    };

    m.screen_left.setCallback(func(cmd){ m.onCmd(cmd); });
    m.screen_right.setCallback(func(cmd){ m.onCmd(cmd); });

    var setStyle = func(text, active)
    {
      text.setPadding(5);
      text.setDrawMode(active ? 5 : 1);
      if( active )
        text.setColor(0, 0.05, 0);
      else
        text.setColor(0, 1, 0);
      text.setPadding(3);
      text.update();
    };

    var propertyCycle = func(prop, values, texts)
    {
      var row = {
        label: [],
        action: {
          fgcmd: 'property-cycle',
          args: {
            property: prop,
            value: values
          }
        }
      };

      foreach(var text; texts)
      {
        if( typeof(text) == 'vector' )
        {
          # capture value in closure and add function which
          # changes style upon comparison with the given value
          (func {
            var val = text[1];
            text[1] = func(t,v) setStyle(t, v == val);
          })();
        }

        append(row.label, text);
      }

      return row;
    };

    var page_hdd_pos = {
      'title': "HDD POS",
      'l1': "HDD 1",
      'l2': "HDD 2",
      'l3': "HDD 3",
      'l4': "HDD 4",
      'r1': "DEFAULTS>"
    };

    m.pages = {};
    m.pages['main-menu'] = {
      'left':
      {
        'title': "MAIN MENU",
        'l1': {label: "<PFD", action: {'page': 'pfd'}},
        'l2': {label: "<ENGINE", action: {'page': 'engine'}},
        'l3': "<CAPS",
        'r1': {label: "NAV-RADAR>", action: {'page': 'nav-radar'}},
        'r2': {label: "SYS STATUS>", action: {'page': 'sys-status'}},
        'r3': {label: "DIG MAP>", action: {'page': 'dig-map'}},
        'r4': "TAWS>"
      },
      'right':
      {
        'title': "MAIN MENU",
        'l1': {label: "<NAV SELECT", action: {'page': 'nav-select'}},
        'l2': "<ACAWS",
        'l3': "<DIAGNOSTICS",
        'l4': "<PREFLIGHT",
        'r1': "DEFAULTS>",
        'r3': "LIGHTING>",
        'r4': "GCAS AND STALL>"
      },
    };

    m.pages['pfd'] = {
      'left':
      {
        'title': "PFD",
        'l1': propertyCycle('/instrumentation/pfd[0]/is_pilot', [0,1], [["PILOT",1]," / ",["COPILOT",0]]),
        'l2': propertyCycle('/instrumentation/pfd[0]/baro_unit', ['in','mb'],["BARO ",["IN",'in']," / ",["MB",'mb']]),
        'l3': propertyCycle('/instrumentation/pfd[0]/north', ['mag','true','grid'], [["MAG",'mag']," / ",["TRUE",'true']," / ",["GRID",'grid']]),
        'l4': propertyCycle('/instrumentation/pfd[0]/fd_source', [0,1], ["FD SOURCE ",["P", 1]," / ",["CP",0]]),
        'r1': propertyCycle('/instrumentation/pfd[0]/att_ref_imu', [1,2], ["ATT REF IMU ",["1",1]," / ",["2",2]]),
        'r2': propertyCycle('/instrumentation/pfd[0]/cadc_src', [1,2], ["CADC ",["1",1]," / ",["2",2]]),
        'r3': propertyCycle('/instrumentation/pfd[0]/rad_alt_src', [1,2], ["RAD ALT ", ["1", 1], " / ", ["2", 2]]),
        'r4': {label: "MAIN MENU>", action: {'page': 'main-menu'}}
      },
      'right':
      {
        'title': "HDD POS",
        'l1': "HDD 1",
        'l2': "HDD 2",
        'r1': "DEFAULTS>"
      }
    };

    m.pages['engine'] = {
      'left':
      {
        'title': "ENGINE",
        'l1': "<ENG DIAGNOSTICS",
        'l2': "<PROP SYNC",
        'l3': "EMS DATA DOWNLOAD",
        'l4': "EMS EVENT RECORD",
        'r3': "HDD POS>",
        'r4': {label: "MAIN MENU>", action: {'page': 'main-menu'}}
      },
      'right': page_hdd_pos
    };

    m.pages['nav-radar'] = {
      'left':
      {
        'title': "NAV-RADAR DISPLAY",
        'l1': propertyCycle('/instrumentation/nav[0]/full', [0,1], [["FULL",1]," / ",["PART",0]]),
        'l2': propertyCycle('/instrumentation/nav[0]/center', [0,1], [["CENTER",1]," / ",["OFFSET",0]]),
        'l3': propertyCycle('/instrumentation/nav[0]/north', ['mag','true','grid'], [["MAG",'mag']," / ",["TRUE",'true']," / ",["GRID",'grid']]),
        'l4': propertyCycle('/instrumentation/nav[0]/up', ['hdg','trk','n'], [["HDG",'hdg']," / ",["TK",'trk']," / ",["N",'n']]),
        'r1': "RANGE    2>",
        'r2': "OVERLAYS>",
        'r3': "HDD POS>",
        'r4': {label: "MAIN MENU>", action: {'page': 'main-menu'}}
      },
      'right': page_hdd_pos
    };

    m.pages['sys-status'] = {
      'left':
      {
        'title': "SYS STATUS DISPLAY",
        'r3': "HDD POS>",
        'r4': {label: "MAIN MENU>", action: {'page': 'main-menu'}}
      },
      'right': page_hdd_pos
    };

    m.pages['dig-map'] = {
      'left':
      {
        title: "DIG MAP DISPLAY",
        l1: {label: "<MAP COVERAGE", action: {'page': 'dig-map-coverage'}},
        l2: "CENTER / OFFSET",
        l3: "MAG / TRUE / GRID",
        l4: "HDG / NORTH UP",
        r1: "WHT / YEL / MGN / BLK",
        r2: {label: "OVERLAYS>", action: {'page': 'dig-map-overlays'}},
        r3: {label: "HDD POS>", action: {'page': 'dig-map'}},
        r4: {label: "MAIN MENU>", action: {'page': 'main-menu'}}
      },
      right: page_hdd_pos
    };
    m.pages['dig-map-coverage'] = {
      'right':
      {
        title: "COVERAGE",
        l1: "?",
        l2: "?",
        l3: "?",
        r1: "?",
        r2: "?",
        r3: "?",
        r4: "?"
      }
    };
    m.pages['dig-map-overlays'] = {
      'right':
      {
        title: "OVERLAYS",
        l1: "NAV AIDS",
        l2: "TACTICAL",
        l3: "FLT PLN",
        r4: "CLEAR ALL"
      }
    };

    m.pages['nav-select'] = {
      left:
      {
        title: "NAV SELECT",
        l1: "PILOT / COPILOT",
        l2: {label: "<PNTR 1 TAC 2", action: {page: 'nav-select-ptr1'}},
        l3: {label: "<PNTR 2 ADF 2", action: {page: 'nav-select-ptr2'}},
        l4: "SHIP SOLN INAV 1 / 2",
        r1: {label: "CDI  VOR 1>", action: {page: 'nav-select-cdi'}},
        r3: {label: "EGI POWER>", action: {page: 'nav-select-egi-power'}},
        r4: {label: "MAIN MENU>", action: {'page': 'main-menu'}}
      }
    };
    m.pages['nav-select-ptr1'] = {
      right:
      {
        title: "POINTER 1",
        l1: "VOR 1",
        l2: "TACAN 1",
        l3: "INAV 1",
        l4: "ADF 1",
        r1: "VOR 2",
        r2: "TACAN 2",
        r4: "ADF 2"
      }
    };
    m.pages['nav-select-ptr2'] = {
      right:
      {
        title: "POINTER 2",
        l1: "VOR 1",
        l2: "TACAN 1",
        l3: "INAV 1",
        l4: "ADF 1",
        r1: "VOR 2",
        r2: "TACAN 2",
        r4: "ADF 2"
      }
    };
    m.pages['nav-select-cdi'] = {
      right:
      {
        title: "CDI",
        l1: "VOR 1",
        l2: "TACAN 1",
        l3: "INAV 1",
        l4: "IPRA",
        r1: "VOR 2",
        r2: "TACAN 2"
      }
    };
    m.pages['nav-select-egi-power'] = {
      right:
      {
        title: "EGI POWER",
        l1: "MASTER EGI OFF",
        l2: "EGI 1 RECYCLE",
        r2: "EGI 2 RECYCLE"
      }
    };
    m.pages['nav-select']['right'] = m.pages['nav-select-ptr1']['right'];

    m.setPage('main-menu');

    var input = "/controls/instruments/AMU/input";
    setlistener(input, func(cmd) { m.onInput(cmd); });
    m.node_input = props.globals.getNode(input);

    return m;
  },
  setPage: func(id)
  {
    var page = me.pages[id];

    if( typeof(page) != 'hash' )
      return debug.dump("AMU: Unknown page: " ~ id);

    var left = page['left'];
    if( typeof(left) == 'hash' )
      me.screen_left.setPage(left);

    var right = page['right'];
    if( typeof(right) == 'hash' )
      me.screen_right.setPage(right);
  },
  onInput: func()
  {
    var input = me.node_input.getValue();
    me.node_input.setValue("");

    var prefix = substr(input, 0, 2);
    var cmd = substr(input, 2);

    if( prefix == "L-" )
      me.screen_left.onKeyPress(cmd);
    else if( prefix == "R-" )
      me.screen_right.onKeyPress(cmd);
  },
  onCmd: func(cmd)
  {
    if( typeof(cmd['page']) == 'scalar' )
      me.setPage(cmd['page']);
  }
};

var node_pfd = props.globals.getNode('/instrumentation/pfd[0]/', 1);
node_pfd.initNode('is_pilot', 1, 'BOOL');
node_pfd.initNode('baro_unit', 'mb');
node_pfd.initNode('north', 'true');
node_pfd.initNode('fd_source', 1, 'INT');
node_pfd.initNode('att_ref_imu', 1, 'INT');
node_pfd.initNode('cadc_src', 1, 'INT');
node_pfd.initNode('rad_alt_src', 1, 'INT');

var node_nav = props.globals.getNode('/instrumentation/nav[0]/', 1);
node_nav.initNode('full', 1, 'BOOL');
node_nav.initNode('center', 1, 'BOOL');
node_nav.initNode('north', 'true');
node_nav.initNode('up', 'trk');

setlistener("/nasal/canvas/loaded", func {
  var amu_pilot = AMU.new();
}, 1);
