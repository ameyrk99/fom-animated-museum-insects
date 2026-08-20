// Museum Insects Are Alive
// Nexus: https://www.nexusmods.com/profile/isuckatsdv/mods

#macro MIAA_REST_FRAMES   45
#macro MIAA_HOP_FRAMES    12
#macro MIAA_SPEED         0.5

#macro MIAA_DRIFT_X       4
#macro MIAA_DRIFT_UP      2
#macro MIAA_DRIFT_DOWN    1
#macro MIAA_DRIFT_SPEED   0.12
#macro MIAA_PAUSE_MIN     30
#macro MIAA_PAUSE_VAR     90

function __museum_insects_are_alive_runtime() {
    if (global[$ "__museum_insects_are_alive"] == undefined) {
        global.__museum_insects_are_alive = {
            registered_hooks: undefined,
            object:           undefined,
            resolved:         false,
            seen:             {},
        };
    }
    return global.__museum_insects_are_alive;
}

function museum_insects_are_alive_say_once(_key, _msg) {
    var _rt = __museum_insects_are_alive_runtime();
    if (_rt.seen[$ _key] != undefined) return;
    _rt.seen[$ _key] = true;
    mmapi_log_info("museum_insects_are_alive", _msg);
    mmapi_log_flush("museum_insects_are_alive");
}

function museum_insects_are_alive_object() {
    var _rt = __museum_insects_are_alive_runtime();
    if (!_rt.resolved) {
        _rt.resolved = true;
        try {
            _rt.object = object_reserve("obj_museum_item");
        } catch (_e) {
            mmapi_log_warn("museum_insects_are_alive",
                "object_reserve threw: " + string(_e));
        }
    }
    return _rt.object;
}

function museum_insects_are_alive_candidate(_bare, _suffix) {
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

function museum_insects_are_alive_plan(_name) {
    if (!is_string(_name)) return undefined;
    if (string_pos("spr_ui_item_insect_", _name) != 1) return undefined;

    var _bare = string_replace(_name, "spr_ui_item_insect_", "");

    var _move = museum_insects_are_alive_candidate(_bare, "_entity_move");
    var _idle = museum_insects_are_alive_candidate(_bare, "_entity_idle");

    if (_move == undefined && _idle == undefined) {
        museum_insects_are_alive_say_once(_name, "no match for: " + _name);
        return undefined;
    }

    if (_move != undefined && _idle != undefined
        && _move.frames <= 1 && _idle.frames <= 1) {
        museum_insects_are_alive_say_once(_name, _name + " -> hop cycle");
        return { mode: "hop", idle: _idle.asset, move: _move.asset };
    }

    var _best = _move;
    if (_best == undefined) {
        _best = _idle;
    } else if (_idle != undefined && _idle.frames > _best.frames) {
        _best = _idle;
    }

    museum_insects_are_alive_say_once(_name,
        _name + " -> " + _best.name + " (frames: " + string(_best.frames) + ")");

    return { mode: "anim", sprite: _best.asset };
}

function museum_insects_are_alive_rand(_inst) {
    _inst.__miaa_seed = ((_inst.__miaa_seed * 75) + 74) mod 65537;
    return _inst.__miaa_seed / 65537;
}

function museum_insects_are_alive_pick_target(_inst) {
    var _rx = museum_insects_are_alive_rand(_inst);
    var _ry = museum_insects_are_alive_rand(_inst);

    _inst.__miaa_tx = -MIAA_DRIFT_X + _rx * (MIAA_DRIFT_X * 2);
    _inst.__miaa_ty = -MIAA_DRIFT_UP + _ry * (MIAA_DRIFT_UP + MIAA_DRIFT_DOWN);

    var _dx = _inst.__miaa_tx - _inst.__miaa_ox;
    if (abs(_dx) > 0.75) {
        _inst.image_xscale = (_dx < 0) ? -1 : 1;
    }
}

function museum_insects_are_alive_place(_inst) {
    _inst.x = _inst.__miaa_bx + round(_inst.__miaa_ox);
    _inst.y = _inst.__miaa_by + round(_inst.__miaa_oy);
}

function museum_insects_are_alive_setup(_inst, _plan) {
    _inst.__miaa_bx   = _inst.x;
    _inst.__miaa_by   = _inst.y;
    _inst.__miaa_ox   = 0;
    _inst.__miaa_oy   = 0;
    _inst.__miaa_seed = ((_inst.x * 37) + (_inst.y * 17) + 1) mod 65537;
    _inst.__miaa_pause = 0;

    _inst.image_xscale = (((_inst.x + _inst.y) mod 2) == 0) ? 1 : -1;
    museum_insects_are_alive_pick_target(_inst);

    if (_plan.mode == "hop") {
        _inst.__miaa_mode   = "hop";
        _inst.__miaa_idle   = _plan.idle;
        _inst.__miaa_move   = _plan.move;
        _inst.sprite_index = _plan.idle;
        _inst.image_speed  = 0;
        _inst.__miaa_timer  = 1 + ((_inst.x + _inst.y) mod MIAA_REST_FRAMES);
        return;
    }

    _inst.__miaa_mode   = "anim";
    _inst.sprite_index = _plan.sprite;
    _inst.image_speed  = MIAA_SPEED;
}

function museum_insects_are_alive_drift(_inst) {
    if (_inst.__miaa_pause > 0) {
        _inst.__miaa_pause -= 1;
        return;
    }

    var _dx = _inst.__miaa_tx - _inst.__miaa_ox;
    var _dy = _inst.__miaa_ty - _inst.__miaa_oy;
    var _d  = sqrt(_dx * _dx + _dy * _dy);

    if (_d <= MIAA_DRIFT_SPEED) {
        _inst.__miaa_ox = _inst.__miaa_tx;
        _inst.__miaa_oy = _inst.__miaa_ty;
        _inst.__miaa_pause = MIAA_PAUSE_MIN
            + floor(museum_insects_are_alive_rand(_inst) * MIAA_PAUSE_VAR);
        museum_insects_are_alive_pick_target(_inst);
    } else {
        _inst.__miaa_ox += MIAA_DRIFT_SPEED * (_dx / _d);
        _inst.__miaa_oy += MIAA_DRIFT_SPEED * (_dy / _d);
    }

    museum_insects_are_alive_place(_inst);
}

function museum_insects_are_alive_hop(_inst) {
    _inst.__miaa_timer -= 1;
    if (_inst.__miaa_timer > 0) return;

    if (_inst.sprite_index == _inst.__miaa_idle) {
        _inst.sprite_index = _inst.__miaa_move;
        _inst.__miaa_timer  = MIAA_HOP_FRAMES;

        museum_insects_are_alive_pick_target(_inst);
        _inst.__miaa_ox = (_inst.__miaa_ox + _inst.__miaa_tx) / 2;
        _inst.__miaa_oy = (_inst.__miaa_oy + _inst.__miaa_ty) / 2;
    } else {
        _inst.sprite_index = _inst.__miaa_idle;
        _inst.__miaa_timer  = MIAA_REST_FRAMES;

        _inst.__miaa_ox = _inst.__miaa_tx;
        _inst.__miaa_oy = _inst.__miaa_ty;
    }

    museum_insects_are_alive_place(_inst);
}

function museum_insects_are_alive_tick() {
    try {
        var _obj = museum_insects_are_alive_object();
        if (_obj == undefined) return;
        if (instance_number(_obj) <= 0) return;

        with (_obj) {
            var _mode = self[$ "__miaa_mode"];

            if (_mode == undefined) {
                var _plan = museum_insects_are_alive_plan(
                    asset_to_string(self.sprite_index));

                if (_plan == undefined) {
                    self.__miaa_mode = "skip";
                    continue;
                }

                museum_insects_are_alive_setup(self, _plan);
                continue;
            }

            if (_mode == "skip") continue;

            if (_mode == "hop") {
                museum_insects_are_alive_hop(self);
            } else {
                museum_insects_are_alive_drift(self);
            }
        }
    } catch (_e) {
        mmapi_warn_rate_limited("museum_insects_are_alive.tick",
            "museum_insects_are_alive", "tick failed: " + string(_e));
    }
}

function museum_insects_are_alive_register_callbacks() {
    var _rt = __museum_insects_are_alive_runtime();
    if (_rt.registered_hooks != undefined) return;
    _rt.registered_hooks = true;

    mmapi_register(museum_insects_are_alive_tick);
    mmapi_log_info("museum_insects_are_alive", "registered");
}

mmapi_mod_declare("museum_insects_are_alive", "1.0.0");
museum_insects_are_alive_register_callbacks();