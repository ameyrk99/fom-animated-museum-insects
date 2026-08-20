// Museum Insects Are Alive
// Nexus: https://www.nexusmods.com/profile/isuckatsdv/mods

#macro MIA_REST_FRAMES 45
#macro MIA_HOP_FRAMES  12
#macro MIA_SPEED       0.5

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

    // Both poses exist but neither animates: alternate them as a hop.
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

    return { mode: "static", sprite: _best.asset };
}

function museum_insects_are_alive_tick() {
    try {
        var _obj = museum_insects_are_alive_object();
        if (_obj == undefined) return;
        if (instance_number(_obj) <= 0) return;

        with (_obj) {
            var _mode = self[$ "__mia_mode"];

            if (_mode == "done") continue;

            if (_mode == "hop") {
                self.__mia_timer -= 1;
                if (self.__mia_timer <= 0) {
                    if (self.sprite_index == self.__mia_idle) {
                        self.sprite_index = self.__mia_move;
                        self.__mia_timer  = MIA_HOP_FRAMES;
                    } else {
                        self.sprite_index = self.__mia_idle;
                        self.__mia_timer  = MIA_REST_FRAMES;
                    }
                }
                continue;
            }

            var _plan = museum_insects_are_alive_plan(
                asset_to_string(self.sprite_index));

            if (_plan == undefined) {
                self.__mia_mode = "done";
                continue;
            }

            if (_plan.mode == "hop") {
                self.__mia_mode   = "hop";
                self.__mia_idle   = _plan.idle;
                self.__mia_move   = _plan.move;
                self.sprite_index = _plan.idle;
                self.image_speed  = 0;
                // stagger so they don't hop in unison
                self.__mia_timer  = 1 + ((self.x + self.y) mod MIA_REST_FRAMES);
                continue;
            }

            self.__mia_mode   = "done";
            self.sprite_index = _plan.sprite;
            self.image_speed  = MIA_SPEED;
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