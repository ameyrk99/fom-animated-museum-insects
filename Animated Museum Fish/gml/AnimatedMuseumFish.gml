// Animated Museum Fish
// Nexus: https://www.nexusmods.com/profile/isuckatsdv/mods

#macro AMF_MOD_ID           "animated_museum_fish"
#macro AMF_VERSION          "1.1.0"
#macro AMF_CONFIG_VERSION   1

#macro AMF_TILT_DEADZONE    0.35
#macro AMF_LEFT_DOWN_ANGLE  90
#macro AMF_EDGE_ALLOW       2

#macro AMF_SPEED_VAR        0.45
#macro AMF_RANGE_VAR        0.30

#macro AMF_SWIM_RANGE_X     5
#macro AMF_SWIM_RANGE_UP    3
#macro AMF_SWIM_RANGE_DOWN  1
#macro AMF_SWIM_SPEED       0.10
#macro AMF_SWIM_WAVE        0.50
#macro AMF_SWIM_Y_BIAS      0

#macro AMF_CRAB_RANGE_X     5
#macro AMF_CRAB_RANGE_UP    1
#macro AMF_CRAB_RANGE_DOWN  1
#macro AMF_CRAB_SPEED       0.07
#macro AMF_CRAB_WAVE        0.30
#macro AMF_CRAB_Y_BIAS      1

#macro AMF_URCHIN_RANGE_X   2
#macro AMF_URCHIN_RANGE_UP  1
#macro AMF_URCHIN_RANGE_DOWN 1
#macro AMF_URCHIN_SPEED     0.005
#macro AMF_URCHIN_WAVE      0.80
#macro AMF_URCHIN_Y_BIAS    1

#macro AMF_MAGIKARP_STEP    12
#macro AMF_MAGIKARP_PAUSE   120
#macro AMF_MAGIKARP_MIN     3
#macro AMF_MAGIKARP_EXTRA   2

function __animated_museum_fish_runtime() {
    if (global[$ "__animated_museum_fish"] == undefined) {
        global.__animated_museum_fish = {
            registered_hooks: undefined,
            initialized:      false,
            face_down:        false,
            magikarp:         false,
            object:           undefined,
            resolved:         false,
            seen:             {},
            rows:             {},
        };
    }
    return global.__animated_museum_fish;
}

function animated_museum_fish_config() {
    if (global[$ "__animated_museum_fish_config"] != undefined) {
        return global.__animated_museum_fish_config;
    }

    var _source = mmapi_config_read_valid(AMF_MOD_ID, AMF_CONFIG_VERSION);

    var _config = {
        face_down: mmapi_config_bool(_source, "face_down", false),
        magikarp:  mmapi_config_bool(_source, "magikarp",  false),

        __friendly_names: {
            face_down: "Tilt fish nose-down while descending",
            magikarp:  "Magikarp mode: fish flop in place",
        },
    };

    mmapi_config_write(AMF_MOD_ID, AMF_CONFIG_VERSION, _config);

    global.__animated_museum_fish_config = _config;
    return _config;
}

function animated_museum_fish_log_once(_key, _msg) {
    var _rt = __animated_museum_fish_runtime();
    if (_rt.seen[$ _key] != undefined) return;
    _rt.seen[$ _key] = true;
    mmapi_log_debug(AMF_MOD_ID, _msg);
}

function animated_museum_fish_object() {
    var _rt = __animated_museum_fish_runtime();
    if (!_rt.resolved) {
        _rt.resolved = true;
        try {
            _rt.object = object_reserve("obj_museum_item");
        } catch (_e) {
            mmapi_log_warn(AMF_MOD_ID, "object_reserve threw: " + string(_e));
        }
    }
    return _rt.object;
}

function animated_museum_fish_classify(_name) {
    if (!is_string(_name)) return undefined;

    if (string_pos("spr_ui_item_fish_", _name) != 1) return undefined;
    if (string_pos("spr_ui_item_fish_bait_", _name) == 1) return undefined;

    if (string_pos("sea_urchin", _name) > 0) {
        return {
            kind:       "urchin",
            tilt:       false,
            range_x:    AMF_URCHIN_RANGE_X,
            range_up:   AMF_URCHIN_RANGE_UP,
            range_down: AMF_URCHIN_RANGE_DOWN,
            speed:      AMF_URCHIN_SPEED,
            wave:       AMF_URCHIN_WAVE,
            y_bias:     AMF_URCHIN_Y_BIAS,
        };
    }

    if (string_pos("crab", _name) > 0) {
        return {
            kind:       "crab",
            tilt:       false,
            range_x:    AMF_CRAB_RANGE_X,
            range_up:   AMF_CRAB_RANGE_UP,
            range_down: AMF_CRAB_RANGE_DOWN,
            speed:      AMF_CRAB_SPEED,
            wave:       AMF_CRAB_WAVE,
            y_bias:     AMF_CRAB_Y_BIAS,
        };
    }

    return {
        kind:       "swim",
        tilt:       true,
        range_x:    AMF_SWIM_RANGE_X,
        range_up:   AMF_SWIM_RANGE_UP,
        range_down: AMF_SWIM_RANGE_DOWN,
        speed:      AMF_SWIM_SPEED,
        wave:       AMF_SWIM_WAVE,
        y_bias:     AMF_SWIM_Y_BIAS,
    };
}

function animated_museum_fish_scan_rows() {
    var _rt   = __animated_museum_fish_runtime();
    var _obj  = animated_museum_fish_object();
    var _rows = {};

    with (_obj) {
        var _key = string(round(self.y));
        var _row = _rows[$ _key];

        if (_row == undefined) {
            _rows[$ _key] = { lo: self.x, hi: self.x };
        } else {
            if (self.x < _row.lo) _row.lo = self.x;
            if (self.x > _row.hi) _row.hi = self.x;
        }
    }

    _rt.rows = _rows;
}

function animated_museum_fish_rand(_inst) {
    _inst.__amf_seed = ((_inst.__amf_seed * 75) + 74) mod 65537;
    return _inst.__amf_seed / 65537;
}

function animated_museum_fish_jitter(_inst, _var) {
    return 1 + (animated_museum_fish_rand(_inst) * 2 - 1) * _var;
}

function animated_museum_fish_orient(_inst, _dx, _dy) {
    if (!_inst.__amf_tilt) {
        _inst.image_xscale = _inst.__amf_dir;
        return;
    }

    var _rt = __animated_museum_fish_runtime();

    if (_rt.face_down && abs(_dy) > abs(_dx) * AMF_TILT_DEADZONE) {
        _inst.__amf_down = (_dy > 0);
    }

    if (_dx >= 0) {
        _inst.image_xscale = 1;
        _inst.image_angle  = _inst.__amf_down ? -90 : 0;
    } else {
        _inst.image_xscale = -1;
        _inst.image_angle  = _inst.__amf_down ? AMF_LEFT_DOWN_ANGLE : 0;
    }
}

function animated_museum_fish_vertical(_inst) {
    var _s = sin(_inst.__amf_ox * _inst.__amf_wave + _inst.__amf_phase);

    return (_s < 0)
        ? _s * _inst.__amf_range_up
        : _s * _inst.__amf_range_down;
}

function animated_museum_fish_place(_inst) {
    _inst.x = _inst.__amf_bx + round(_inst.__amf_ox);
    _inst.y = _inst.__amf_by + round(_inst.__amf_oy);
}

function animated_museum_fish_flop_apply(_inst) {
    _inst.image_yscale = -1;
    _inst.image_xscale = _inst.__amf_flop_x;
    _inst.image_angle  = _inst.__amf_flop_up ? _inst.__amf_flop_angle : 0;
}

function animated_museum_fish_flop_setup(_inst) {
    var _left = (_inst.__amf_dir < 0);

    _inst.__amf_flop_x     = _left ? -1 :  1;
    _inst.__amf_flop_angle = _left ? -90 : 90;
    _inst.__amf_flop_up    = false;
    _inst.__amf_flop_left  = AMF_MAGIKARP_MIN
        + floor(animated_museum_fish_rand(_inst) * AMF_MAGIKARP_EXTRA);
    _inst.__amf_flop_timer = 1
        + floor(animated_museum_fish_rand(_inst) * AMF_MAGIKARP_PAUSE);

    _inst.__amf_ox = 0;
    _inst.__amf_oy = 0;
    _inst.__amf_mode = "flop";

    animated_museum_fish_flop_apply(_inst);
    animated_museum_fish_place(_inst);
}

function animated_museum_fish_flop(_inst) {
    _inst.__amf_flop_timer -= 1;
    if (_inst.__amf_flop_timer > 0) return;

    if (_inst.__amf_flop_left > 0) {
        _inst.__amf_flop_left -= 1;
        _inst.__amf_flop_up = !_inst.__amf_flop_up;
        animated_museum_fish_flop_apply(_inst);
        _inst.__amf_flop_timer = AMF_MAGIKARP_STEP;
        return;
    }

    if (_inst.__amf_flop_up) {
        _inst.__amf_flop_up = false;
        animated_museum_fish_flop_apply(_inst);
        _inst.__amf_flop_timer = AMF_MAGIKARP_STEP;
        return;
    }

    _inst.__amf_flop_left = AMF_MAGIKARP_MIN
        + floor(animated_museum_fish_rand(_inst) * AMF_MAGIKARP_EXTRA);
    _inst.__amf_flop_timer = AMF_MAGIKARP_PAUSE;
}

function animated_museum_fish_setup(_inst, _class) {
    var _rt  = __animated_museum_fish_runtime();
    var _row = _rt.rows[$ string(round(_inst.y))];

    _inst.__amf_bx   = _inst.x;
    _inst.__amf_by   = _inst.y + _class.y_bias;
    _inst.__amf_ox   = 0;
    _inst.__amf_seed = ((_inst.x * 37) + (_inst.y * 17) + 1) mod 65537;

    _inst.__amf_speed = _class.speed
        * animated_museum_fish_jitter(_inst, AMF_SPEED_VAR);

    var _rx = max(1, _class.range_x
        * animated_museum_fish_jitter(_inst, AMF_RANGE_VAR));

    if (_row == undefined) {
        _inst.__amf_range_left  = _rx;
        _inst.__amf_range_right = _rx;
    } else {
        _inst.__amf_range_left  = min(_rx, (_inst.x - _row.lo) + AMF_EDGE_ALLOW);
        _inst.__amf_range_right = min(_rx, (_row.hi - _inst.x) + AMF_EDGE_ALLOW);
    }

    _inst.__amf_range_up = _class.range_up
        * animated_museum_fish_jitter(_inst, AMF_RANGE_VAR);

    _inst.__amf_range_down = _class.range_down
        * animated_museum_fish_jitter(_inst, AMF_RANGE_VAR);

    _inst.__amf_wave = _class.wave
        * animated_museum_fish_jitter(_inst, AMF_RANGE_VAR);

    _inst.__amf_dir   = (animated_museum_fish_rand(_inst) < 0.5) ? -1 : 1;
    _inst.__amf_phase = animated_museum_fish_rand(_inst) * 2 * pi;
    _inst.__amf_tilt  = _class.tilt;
    _inst.__amf_down  = false;

    _inst.image_speed  = 0;
    _inst.image_xscale = 1;
    _inst.image_yscale = 1;
    _inst.image_angle  = 0;

    if (_rt.magikarp && _class.tilt) {
        animated_museum_fish_flop_setup(_inst);
        return;
    }

    _inst.__amf_oy = animated_museum_fish_vertical(_inst);

    animated_museum_fish_orient(_inst, _inst.__amf_dir, 0);

    _inst.__amf_mode = _class.kind;
    animated_museum_fish_place(_inst);
}

function animated_museum_fish_move(_inst) {
    var _prev_oy = _inst.__amf_oy;

    _inst.__amf_ox += _inst.__amf_speed * _inst.__amf_dir;

    if (_inst.__amf_ox > _inst.__amf_range_right) {
        _inst.__amf_ox  = _inst.__amf_range_right;
        _inst.__amf_dir = -1;
    } else if (_inst.__amf_ox < -_inst.__amf_range_left) {
        _inst.__amf_ox  = -_inst.__amf_range_left;
        _inst.__amf_dir = 1;
    }

    _inst.__amf_oy = animated_museum_fish_vertical(_inst);

    var _dx = _inst.__amf_speed * _inst.__amf_dir;
    var _dy = _inst.__amf_oy - _prev_oy;

    animated_museum_fish_orient(_inst, _dx, _dy);
    animated_museum_fish_place(_inst);
}

function animated_museum_fish_tick() {
    try {
        var _rt = __animated_museum_fish_runtime();

        if (!_rt.initialized) {
            _rt.initialized = true;

            var _config = animated_museum_fish_config();
            _rt.face_down = _config.face_down;
            _rt.magikarp  = _config.magikarp;

            mmapi_log_info(AMF_MOD_ID,
                "Animated Museum Fish v" + AMF_VERSION + " initialized.");
            mmapi_log_flush(AMF_MOD_ID);
        }

        var _obj = animated_museum_fish_object();
        if (_obj == undefined) return;
        if (instance_number(_obj) <= 0) return;

        var _fresh = false;
        with (_obj) {
            if (self[$ "__amf_mode"] == undefined) _fresh = true;
        }

        if (_fresh) animated_museum_fish_scan_rows();

        with (_obj) {
            var _mode = self[$ "__amf_mode"];

            if (_mode == undefined) {
                var _name  = asset_to_string(self.sprite_index);
                var _class = animated_museum_fish_classify(_name);

                if (_class == undefined) {
                    self.__amf_mode = "skip";
                    continue;
                }

                animated_museum_fish_log_once(_name, _name + " -> " + _class.kind);
                animated_museum_fish_setup(self, _class);
                continue;
            }

            if (_mode == "skip") continue;

            if (_mode == "flop") {
                animated_museum_fish_flop(self);
            } else {
                animated_museum_fish_move(self);
            }
        }
    } catch (_e) {
        mmapi_warn_rate_limited("animated_museum_fish.tick", AMF_MOD_ID,
            "tick failed: " + string(_e));
    }
}

function animated_museum_fish_register_callbacks() {
    var _rt = __animated_museum_fish_runtime();
    if (_rt.registered_hooks != undefined) return;
    _rt.registered_hooks = true;

    mmapi_register(animated_museum_fish_tick);
}

mmapi_mod_declare(AMF_MOD_ID, AMF_VERSION);
animated_museum_fish_register_callbacks();