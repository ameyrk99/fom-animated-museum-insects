// Animated Museum Fish
// Nexus: https://www.nexusmods.com/profile/isuckatsdv/mods

#macro AMF_MOD_ID           "animated_museum_fish"
#macro AMF_VERSION          "1.1.0"
#macro AMF_CONFIG_VERSION   1

#macro AMF_TILT_DEADZONE    0.35
// Non-90 deg angles cause mush sprites because of how the game is rendered
#macro AMF_LEFT_DOWN_ANGLE  90
#macro AMF_EDGE_ALLOW       2

#macro AMF_SPEED_VAR        0.45
#macro AMF_LIMIT_VAR        0.30

#macro AMF_SWIM_LIMIT_X     5
#macro AMF_SWIM_LIMIT_UP    3
#macro AMF_SWIM_LIMIT_DOWN  1
#macro AMF_SWIM_SPEED       0.10
#macro AMF_SWIM_WAVE        0.50
#macro AMF_SWIM_Y_BIAS      0

#macro AMF_CRAB_LIMIT_X     5
#macro AMF_CRAB_LIMIT_UP    1
#macro AMF_CRAB_LIMIT_DOWN  1
#macro AMF_CRAB_SPEED       0.07
#macro AMF_CRAB_WAVE        0.30
#macro AMF_CRAB_Y_BIAS      1

#macro AMF_URCHIN_LIMIT_X   2
#macro AMF_URCHIN_LIMIT_UP  1
#macro AMF_URCHIN_LIMIT_DOWN 1
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
        magikarp: mmapi_config_bool(_source, "magikarp", false),

        __friendly_names: {
            face_down: "Tilt fish nose-down while descending",
            magikarp: "Magikarp mode (fish flop in place)",
        },
    };

    mmapi_config_write(AMF_MOD_ID, AMF_CONFIG_VERSION, _config);

    global.__animated_museum_fish_config = _config;
    return _config;
}

function animated_museum_fish_log_seen(_key, _msg) {
    // Log if fish has been seen or not
    var _rt = __animated_museum_fish_runtime();
    if (_rt.seen[$ _key] != undefined) return;
    _rt.seen[$ _key] = true;
    mmapi_log_debug(AMF_MOD_ID, _msg);
}

function animated_museum_fish_get_museum_object() {
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

function animated_museum_fish_classify_fish(_name) {
    // Classify items into 3 categories:
    //  1. Sea Urchin that moves very slowly and not too far
    //  2. Crabs that move mostly horizontally
    //  3. Swim (fish) that move in all dir, can face down, and can use Magikarp Mode

    if (!is_string(_name)) return undefined;

    if (string_pos("spr_ui_item_fish_", _name) != 1) return undefined;
    if (string_pos("spr_ui_item_fish_bait_", _name) == 1) return undefined;

    if (string_pos("sea_urchin", _name) > 0) {
        return {
            kind:       "urchin",
            tilt:       false,
            limit_x:    AMF_URCHIN_LIMIT_X,
            limit_up:   AMF_URCHIN_LIMIT_UP,
            limit_down: AMF_URCHIN_LIMIT_DOWN,
            speed:      AMF_URCHIN_SPEED,
            wave:       AMF_URCHIN_WAVE,
            y_bias:     AMF_URCHIN_Y_BIAS,
        };
    }

    if (string_pos("crab", _name) > 0) {
        return {
            kind:       "crab",
            tilt:       false,
            limit_x:    AMF_CRAB_LIMIT_X,
            limit_up:   AMF_CRAB_LIMIT_UP,
            limit_down: AMF_CRAB_LIMIT_DOWN,
            speed:      AMF_CRAB_SPEED,
            wave:       AMF_CRAB_WAVE,
            y_bias:     AMF_CRAB_Y_BIAS,
        };
    }

    return {
        kind:       "swim",
        tilt:       true,
        limit_x:    AMF_SWIM_LIMIT_X,
        limit_up:   AMF_SWIM_LIMIT_UP,
        limit_down: AMF_SWIM_LIMIT_DOWN,
        speed:      AMF_SWIM_SPEED,
        wave:       AMF_SWIM_WAVE,
        y_bias:     AMF_SWIM_Y_BIAS,
    };
}

function animated_museum_fish_scan_museum_rows() {
    var _rt = __animated_museum_fish_runtime();
    var _obj = animated_museum_fish_get_museum_object();
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

function animated_museum_fish_get_rand_seed(_inst) {
    _inst.__amf_seed = ((_inst.__amf_seed * 75) + 74) mod 65537;
    return _inst.__amf_seed / 65537;
}

function animated_museum_fish_get_fish_jitter(_inst, _var) {
    return 1 + (animated_museum_fish_get_rand_seed(_inst) * 2 - 1) * _var;
}

function animated_museum_fish_set_orientation(_inst, _dx, _dy) {
    // Set which direction fish are facing (right up, left down, etc)

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
        _inst.image_angle = _inst.__amf_down ? -90 : 0;
    } else {
        _inst.image_xscale = -1;
        _inst.image_angle = _inst.__amf_down ? AMF_LEFT_DOWN_ANGLE : 0;
    }
}

function animated_museum_fish_get_vertical_mov(_inst) {
    // Use sine func to determine vertical movement

    var _s = sin(_inst.__amf_offset_x * _inst.__amf_wave + _inst.__amf_phase);

    return (_s < 0)
        ? _s * _inst.__amf_limit_up
        : _s * _inst.__amf_limit_down;
}

function animated_museum_fish_set_placement(_inst) {
    _inst.x = _inst.__amf_base_x + round(_inst.__amf_offset_x);
    _inst.y = _inst.__amf_base_y + round(_inst.__amf_offset_y);
}

function animated_museum_fish_animate_flop(_inst) {
    _inst.image_yscale = -1;
    _inst.image_xscale = _inst.__amf_flop_x;
    _inst.image_angle = _inst.__amf_flop_up ? _inst.__amf_flop_angle : 0;
}

function animated_museum_fish_setup_flop(_inst) {
    var _left = (_inst.__amf_dir < 0);

    // Initially, fish sprites look roughly towards right-up direction
    // For magikarp flopping, they should be one of 4 things:
    //  If facing right:
    //      - Flipped horizontally then rot 90 deg (right up)
    //      - Flipped horizontally (right down)
    //  If facing left:
    //      - Flipped horizontally then vertically then rot -90 deg (left up)
    //      - Flipped horizontally then vertically (left down)
    // This is so that upper part of the fish is always facing downwards
    _inst.__amf_flop_x = _left ? -1 :  1;
    _inst.__amf_flop_angle = _left ? -90 : 90;
    _inst.__amf_flop_up = false;
    _inst.__amf_flop_remaining = AMF_MAGIKARP_MIN
        + floor(animated_museum_fish_get_rand_seed(_inst) * AMF_MAGIKARP_EXTRA);
    _inst.__amf_flop_timer = 1
        + floor(animated_museum_fish_get_rand_seed(_inst) * AMF_MAGIKARP_PAUSE);

    _inst.__amf_offset_x = 0;
    _inst.__amf_offset_y = 0;
    _inst.__amf_anim_mode = "flop";

    animated_museum_fish_animate_flop(_inst);
    animated_museum_fish_set_placement(_inst);
}

function animated_museum_fish_flop(_inst) {
    _inst.__amf_flop_timer -= 1;
    if (_inst.__amf_flop_timer > 0) return;

    if (_inst.__amf_flop_remaining > 0) {
        _inst.__amf_flop_remaining -= 1;
        _inst.__amf_flop_up = !_inst.__amf_flop_up;
        animated_museum_fish_animate_flop(_inst);
        _inst.__amf_flop_timer = AMF_MAGIKARP_STEP;
        return;
    }

    if (_inst.__amf_flop_up) {
        _inst.__amf_flop_up = false;
        animated_museum_fish_animate_flop(_inst);
        _inst.__amf_flop_timer = AMF_MAGIKARP_STEP;
        return;
    }

    _inst.__amf_flop_remaining = AMF_MAGIKARP_MIN
        + floor(animated_museum_fish_get_rand_seed(_inst) * AMF_MAGIKARP_EXTRA);
    _inst.__amf_flop_timer = AMF_MAGIKARP_PAUSE;
}

function animated_museum_fish_setup(_inst, _class) {
    var _rt = __animated_museum_fish_runtime();
    var _row = _rt.rows[$ string(round(_inst.y))];

    _inst.__amf_base_x = _inst.x;
    _inst.__amf_base_y = _inst.y + _class.y_bias;
    _inst.__amf_offset_x = 0;
    _inst.__amf_seed = ((_inst.x * 37) + (_inst.y * 17) + 1) mod 65537;

    _inst.__amf_speed = _class.speed
        * animated_museum_fish_get_fish_jitter(_inst, AMF_SPEED_VAR);

    var _rx = max(1, _class.limit_x
        * animated_museum_fish_get_fish_jitter(_inst, AMF_LIMIT_VAR));

    if (_row == undefined) {
        _inst.__amf_limit_lt = _rx;
        _inst.__amf_limit_rt = _rx;
    } else {
        _inst.__amf_limit_lt = min(_rx, (_inst.x - _row.lo) + AMF_EDGE_ALLOW);
        _inst.__amf_limit_rt = min(_rx, (_row.hi - _inst.x) + AMF_EDGE_ALLOW);
    }

    _inst.__amf_limit_up = _class.limit_up
        * animated_museum_fish_get_fish_jitter(_inst, AMF_LIMIT_VAR);

    _inst.__amf_limit_down = _class.limit_down
        * animated_museum_fish_get_fish_jitter(_inst, AMF_LIMIT_VAR);

    _inst.__amf_wave = _class.wave
        * animated_museum_fish_get_fish_jitter(_inst, AMF_LIMIT_VAR);

    _inst.__amf_dir = (animated_museum_fish_get_rand_seed(_inst) < 0.5) ? -1 : 1;
    _inst.__amf_phase = animated_museum_fish_get_rand_seed(_inst) * 2 * pi;
    _inst.__amf_tilt = _class.tilt;
    _inst.__amf_down = false;

    _inst.image_speed = 0;
    _inst.image_xscale = 1;
    _inst.image_yscale = 1;
    _inst.image_angle = 0;

    if (_rt.magikarp && _class.tilt) {
        animated_museum_fish_setup_flop(_inst);
        return;
    }

    _inst.__amf_offset_y = animated_museum_fish_get_vertical_mov(_inst);

    animated_museum_fish_set_orientation(_inst, _inst.__amf_dir, 0);

    _inst.__amf_anim_mode = _class.kind;
    animated_museum_fish_set_placement(_inst);
}

function animated_museum_fish_move(_inst) {
    var _prev_offset_y = _inst.__amf_offset_y;

    _inst.__amf_offset_x += _inst.__amf_speed * _inst.__amf_dir;

    if (_inst.__amf_offset_x > _inst.__amf_limit_rt) {
        _inst.__amf_offset_x = _inst.__amf_limit_rt;
        _inst.__amf_dir = -1;
    } else if (_inst.__amf_offset_x < -_inst.__amf_limit_lt) {
        _inst.__amf_offset_x = -_inst.__amf_limit_lt;
        _inst.__amf_dir = 1;
    }

    _inst.__amf_offset_y = animated_museum_fish_get_vertical_mov(_inst);

    var _dx = _inst.__amf_speed * _inst.__amf_dir;
    var _dy = _inst.__amf_offset_y - _prev_offset_y;

    animated_museum_fish_set_orientation(_inst, _dx, _dy);
    animated_museum_fish_set_placement(_inst);
}

function animated_museum_fish_tick() {
    try {
        var _rt = __animated_museum_fish_runtime();

        if (!_rt.initialized) {
            _rt.initialized = true;

            var _config = animated_museum_fish_config();
            _rt.face_down = _config.face_down;
            _rt.magikarp = _config.magikarp;

            mmapi_log_info(AMF_MOD_ID,
                "Animated Museum Fish v" + AMF_VERSION + " initialized.");
            mmapi_log_flush(AMF_MOD_ID);
        }

        var _obj = animated_museum_fish_get_museum_object();
        if (_obj == undefined) return;
        if (instance_number(_obj) <= 0) return;

        var _fresh = false;
        with (_obj) {
            if (self[$ "__amf_anim_mode"] == undefined) _fresh = true;
        }

        if (_fresh) animated_museum_fish_scan_museum_rows();

        with (_obj) {
            var _mode = self[$ "__amf_anim_mode"];

            if (_mode == undefined) {
                var _name = asset_to_string(self.sprite_index);
                var _class = animated_museum_fish_classify_fish(_name);

                if (_class == undefined) {
                    self.__amf_anim_mode = "skip";
                    continue;
                }

                animated_museum_fish_log_seen(_name, _name + " -> " + _class.kind);
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
