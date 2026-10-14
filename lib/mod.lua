-- nb_synthy 0.1.2 — Synthy as a Nota Bene voice. Original synthesis: Zack Scholl (MIT).
local mods = require 'core/mods'
local controlspec = require 'controlspec'
local GROUP = 'nb_synthy_group'
local PREFIX = 'nb_synthy_'
local current

local controls = {
  {'level', 'level', 0, 2, 'lin', 0, 1, ''},
  {'sub', 'sub', 0, 3, 'lin', 0, 1, ''},
  {'attack', 'attack', 0.01, 30, 'exp', 0, 1, 's'},
  {'decay', 'decay', 0, 30, 'lin', 0, 0.1, 's'},
  {'sustain', 'sustain', 0, 1, 'lin', 0, 0.9, ''},
  {'release', 'release', 0, 30, 'lin', 0, 5, 's'},
  {'portamento', 'pitch slew', 0, 10, 'lin', 0, 1, 's'},
  {'lpf', 'filter cutoff', 20, 20000, 'exp', 0, 6000, 'Hz'},
  {'hold_control', 'filter hold', 0, 300, 'lin', 0, 5, 's', 0.1 / 300},
  {'lpf_lag', 'filter slew', 0.1, 8, 'lin', 0, 2, 's', 0.01 / 7.9},
  {'flanger', 'flanger', 0, 100, 'lin', 0, 0, '%'},
  {'reverb', 'reverb', 0, 100, 'lin', 0, 2, '%'},
  {'detuning', 'squishy detuning', 0, 20, 'lin', 0, 1, ''},
  {'tremolo', 'squishy tremolo', 0, 20, 'lin', 0, 1, ''},
}

local function finite(x)
  return type(x) == 'number' and x == x and x > -math.huge and x < math.huge
end

local function clamp(x, lo, hi) return math.min(hi, math.max(lo, x)) end
local function send(path, args)
  osc.send({'127.0.0.1', 57120}, '/nb_synthy/' .. path, args or {})
end

local function new_player()
  local p = {started = false, selected = false, timers = {}, values = {autofilter = 1}}
  for _, c in ipairs(controls) do p.values[c[1]] = c[7] end

  function p:send_param(key, value)
    if key == 'reverb' then value = value / 100 end
    send('param', {key, value})
  end

  function p:ensure_started()
    if self.started then return end
    self.started = true
    send('init')
    -- Send hold/slew/mode before the cutoff, which triggers manual takeover.
    for _, c in ipairs(controls) do
      if c[1] ~= 'lpf' then self:send_param(c[1], self.values[c[1]]) end
    end
    self:send_param('autofilter', self.values.autofilter)
    self:send_param('lpf', self.values.lpf)
  end

  function p:cancel_note_timer(note)
    if self.timers[note] then
      clock.cancel(self.timers[note])
      self.timers[note] = nil
    end
  end

  function p:stop_all()
    for _, id in pairs(self.timers) do clock.cancel(id) end
    self.timers = {}
    if self.started then send('panic') end
  end

  function p:dispose()
    self:stop_all()
    if self.started then send('free') end
    self.started = false
  end

  function p:note_on(note, vel)
    if not finite(note) or not finite(vel) then return end
    self:cancel_note_timer(note)
    if vel <= 0 then self:note_off(note); return end
    self:ensure_started()
    -- Keep the full n.b. identifier; SC derives pitch with modulo 128.
    send('note_on', {note, clamp(vel, 0, 1)})
  end

  function p:note_off(note)
    if not finite(note) then return end
    self:cancel_note_timer(note)
    if self.started then send('note_off', {note}) end
  end

  function p:play_note(note, vel, length, properties)
    if not finite(note) or not finite(vel) or not finite(length) then return end
    self:note_on(note, vel, properties)
    if vel <= 0 then return end
    if length <= 0 then self:note_off(note); return end
    self.timers[note] = clock.run(function()
      clock.sleep(length * clock.get_beat_sec())
      self.timers[note] = nil
      self:note_off(note)
    end)
  end

  function p:pitch_bend(note, amount)
    if self.started and finite(note) and finite(amount) then
      send('bend', {note, clamp(amount, -48, 48)})
    end
  end

  function p:set_slew(seconds)
    if finite(seconds) then self:set_value('portamento', clamp(seconds, 0, 10)) end
  end

  function p:modulate(value)
    if finite(value) then self:set_value('lpf', 20 * (1000 ^ clamp(value, 0, 1))) end
  end

  function p:set_value(key, value)
    local id = PREFIX .. key
    if params.lookup[id] then
      local previous = params:get(id)
      params:set(id, value)
      -- A repeated modulation value still renews manual filter control.
      if previous == value and self.started then self:send_param(key, value) end
    else
      self.values[key] = value
      if self.started then self:send_param(key, value) end
    end
  end

  function p:describe()
    local ids = {PREFIX .. 'autofilter'}
    for _, c in ipairs(controls) do table.insert(ids, PREFIX .. c[1]) end
    return {
      name = 'synthy', supports_bend = true, supports_slew = true,
      modulate_description = 'filter cutoff (20 Hz - 20 kHz)',
      note_mod_targets = {}, voice_mod_targets = {}, params = ids,
    }
  end

  function p:add_params()
    if params.lookup[GROUP] then return end
    params:add_group(GROUP, 'synthy', #controls + 2)
    for _, c in ipairs(controls) do
      local key = c[1]
      params:add_control(PREFIX .. key, c[2],
        controlspec.new(c[3], c[4], c[5], c[6], self.values[key], c[8], c[9]))
      params:set_action(PREFIX .. key, function(value)
        self.values[key] = value
        if self.started then self:send_param(key, value) end
      end)
    end
    params:add_option(PREFIX .. 'autofilter', 'filter mode', {'autonomous', 'manual'},
      self.values.autofilter == 1 and 1 or 2)
    params:set_action(PREFIX .. 'autofilter', function(value)
      self.values.autofilter = value == 1 and 1 or 0
      if self.started then self:send_param('autofilter', self.values.autofilter) end
    end)
    params:add_trigger(PREFIX .. 'panic', 'all notes off')
    params:set_action(PREFIX .. 'panic', function() self:stop_all() end)
    if not self.selected then params:hide(GROUP) end
  end

  function p:active()
    self.selected = true
    self:ensure_started()
    if params.lookup[GROUP] then params:show(GROUP); _menu.rebuild_params() end
  end

  function p:inactive()
    self.selected = false
    self:dispose()
    if params.lookup[GROUP] then params:hide(GROUP); _menu.rebuild_params() end
  end

  return p
end

mods.hook.register('script_pre_init', 'nb_synthy', function()
  if current then current:dispose() end
  current = new_player()
  note_players = note_players or {}
  note_players.synthy = current
end)

mods.hook.register('script_post_cleanup', 'nb_synthy', function()
  if current then current:dispose(); current = nil end
end)
