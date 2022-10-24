togglereverser = func(num_engines = 2) {
  debug.warn("No reverse thrust for turboprops implemented!");
  return;
  var propulsion = props.globals.getNode("/fdm/jsbsim/propulsion");
  var controls_engine = props.globals.getNode("/controls/engines");

  var engines_rev = setsize([], num_engines);
  var controls_rev = setsize([], num_engines);

  for(var i = 0; i < num_engines; i += 1)
  {
    engines_rev[i] = propulsion.getNode("engine[" ~ i ~ "]/reverser-angle-rad");
    controls_rev[i] = controls_engine.getNode("engine[" ~ i ~ "]/reverser");
  }

  var val = getprop("/engines/engine[0]/reverser-pos-norm");
  if( val == 0 or val == nil )
  {
    for(var i = 0; i < num_engines; i += 1)
    {
      engines_rev[i].setValue(math.pi);
      controls_rev[i].setBoolValue(1);
      interpolate("/engines/engine[" ~ i ~ "]/reverser-pos-norm", 1.0, 1.4);
    }
  }
  else if (val == 1.0)
  {
    for(var i = 0; i < num_engines; i += 1)
    {
      engines_rev[i].setValue(0);
      controls_rev[i].setBoolValue(0);
      interpolate("/engines/engine[" ~ i ~ "]/reverser-pos-norm", 0.0, 1.4);
    }
  }
}

