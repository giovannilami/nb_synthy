-- nb_synthy: prova audio
-- K2: tieni premuto per un accordo
-- K3: tutte le note off
-- E2: nota base
-- E3: velocity
-- Abilita prima il mod nb_synthy.

local player
local root_note, velocity = 48, 0.6
local held = {}

function init()
  if note_players then player = note_players.synthy end
  if player then player:add_params(); player:active() end
  redraw()
end

function enc(n, d)
  if n == 2 then root_note = util.clamp(root_note + d, 24, 84) end
  if n == 3 then velocity = util.clamp(velocity + d / 100, 0.01, 1) end
  redraw()
end

function key(n, z)
  if not player then return end
  if n == 2 then
    if z == 1 then
      for _, note in ipairs(held) do player:note_off(note) end
      held = {}
      for _, interval in ipairs({0, 4, 7, 12}) do
        local note = root_note + interval
        held[#held + 1] = note
        player:note_on(note, velocity)
      end
    else
      for _, note in ipairs(held) do player:note_off(note) end
      held = {}
    end
  elseif n == 3 and z == 1 then
    player:stop_all()
    held = {}
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(3, 12); screen.text('nb_synthy / test')
  if player then
    screen.move(3, 27); screen.text('nota ' .. root_note .. '   vel ' .. math.floor(velocity * 100))
    screen.move(3, 42); screen.text('K2: tieni per accordo')
    screen.move(3, 56); screen.text('K3: tutte le note off')
  else
    screen.move(3, 30); screen.text('Abilita nb_synthy')
    screen.move(3, 44); screen.text('in SYSTEM > MODS')
    screen.move(3, 58); screen.text('poi riavvia norns.')
  end
  screen.update()
end

function cleanup()
  if player then player:inactive() end
end
