-- Run from the package root:
-- lua tests/player_test.lua /path/to/norns /path/to/nb
-- Uses upstream norns parameters and n.b.; mocks only hardware and scheduling.
local norns_root = assert(arg[1], 'norns source path required')
local nb_root = assert(arg[2], 'nb source path required')
package.path = norns_root .. '/lua/?.lua;' .. norns_root .. '/lua/core/?.lua;'
  .. norns_root .. '/lua/lib/?.lua;' .. package.path
-- Norns builds Lua with the legacy math compatibility helpers.
math.pow = math.pow or function(a,b) return a ^ b end
util = require 'util'
tab = require 'tabutil'
local hooks, messages, tasks = {}, {}, {}
local next_task = 0
package.loaded['core/mods'] = {hook = {register = function(event, name, fn) hooks[event] = fn end}}
norns = {pmap = {data = {}}, state = {}}
_menu = {rebuild_params = function() end}
midi = {vports = {}}
engine = {name = 'host-engine'}
local host_osc = function() end
osc = {event = host_osc, send = function(to, path, args)
  assert(to[2] == 57120)
  messages[#messages + 1] = {path = path, args = args}
end}
clock = {
  run = function(fn)
    next_task = next_task + 1
    local id = next_task
    tasks[id] = coroutine.create(fn)
    assert(coroutine.resume(tasks[id]))
    return id
  end,
  sleep = coroutine.yield,
  cancel = function(id) tasks[id] = nil end,
  get_beat_sec = function() return 0.5 end,
}
local function finish_tasks()
  local pending = tasks; tasks = {}
  for _, co in pairs(pending) do assert(coroutine.resume(co)) end
end
local function count(path)
  local n = 0
  for _, m in ipairs(messages) do if m.path == '/nb_synthy/' .. path then n = n + 1 end end
  return n
end
local function last(path)
  for i = #messages, 1, -1 do if messages[i].path == '/nb_synthy/' .. path then return messages[i].args end end
end
local function near(a,b) assert(math.abs(a-b) < 0.000001, tostring(a)..' ~= '..tostring(b)) end
local tests = 0
local function passed(name) tests = tests + 1; print('PASS ' .. name) end
params = require('core/paramset').new()
_path = {code = ''}
include = function() return dofile(nb_root .. '/lib/player.lua') end
local nb = dofile(nb_root .. '/lib/nb.lua')
dofile('lib/mod.lua')
hooks.script_pre_init()
assert(note_players.synthy)
nb:init()
nb:add_param('voice_1', 'voice 1')
nb:add_param('voice_2', 'voice 2')
nb:add_player_params()
assert(count('init') == 0)
assert(params.hidden[params.lookup.nb_synthy_group])
local size = params.count
nb:add_player_params()
assert(params.count == size)
passed('registration, lazy allocation, real n.b. and norns params, idempotent parameters')
finish_tasks()
params:set('voice_1', 2)
local p = params:lookup_param('voice_1'):get_player()
assert(p == note_players.synthy)
assert(count('init') == 1 and not params.hidden[params.lookup.nb_synthy_group])
params:set('voice_2', 2)
params:lookup_param('voice_2'):get_player()
assert(count('init') == 1)
passed('two selectors share one player without duplicate initialization')
p:note_on(60.5, 0.7)
near(last('note_on')[1],60.5)
near(last('note_on')[2],0.7)
p:note_on(188.5, 2)
near(last('note_on')[1],188.5)
near(last('note_on')[2],1)
passed('fractional pitch, independent n.b. identifiers, velocity clamp')
local before = count('note_on')
p:note_on(70, 0); p:note_on(0/0, 1); p:note_on(60, math.huge)
assert(count('note_on') == before)
assert(last('note_off')[1] == 70)
passed('zero velocity and invalid values')
p:play_note(64, 0.5, 2)
local first = p.timers[64]
p:play_note(64, 0.6, 4)
assert(tasks[first] == nil and p.timers[64] ~= first)
local off_before = count('note_off')
finish_tasks()
assert(count('note_off') == off_before + 1 and p.timers[64] == nil)
passed('retrigger cancels the old timed note-off')
p:play_note(65, 0.5, 2)
local timer = p.timers[65]
p:note_off(65)
assert(tasks[timer] == nil)
p:play_note(66, 0.5, 0)
assert(last('note_off')[1] == 66)
passed('explicit note-off cancels timers and zero length releases immediately')
p:pitch_bend(188.5, 2)
assert(last('bend')[1] == 188.5 and last('bend')[2] == 2)
p:set_slew(0.25)
near(params:get('nb_synthy_portamento'),0.25)
p:modulate(1)
near(params:get('nb_synthy_lpf'),20000)
local param_before = count('param')
p:modulate(1)
assert(count('param') == param_before + 1 and last('param')[1] == 'lpf')
params:set('nb_synthy_reverb', 25)
near(last('param')[2],0.25)
params:set('nb_synthy_autofilter', 2)
assert(last('param')[1] == 'autofilter' and last('param')[2] == 0)
passed('pitch bend, slew, modulation, parameter conversion, manual filter')
params:set('voice_1', 1)
assert(count('free') == 0)
params:set('voice_2', 1)
assert(count('free') == 1 and not p.started)
assert(params.hidden[params.lookup.nb_synthy_group])
passed('reference counting frees only after the final selector leaves')
params:set('voice_1', 2)
assert(p.started and count('init') == 2)
near(p.values.reverb,25)
assert(p.values.autofilter == 0)
passed('reactivation restores edited values')
p:play_note(60,0.8,8)
p:stop_all()
assert(next(p.timers) == nil and next(tasks) == nil)
passed('panic cancels delayed note-offs')
hooks.script_post_cleanup()
assert(not p.started)
assert(osc.event == host_osc and engine.name == 'host-engine')
passed('cleanup preserves the host OSC callback and engine')
params = require('core/paramset').new()
hooks.script_pre_init()
assert(note_players.synthy ~= p)
near(note_players.synthy.values.reverb,2)
assert(not note_players.synthy.started)
passed('script changes create fresh player state')
print(tests .. ' integration checks passed')
