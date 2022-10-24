var ramp = {
  new: func(path = "/controls/doors/cargo-ramp/", min = 0, max = 1, speed = 0.1) {
    var m = { parents: [ramp] };
    var node = props.globals.getNode(path, 1);
    m.node_pos = node.initNode("position", 0, "DOUBLE");
    m.node_up = node.initNode("trigger-up", 0, "BOOL");
    m.node_down = node.initNode("trigger-down", 0, "BOOL");
    m.speed = speed;
    m.min = min;
    m.max = max;

    m.dt = props.globals.getNode("sim/time/delta-sec");
    m.update();

    return m;
  },
  update: func() {
    var dt = me.dt.getValue();
    var move = me.node_up.getValue() - me.node_down.getValue();
    var new_val = me.node_pos.getValue() + move * dt * me.speed;

    if( new_val < me.min or new_val > me.max )
    {
      new_val = math.min(me.max, math.max(me.min, new_val));
      me.node_up.setValue(0);
      me.node_down.setValue(0);
    }

    me.node_pos.setValue(new_val);
    settimer(func me.update(), 0);
  },
};

var r = ramp.new("/controls/doors/cargo-ramp", -0.366, 0.244, -0.04);
