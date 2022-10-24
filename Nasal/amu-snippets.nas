'title': "PFD",
          'l1': [[ ["PILOT", func(t,v) { setStyle(t, v == 1) }],
                    " / ",
                   ["COPILOT", func(t,v) { setStyle(t, v != 1) }]
                 ],
                'property-cycle', {property: '/instrumentation/pfd[0]/is_pilot', value: [0, 1]}
                ],
          'l2': [[  "BARO ",
                   ["IN", func(t,v) { setStyle(t, v == 'in') }],
                    " / ",
                   ["MB", func(t,v) { setStyle(t, v == 'mb') }],
                 ],
                 'property-cycle', {property: '/instrumentation/pfd[0]/baro_unit', value: ['in', 'mb']}
                ],
          'l3': [["MAG"," / ","TRUE"," / ","GRID"]],
          'l4': [["FD SOURCE ","P"," / ","CP"]],
          'r1': [["ATT REF IMU ","1"," / ","2"]],
          'r2': [["CADC ","1"," / ","2"]],
          'r3': propertyCycle('/instrumentation/pfd[0]/rad_alt_src', [1, 2], ["RAD ALT ", ["1", 1], " / ", ["2", 2]]),
          'r4': ["MAIN MENU>", {'page': 'main-menu'}]
