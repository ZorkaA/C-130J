# Switch
# ==============================================================================
# class for objects moving at constant speed, with the ability to
# reverse moving direction at any point. Appropriate for doors, canopies, etc.
#
# SYNOPSIS:
#	door.new(<property>, <anim-prop>, <swingtime> [, <startpos>]);
#
#	property   ... door node: property path or node
#	anim-prop  ... animation node: property path or node
#	swingtime  ... time in seconds for full movement (0 -> 1)
#	startpos   ... initial position      (default: 0)
#
# PROPERTIES:
#	./position-norm   (double)     (default: <startpos>)
#	./enabled         (bool)       (default: 1)
#
# EXAMPLE:
#	var canopy = Switch.new("sim/model/foo/canopy", 5);
#	canopy.open();
#
var Switch = {
	new: func(node, anim_node, swingtime, pos = 0) {
		var m = { parents: [Switch] };
		m.ctrl_node = aircraft.makeNode(node).initNode("", pos, "BOOL");
		m.anim_node = aircraft.makeNode(anim_node).initNode("", pos, "DOUBLE");
		m.swingtime = swingtime;
		m.target = pos < 0.5;

		m.ctrl_timer = maketimer(swingtime, m, Switch._updateCtrl);
		m.ctrl_timer.singleShot = 1;

    m.ctrl_listen = setlistener(m.ctrl_node, func(p) m.move(p.getValue()), 0, 0);

		return m;
	},
	# door.setpos(double)  ->  set ./position-norm without movement
	setpos: func(pos) {
		me.stop();
		me.anim_node.setValue(pos);
		me.target = pos < 0.5;
		me._updateCtrl();
		me;
	},
	# double door.getpos() ->  return current position as double
	getpos: func {
		me.anim_node.getValue();
	},
	# door.close()         ->  move to closed state
	close: func {
		me.move(me.target = 0);
	},
	# door.open()          ->  move to open state
	open: func {
		me.move(me.target = 1);
	},
	# door.toggle()        ->  move to opposite end position
	toggle: func {
		me.move(me.target);
	},
	# door.stop()          ->  stop movement
	stop: func {
		interpolate(me.anim_node);
		me.ctrl_timer.stop();
	},
	# door.move(double)    ->  move to arbitrary position
	move: func(target) {
		var pos = me.getpos();
		if( pos != target )
		{
			var time = abs(pos - target) * me.swingtime;
			interpolate(me.anim_node, target, time);
			me.ctrl_timer.restart(time);
		}
		else
		  # ensure ctrl node is in sync
		  me._updateCtrl();

		me.target = target < 0.5;
	},
	#
	_updateCtrl: func
	{
	  me.ctrl_node.setValue(me.getpos());
	},
};

################################################################################

var gearLever = Switch.new(
  "controls/gear/gear-down",
  "controls/gear/gear-down-position-norm",
  0.2,
  1
);

controls.gearDown = func(v)
{
  if( v < 0 and !getprop("gear/gear[1]/wow") )
    gearLever.move(0);
  elsif (v > 0)
    gearLever.move(1);
}
