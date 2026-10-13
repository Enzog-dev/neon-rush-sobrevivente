-- =========================================
-- inicializacao e persistencia (cartdata)
-- =========================================
cartdata("neonrush_save_01") -- inicializa a memoria persistente do pico-8

function _load_data()
  highscore = dget(0)
  highlevel = dget(1)
  lifetime_coins = dget(2)
end

function _save_data()
  dset(0, highscore)
  dset(1, highlevel)
  dset(2, lifetime_coins)
end

_load_data()

game_state = "menu"
continue_cost = 20
state_timer = 0

-- =========================================
-- funcoes auxiliares de colisao e utilidades
-- =========================================
function col_rect(a,b)
  return a.x < b.x+b.w and a.x+a.w > b.x and a.y < b.y+b.h and a.y+a.h > b.y
end

function col_circ(a,b)
  local dx=a.x-b.x
  local dy=a.y-b.y
  local r=a.r+b.r
  return dx*dx+dy*dy < r*r
end

function get_bounds(obj)
  if obj.r then return {x=obj.x-obj.r, y=obj.y-obj.r, w=obj.r*2, h=obj.r*2} end
  return obj
end

function hit_wall(obj)
  local b = get_bounds(obj)
  for w in all(walls) do
    if col_rect(b, w) then return true end
  end
  return false
end

-- =========================================
-- geracao da arena e posicoes validas
-- =========================================
function _is_pos_free(obj, nx, ny)
  local oldx, oldy = obj.x, obj.y
  obj.x, obj.y = nx, ny
  local b = get_bounds(obj)
  local free = not hit_wall(obj)
  
  if free and p != nil and obj != p then
    if col_rect(b, get_bounds(p)) then free = false end
  end
  
  if free and coin != nil and obj != coin then
    if col_rect(b, get_bounds(coin)) then free = false end
  end
  
  if free and item != nil and item.active and obj != item then
    if col_rect(b, get_bounds(item)) then free = false end
  end
  
  if free and guns != nil then
    for g in all(guns) do
      if col_rect(b, get_bounds(g)) then free = false end
    end
  end
  
  obj.x, obj.y = oldx, oldy
  return free
end

function _get_valid_pos(obj)
  local r = obj.r or 3
  local w = obj.w or r*2
  local h = obj.h or r*2

  -- tenta posicoes aleatorias
  for i=1,150 do
    local px = 8 + rnd(112 - w)
    local py = 24 + rnd(96 - h)
    if _is_pos_free(obj, px, py) then
      obj.x = px
      obj.y = py
      return
    end
  end
  
  -- fallback de seguranca: busca em grade
  for gx=8, 112, 8 do
    for gy=24, 112, 8 do
      if _is_pos_free(obj, gx, gy) then
        obj.x = gx
        obj.y = gy
        return
      end
    end
  end
end

function _set_arena_layout(id)
  walls = {}
  local dx = flr(rnd(7)) - 3
  local dy = flr(rnd(7)) - 3
  
  if id == 1 then add(walls, {x=60+dx, y=44+dy, w=8, h=24})
  elseif id == 2 then
    add(walls, {x=24+dx, y=44+dy, w=26, h=6})
    add(walls, {x=78+dx, y=44+dy, w=26, h=6})
    add(walls, {x=24+dx, y=84+dy, w=26, h=6})
    add(walls, {x=78+dx, y=84+dy, w=26, h=6})
  elseif id == 3 then
    add(walls, {x=44+dx, y=30+dy, w=6, h=26})
    add(walls, {x=44+dx, y=72+dy, w=6, h=26})
    add(walls, {x=78+dx, y=30+dy, w=6, h=26})
    add(walls, {x=78+dx, y=72+dy, w=6, h=26})
  elseif id == 4 then
    add(walls, {x=42+dx, y=60+dy, w=14, h=6})
    add(walls, {x=72+dx, y=60+dy, w=14, h=6})
    add(walls, {x=60+dx, y=42+dy, w=6, h=14})
    add(walls, {x=60+dx, y=72+dy, w=6, h=14})
  elseif id == 5 then
    add(walls, {x=32+dx, y=44+dy, w=14, h=14})
    add(walls, {x=82+dx, y=44+dy, w=14, h=14})
    add(walls, {x=57+dx, y=72+dy, w=14, h=14})
  elseif id == 6 then
    add(walls, {x=24+dx, y=30+dy, w=20, h=6})
    add(walls, {x=24+dx, y=30+dy, w=6, h=20})
    add(walls, {x=84+dx, y=92+dy, w=20, h=6})
    add(walls, {x=98+dx, y=78+dy, w=6, h=20})
  else
    add(walls, {x=56+dx, y=56+dy, w=16, h=16})
    add(walls, {x=24+dx, y=24+dy, w=14, h=6})
    add(walls, {x=90+dx, y=24+dy, w=14, h=6})
    add(walls, {x=24+dx, y=98+dy, w=14, h=6})
    add(walls, {x=90+dx, y=98+dy, w=14, h=6})
  end
  
  -- se layout mudou sobre alguem, reposiciona esse alguem
  if p != nil and hit_wall(p) then _get_valid_pos(p) end
  if coin != nil and hit_wall(coin) then _get_valid_pos(coin) end
  if item != nil and item.active and hit_wall(item) then _get_valid_pos(item) end
end

-- =========================================
-- controle de armas
-- =========================================
function _reposition_gun(g)
  local best_x, best_y, best_dx, best_dy
  
  for i=1, 100 do
    local side = flr(rnd(4))
    local gx, gy, dx, dy
    
    if side == 0 then gx=8+rnd(112) gy=16 dx=0 dy=1
    elseif side == 1 then gx=124 gy=24+rnd(96) dx=-1 dy=0
    elseif side == 2 then gx=8+rnd(112) gy=124 dx=0 dy=-1
    else gx=0 gy=24+rnd(96) dx=1 dy=0 end
    
    local dummy = {x=gx, y=gy, w=g.w, h=g.h}
    local safe = not hit_wall(dummy)
    
    -- testa se a trajetoria inicial esta livre
    if safe then
      for step=1, 15 do
        dummy.x += dx * 2
        dummy.y += dy * 2
        if dummy.x < 0 or dummy.x > 128 or dummy.y < 16 or dummy.y > 128 then break end
        if hit_wall(dummy) then safe = false break end
      end
    end
    
    -- testa distancia do jogador e da moeda
    if safe and p then
      if (gx-p.x)^2 + (gy-p.y)^2 < 576 then safe = false end
    end
    if safe and coin then
      if (gx-coin.x)^2 + (gy-coin.y)^2 < 256 then safe = false end
    end
    
    if safe then
      best_x, best_y, best_dx, best_dy = gx, gy, dx, dy
      break
    end
  end
  
  -- fallback absoluto para nunca desaparecer
  if not best_x then best_x, best_y, best_dx, best_dy = 0, 16, 1, 0 end
  
  g.x, g.y = best_x, best_y
  g.bx, g.by = best_x, best_y
  g.dx, g.dy = best_dx, best_dy
end

function _reposition_all_guns()
  for g in all(guns) do
    _reposition_gun(g)
  end
end

function _check_weapon_progression()
  local tgt_guns = min(7, 1 + flr(level / 6))
  local needs_reposition = false
  
  if tgt_guns != current_layout then
    current_layout = tgt_guns
    _set_arena_layout(current_layout)
    needs_reposition = true
  end
  
  while #guns < tgt_guns do 
    add(guns, {w=4, h=4})
    needs_reposition = true
  end
  
  if needs_reposition then
    _reposition_all_guns()
  end
end

-- =========================================
-- controle de records e inicializacao
-- =========================================
function _add_vfx(x, y, col)
  add(fxs, {x=x, y=y, r=2, max_r=12, c=col})
end

function _check_records()
  if score > highscore then
    highscore = score
    new_record = true
  end
  if level > highlevel then
    highlevel = level
  end
  _save_data()
end

function _init()
  p = {x=64,y=64,w=6,h=6,spd=2,shielded=false,shield_timer=0,fx=1,fy=0,d_cd=0,d_time=0,invuln=0}
  walls = {}
  coin = {x=0,y=0,r=3}
  item = {active=false, x=0, y=0, r=4, type=0, timer=0}
  
  fxs = {}
  guns = {}
  
  score = 0
  coins = 0 -- moedas da partida
  level = 1
  hp = 3
  
  new_record = false
  slow_timer = 0
  current_layout = 0
  continue_cost = 20
  state_timer = 0
  
  -- gera arena primeiro, depois posiciona os objetos
  _check_weapon_progression()
  _get_valid_pos(p)
  _get_valid_pos(coin)
end

-- =========================================
-- loop principal (_update e _draw)
-- =========================================
function _update()
  local btn_z = btnp(4) -- z ou c unicamente
  local btn_x = btnp(5) -- x ou v

  if game_state == "menu" then
    if btn_z then _init() game_state = "play" end
    return
  end
  
  if state_timer > 0 then state_timer -= 1 end
  
  if game_state == "game_over" or game_state == "victory" then
    if state_timer == 0 then
      if btn_x and game_state == "game_over" then
        if lifetime_coins >= continue_cost then
          lifetime_coins -= continue_cost
          _save_data()
          continue_cost *= 2
          hp = 1
          p.invuln = 120
          
          if hit_wall(p) then _get_valid_pos(p) end
          _reposition_all_guns()
          game_state = "play"
        end
      elseif btn_z then
        _init()
        game_state = "play"
      elseif btnp(2) and game_state == "game_over" then
        _init()
        game_state = "menu"
      end
    end
    return
  end
  
  if p.invuln > 0 then p.invuln -= 1 end
  if slow_timer > 0 then slow_timer -= 1 end
  if p.d_cd > 0 then p.d_cd -= 1 end
  
  if p.shield_timer > 0 then
    p.shield_timer -= 1
    if p.shield_timer <= 0 then p.shielded = false end
  end
  
  _update_player()
  _update_items()
  _update_guns()
  
  for i=#fxs, 1, -1 do
    local f = fxs[i]
    f.r += 1
    if f.r > f.max_r then deli(fxs, i) end
  end
end

function _draw()
  cls()
  
  if game_state == "menu" then
    _draw_menu()
    return
  end
  
  for f in all(fxs) do circ(f.x, f.y, f.r, f.c) end
  _draw_items()
  _draw_arena()
  _draw_guns()
  _draw_player()
  _draw_ui()
  
  if game_state == "game_over" then _draw_game_over() end
  if game_state == "victory" then _draw_victory() end
end

-- =========================================
-- logica do jogador, itens e armas
-- =========================================
function _update_player()
  local ox, oy = p.x, p.y
  
  if p.d_time > 0 then
    p.x += p.fx * 4
    p.y += p.fy * 4
    p.d_time -= 1
  else
    local moved = false
    if btn(0) then p.x -= p.spd p.fx = -1 p.fy = 0 moved = true end
    if btn(1) then p.x += p.spd p.fx = 1 p.fy = 0 moved = true end
    if btn(2) then p.y -= p.spd p.fx = 0 p.fy = -1 moved = true end
    if btn(3) then p.y += p.spd p.fx = 0 p.fy = 1 moved = true end
    
    if (btn(4) or btn(5)) and p.d_cd == 0 and moved then
      p.d_time = 5
      p.d_cd = 45
    end
  end
  
  p.x = mid(0, p.x, 128 - p.w)
  p.y = mid(16, p.y, 128 - p.h)
  
  if hit_wall(p) then
    p.x = ox
    p.y = oy
  end
end

function _update_items()
  local pc = {x=p.x+p.w/2, y=p.y+p.h/2, r=p.w/2}
  
  if col_circ(pc, coin) then
    score += 1
    coins += 1
    lifetime_coins += 1
    _save_data()
    
    _add_vfx(coin.x, coin.y, 10)
    _check_level()
    _get_valid_pos(coin)
    _reposition_all_guns() 
    _try_spawn_item()
  end
  
  if item.active then
    item.timer -= 1
    if item.timer <= 0 then
      item.active = false
    else
      local ic = {x=item.x, y=item.y, r=item.r}
      if col_circ(pc, ic) then
        _add_vfx(item.x, item.y, 7)
        _apply_item(item.type)
        item.active = false
      end
    end
  end
end

function _check_level()
  if level >= 40 then return end
  
  if coins > 0 and coins % 5 == 0 then
    level += 1
    for i=1, 8 do _add_vfx(p.x+3-8+rnd(16), p.y+3-8+rnd(16), 12) end
    
    if level == 40 then
      game_state = "victory"
      state_timer = 30
      _check_records()
      return
    end
    
    _check_weapon_progression()
  end
end

function _try_spawn_item()
  if not item.active and rnd(100) < 20 then
    item.active = true
    item.timer = 300
    _get_valid_pos(item)
    
    local r = rnd(100)
    if r < 25 then item.type = 1
    elseif r < 45 then item.type = 2
    elseif r < 65 then item.type = 3
    elseif r < 85 then item.type = 4
    else item.type = 5 end
  end
end

function _apply_item(t)
  if t == 1 then p.shielded = true p.shield_timer = 600
  elseif t == 2 then hp = min(3, hp + 1)
  elseif t == 3 then score += 5
  elseif t == 4 then for g in all(guns) do g.bx = g.x g.by = g.y end
  elseif t == 5 then slow_timer = 300 end
end

function _update_guns()
  local speed = min(7, 3 + (level * 0.1))
  if slow_timer > 0 then speed *= 0.4 end
  
  for g in all(guns) do
    g.bx += g.dx * speed
    g.by += g.dy * speed
    
    local brect = {x=g.bx, y=g.by, w=g.w, h=g.h}
    
    if g.bx<0 or g.bx>128 or g.by<16 or g.by>128 or hit_wall(brect) then
      g.bx = g.x
      g.by = g.y
    end
    
    if p.invuln == 0 and col_rect(brect, get_bounds(p)) then
      if p.shielded then
        p.shielded = false
        p.shield_timer = 0
        for i=1,5 do _add_vfx(p.x+3-4+rnd(8), p.y+3-4+rnd(8), 11) end
      else
        hp -= 1
        for i=1,5 do _add_vfx(p.x+3-4+rnd(8), p.y+3-4+rnd(8), 8) end
        
        if hp <= 0 then
          game_state = "game_over"
          state_timer = 30
          _check_records()
          for i=1,20 do _add_vfx(p.x+3-8+rnd(16), p.y+3-8+rnd(16), 8) end
        end
      end
      p.invuln = 45
      g.bx = g.x
      g.by = g.y
    end
  end
end

-- =========================================
-- desenhos (draw)
-- =========================================
function _draw_ui()
  rectfill(0, 0, 128, 15, 0)
  print("pontos:"..score.." rec:"..highscore, 2, 2, 7)
  
  local c_prog = coins % 5
  if level == 40 then c_prog = 5 end
  
  print("vidas:"..hp.." nivel:"..level.."/40 md:"..c_prog.."/5", 2, 9, 7)
  line(0, 15, 128, 15, 5)
  
  local y_buff = 118
  local blink = flr(time()*4)%2==0
  
  if p.shield_timer > 0 then 
    local col = (p.shield_timer < 60 and blink) and 7 or 11
    print("escudo", 2, y_buff, col) 
    rectfill(28, y_buff+1, 28 + (p.shield_timer/600)*20, y_buff+3, col)
    y_buff -= 6
  end
  if slow_timer > 0 then 
    local col = (slow_timer < 60 and blink) and 7 or 12
    print("lento", 2, y_buff, col) 
    rectfill(28, y_buff+1, 28 + (slow_timer/300)*20, y_buff+3, col)
  end
end

function _draw_arena()
  for w in all(walls) do
    rectfill(w.x+1, w.y+1, w.x+w.w, w.y+w.h, 0)
    rectfill(w.x, w.y, w.x+w.w-1, w.y+w.h-1, 13)
    rectfill(w.x+1, w.y+1, w.x+w.w-2, w.y+w.h-2, 5)
  end
  circfill(coin.x, coin.y, coin.r, 10)
end

function _draw_items()
  if not item.active then return end
  if item.timer < 60 and item.timer % 10 < 5 then return end
  
  local x, y = item.x, item.y
  
  if item.type == 1 then circfill(x, y, 3, 1) circ(x, y, 4, 12)
  elseif item.type == 2 then circfill(x-1,y-1,1,8) circfill(x+1,y-1,1,8) line(x-2,y,x,y+2,8) line(x+2,y,x,y+2,8)
  elseif item.type == 3 then rectfill(x-1,y-2,x+1,y+2,14) rectfill(x-2,y-1,x+2,y+1,14) pset(x,y-1,7)
  elseif item.type == 4 then circfill(x, y+1, 2, 0) pset(x, y-2, 5) pset(x+1, y-3, 8)
  elseif item.type == 5 then circfill(x, y, 3, 1) circ(x, y, 4, 7) line(x,y,x,y-2,7) line(x,y,x+1,y,7) end
end

function _draw_player()
  if p.d_time > 0 then rectfill(p.x-p.fx*4, p.y-p.fy*4, p.x-p.fx*4+p.w-1, p.y-p.fy*4+p.h-1, 7) end
  if p.invuln == 0 or (p.invuln % 6 < 3) then
    rectfill(p.x, p.y, p.x+p.w-1, p.y+p.h-1, 12)
    if p.shielded then
      local blink = (p.shield_timer < 60 and flr(time()*4)%2==0)
      if not blink then circ(p.x+p.w/2, p.y+p.h/2, p.w, 11) end
    end
  end
end

function _draw_guns()
  print("",0,0) 
  for g in all(guns) do
    rectfill(g.x, g.y, g.x+g.w-1, g.y+g.h-1, 13)
    rectfill(g.bx, g.by, g.bx+g.w-1, g.by+g.h-1, 8)
  end
end

function _draw_menu()
  _draw_arena()
  _draw_player()
  
  rectfill(10, 20, 118, 108, 0)
  rect(10, 20, 118, 108, 5)
  
  print("neon rush: sobrevivente", 18, 28, 10)
  print("=======================", 18, 34, 5)
  
  print("controles:", 44, 48, 7)
  print("setas = mover", 38, 58, 6)
  print("z ou x = dash", 36, 68, 12)
  
  print("moedas totais: "..lifetime_coins, 26, 82, 14)
  
  if flr(time()*2)%2==0 then print("aperte z para iniciar", 22, 96, 7) end
end

function _draw_game_over()
  -- fundo e titulo
  rectfill(2, 2, 125, 125, 0)
  rect(2, 2, 125, 125, 7)
  rectfill(2, 2, 125, 12, 8)
  print("fim de jogo", 42, 4, 7)
  
  -- area de estatisticas
  rectfill(4, 15, 123, 44, 0)
  print("nivel alcancado: "..level, 8, 18, 7)
  print("pontos: "..score.." (rec: "..highscore..")", 8, 26, 7)
  print("moedas totais: "..lifetime_coins, 8, 36, 14)
  
  -- opcao 1: continuar
  local can_cont = lifetime_coins >= continue_cost
  local c_bg = can_cont and 1 or 5
  local c_fg = can_cont and 12 or 13
  local c_text = can_cont and 12 or 8
  
  rectfill(6, 48, 121, 70, c_bg)
  rect(6, 48, 121, 70, c_fg)
  
  if can_cont then
    print("continuar - "..continue_cost.." moedas", 10, 52, c_text)
    print("aperte x", 84, 62, 7)
    print("tem: "..lifetime_coins, 10, 62, 10)
  else
    print("continuar (falta moeda)", 10, 52, c_text)
    print("custa: "..continue_cost.." tem: "..lifetime_coins, 10, 62, 8)
  end
  
  -- opcao 2: nova partida
  rectfill(6, 74, 121, 94, 3)
  rect(6, 74, 121, 94, 11)
  print("nova partida", 10, 78, 11)
  print("aperte z", 84, 86, 7)
  
  -- opcao 3: voltar ao menu
  rectfill(6, 98, 121, 118, 2)
  rect(6, 98, 121, 118, 4)
  print("voltar ao menu", 10, 102, 10)
  print("aperte cima", 74, 110, 7)
end

function _draw_victory()
  rectfill(2, 2, 125, 125, 0)
  rect(2, 2, 125, 125, 11)
  
  rectfill(2, 2, 125, 18, 11)
  print("vitoria!", 48, 6, 0)
  
  print("nivel: "..level.." (max: "..highlevel..")", 12, 28, 7)
  print("pontos: "..score.." (rec: "..highscore..")", 12, 38, 7)
  print("moedas da partida: "..coins, 12, 48, 10)
  print("moedas no total: "..lifetime_coins, 12, 58, 14)
  
  if new_record then 
    if flr(time()*4)%2==0 then print("novo recorde!", 38, 72, 10) end 
  end
  
  rectfill(8, 96, 120, 118, 0)
  rect(8, 96, 120, 118, 12)
  print("jogar novamente", 34, 102, 12)
  if flr(time()*2)%2==0 then print("aperte z", 48, 110, 7) end
end