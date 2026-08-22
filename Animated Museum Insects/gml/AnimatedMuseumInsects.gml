// Animated Museum Insects
// Nexus: https://www.nexusmods.com/profile/isuckatsdv/mods

#macro AMI_MOD_ID        "animated_museum_insects"
#macro AMI_VERSION       "1.2.0"

#macro AMI_SPEED                0.5

#macro AMI_DRIFT_LIMIT_X        5
#macro AMI_DRIFT_LIMIT_UP       2
#macro AMI_DRIFT_LIMIT_DOWN     3
#macro AMI_DRIFT_SPEED          0.12

#macro AMI_HOP_REST_FRAMES      45
#macro AMI_HOP_FRAMES           12

#macro AMI_PAUSE_MIN            30
#macro AMI_PAUSE_VAR            90
#macro AMI_LIMIT_EDGE           2

function __animated_museum_insects_runtime() {
    if (global[$ "__animated_museum_insects"] == undefined) {
        global.__animated_museum_insects = {
            registered_hooks: undefined,
            initialized:      false,
            object:           undefined,
            resolved:         false,
            seen:             {},
            rows:             {},
        };
    }
    return global.__animated_museum_insects;
}

function animated_museum_insects_log_seen(_key, _msg) {
    // Log if insect has been seen or not
    var _rt = __animated_museum_insects_runtime();
    if (_rt.seen[$ _key] != undefined) return;
    _rt.seen[$ _key] = true;
    mmapi_log_debug(AMI_MOD_ID, _msg);
}

function animated_museum_insects_get_museum_object() {
    var _rt = __animated_museum_insects_runtime();
    if (!_rt.resolved) {
        _rt.resolved = true;
        try {
            _rt.object = object_reserve("obj_museum_item");
        } catch (_e) {
            mmapi_log_warn(AMI_MOD_ID, "object_reserve threw: " + string(_e));
        }
    }
    return _rt.object;
}

function animated_museum_insects_get_asset(_bare, _suffix) {
    // Some insects don't have underscore in the sprite name
    var _names = [
        "spr_insect_" + _bare + _suffix,
        "spr_insect_" + string_replace_all(_bare, "_", "") + _suffix,
    ];

    for (var _i = 0; _i < array_length(_names); _i++) {
        var _asset = try_string_to_asset(_names[_i]);
        if (typeof(_asset) == "undefined") continue;

        var _frames = 1;
        try {
            _frames = sprite_get_number(_asset);
        } catch (_e) {
            _frames = 1;
        }

        return { asset: _asset, name: _names[_i], frames: _frames };
    }

    return undefined;
}

function animated_museum_insects_get_alias(_bare) {
    // Insects that don't conform to the naming pattern
    switch (_bare) {
        case "strobefirefly": return "strobe_dragonfly";
    }
    return undefined;
}

function animated_museum_insects_classify_anim(_name) {
    if (!is_string(_name)) return undefined;
    if (string_pos("spr_ui_item_insect_", _name) != 1) return undefined;

    var _bare = string_replace(_name, "spr_ui_item_insect_", "");
    var _alias = animated_museum_insects_get_alias(_bare);
    if (_alias != undefined) _bare = _alias;

    var _move = animated_museum_insects_get_asset(_bare, "_entity_move");
    var _idle = animated_museum_insects_get_asset(_bare, "_entity_idle");

    if (_move == undefined && _idle == undefined) {
        mmapi_log_warn(AMI_MOD_ID, "no entity sprite for: " + _name);
        return undefined;
    }

    if (_move != undefined && _idle != undefined
        && _move.frames <= 1 && _idle.frames <= 1) {
        animated_museum_insects_log_seen(_name, _name + " -> hop cycle");
        return { mode: "hop", idle: _idle.asset, move: _move.asset };
    }

    // Idle animations for some insects look better than the move ones.
    // Since insects aren't moving that much on the display, choose whichever has more sprite frames
    var _best = _move;
    if (_best == undefined) {
        _best = _idle;
    } else if (_idle != undefined && _idle.frames > _best.frames) {
        _best = _idle;
    }

    animated_museum_insects_log_seen(_name,
        _name + " -> " + _best.name + " (frames: " + string(_best.frames) + ")");

    return { mode: "anim", sprite: _best.asset };
}

function animated_museum_insects_scan_rows() {
    var _rt = __animated_museum_insects_runtime();
    var _obj = animated_museum_insects_get_museum_object();
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

function animated_museum_insects_get_rand_seed(_inst) {
    _inst.__ami_seed = ((_inst.__ami_seed * 75) + 74) mod 65537;
    return _inst.__ami_seed / 65537;
}

function animated_museum_insects_set_target(_inst) {
    var _rx = animated_museum_insects_get_rand_seed(_inst);
    var _ry = animated_museum_insects_get_rand_seed(_inst);

    _inst.__ami_target_x = -_inst.__ami_limit_lt
        + _rx * (_inst.__ami_limit_lt + _inst.__ami_limit_rt);
    _inst.__ami_target_y = -AMI_DRIFT_LIMIT_UP + _ry * (AMI_DRIFT_LIMIT_UP + AMI_DRIFT_LIMIT_DOWN);

    var _dx = _inst.__ami_target_x - _inst.__ami_offset_x;
    if (abs(_dx) > 0.75) {
        _inst.image_xscale = (_dx < 0) ? 1 : -1;
    }
}

function animated_museum_insects_set_placement(_inst) {
    _inst.x = _inst.__ami_base_x + round(_inst.__ami_offset_x);
    _inst.y = _inst.__ami_base_y + round(_inst.__ami_offset_y);
}

function animated_museum_insects_setup(_inst, _plan) {
    var _rt = __animated_museum_insects_runtime();
    var _row = _rt.rows[$ string(round(_inst.y))];

    _inst.__ami_base_x = _inst.x;
    _inst.__ami_base_y = _inst.y;
    _inst.__ami_offset_x = 0;
    _inst.__ami_offset_y = 0;
    _inst.__ami_seed = ((_inst.x * 37) + (_inst.y * 17) + 1) mod 65537;
    _inst.__ami_pause = 0;

    if (_row == undefined) {
        _inst.__ami_limit_lt = AMI_DRIFT_LIMIT_X;
        _inst.__ami_limit_rt = AMI_DRIFT_LIMIT_X;
    } else {
        _inst.__ami_limit_lt = min(AMI_DRIFT_LIMIT_X,
            (_inst.x - _row.lo) + AMI_LIMIT_EDGE);
        _inst.__ami_limit_rt = min(AMI_DRIFT_LIMIT_X,
            (_row.hi - _inst.x) + AMI_LIMIT_EDGE);
    }

    _inst.image_xscale = (((_inst.x + _inst.y) mod 2) == 0) ? 1 : -1;
    animated_museum_insects_set_target(_inst);

    if (_plan.mode == "hop") {
        _inst.__ami_anim_mode = "hop";
        _inst.__ami_sprite_idle = _plan.idle;
        _inst.__ami_sprite_move = _plan.move;
        _inst.sprite_index = _plan.idle;
        _inst.image_speed= 0;
        _inst.__ami_timer= 1 + ((_inst.x + _inst.y) mod AMI_HOP_REST_FRAMES);
    } else {
        _inst.__ami_anim_mode = "anim";
        _inst.sprite_index = _plan.sprite;
        _inst.image_speed = AMI_SPEED;
    }
}

function animated_museum_insects_move(_inst) {
    if (_inst.__ami_pause > 0) {
        _inst.__ami_pause -= 1;
        return;
    }

    var _dx = _inst.__ami_target_x - _inst.__ami_offset_x;
    var _dy = _inst.__ami_target_y - _inst.__ami_offset_y;
    var _d = sqrt(_dx * _dx + _dy * _dy);

    if (_d <= AMI_DRIFT_SPEED) {
        _inst.__ami_offset_x = _inst.__ami_target_x;
        _inst.__ami_offset_y = _inst.__ami_target_y;
        _inst.__ami_pause = AMI_PAUSE_MIN
            + floor(animated_museum_insects_get_rand_seed(_inst) * AMI_PAUSE_VAR);
        animated_museum_insects_set_target(_inst);
    } else {
        _inst.__ami_offset_x += AMI_DRIFT_SPEED * (_dx / _d);
        _inst.__ami_offset_y += AMI_DRIFT_SPEED * (_dy / _d);
    }

    animated_museum_insects_set_placement(_inst);
}

function animated_museum_insects_hop(_inst) {
    _inst.__ami_timer -= 1;
    if (_inst.__ami_timer > 0) return;

    if (_inst.sprite_index == _inst.__ami_sprite_idle) {
        _inst.sprite_index = _inst.__ami_sprite_move;
        _inst.__ami_timer = AMI_HOP_FRAMES;

        animated_museum_insects_set_target(_inst);
        _inst.__ami_offset_x = (_inst.__ami_offset_x + _inst.__ami_target_x) / 2;
        _inst.__ami_offset_y = (_inst.__ami_offset_y + _inst.__ami_target_y) / 2;
    } else {
        _inst.sprite_index = _inst.__ami_sprite_idle;
        _inst.__ami_timer = AMI_HOP_REST_FRAMES;

        _inst.__ami_offset_x = _inst.__ami_target_x;
        _inst.__ami_offset_y = _inst.__ami_target_y;
    }

    animated_museum_insects_set_placement(_inst);
}

function animated_museum_insects_tick() {
    try {
        var _rt = __animated_museum_insects_runtime();

        if (!_rt.initialized) {
            _rt.initialized = true;
            mmapi_log_info(AMI_MOD_ID,
                "Animated Museum Insects v" + AMI_VERSION + " initialized.");
            mmapi_log_flush(AMI_MOD_ID);
        }

        var _obj = animated_museum_insects_get_museum_object();
        if (_obj == undefined) return;
        if (instance_number(_obj) <= 0) return;

        var _fresh = false;
        with (_obj) {
            if (self[$ "__ami_anim_mode"] == undefined) _fresh = true;
        }

        if (_fresh) animated_museum_insects_scan_rows();

        with (_obj) {
            var _mode = self[$ "__ami_anim_mode"];

            if (_mode == undefined) {
                var _plan = animated_museum_insects_classify_anim(
                    asset_to_string(self.sprite_index));

                if (_plan == undefined) {
                    self.__ami_anim_mode = "skip";
                    continue;
                }
                
                animated_museum_insects_setup(self, _plan);
                continue;
            }

            if (_mode == "skip") continue;

            if (_mode == "hop") {
                animated_museum_insects_hop(self);
            } else {
                animated_museum_insects_move(self);
            }
        }
    } catch (_e) {
        mmapi_warn_rate_limited("animated_museum_insects.tick", AMI_MOD_ID,
            "tick failed: " + string(_e));
    }
}

function animated_museum_insects_register_callbacks() {
    var _rt = __animated_museum_insects_runtime();
    if (_rt.registered_hooks != undefined) return;
    _rt.registered_hooks = true;

    mmapi_register(animated_museum_insects_tick);
}

mmapi_mod_declare(AMI_MOD_ID, AMI_VERSION);
animated_museum_insects_register_callbacks();
