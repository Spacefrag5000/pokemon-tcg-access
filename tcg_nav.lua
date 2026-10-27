-- ============================================================
-- Pokemon TCG accessibility mod - walking around rooms.
-- Loaded by tcg_core.lua: dofile(...)(E) with E holding the core's
-- helpers (rb, rbytes, romByte, romWord, textFromId, say, GAP).
-- Returns the nav functions.
--
-- Everything comes from the game's own data (see PROGRESS.md):
--   wCurMap $D32F, player tile coords $D330/$D331, facing $D334
--     (0 north, 1 east, 2 south, 3 west);
--   wPermissionMap $D133: 16x16 blocks (a block = 2x2 tiles = one
--     step), bits $80 wall, $40 something to talk to (person or
--     object), $10 a text box is over it;
--   wLoadedNPCs $D34A: 8 x 12 bytes (id, sprite, x, y, direction...);
--   names: NPCHeaderPointers 04:58f5, name text id at +7;
--   exits: WarpDataPointers 07:4099, 5 bytes (x, y, map, x, y);
--   objects: MapScripts 04:562a, 8 words per map, word 2 -> list of
--     9 bytes (facing needed, x, y, routine, text, name), $ff ends.
-- Distances are in steps: one step moves the player one block.
-- ============================================================
return function(E)
local rb, rbytes, romByte, romWord, textFromId, say, GAP =
  E.rb, E.rbytes, E.romByte, E.romWord, E.textFromId, E.say, E.GAP

local MAP_NAMES = {
  [0] = "the island map", "Mason Laboratory", "Deck Machine Room", "Ishihara's House",
  "Fighting Club Entrance", "Fighting Club Lobby", "Fighting Club",
  "Rock Club Entrance", "Rock Club Lobby", "Rock Club",
  "Water Club Entrance", "Water Club Lobby", "Water Club",
  "Lightning Club Entrance", "Lightning Club Lobby", "Lightning Club",
  "Grass Club Entrance", "Grass Club Lobby", "Grass Club",
  "Psychic Club Entrance", "Psychic Club Lobby", "Psychic Club",
  "Science Club Entrance", "Science Club Lobby", "Science Club",
  "Fire Club Entrance", "Fire Club Lobby", "Fire Club",
  "Challenge Hall Entrance", "Challenge Hall Lobby", "Challenge Hall",
  "Pokemon Dome Entrance", "Pokemon Dome", "Hall of Honor",
}

-- object routines (bank 03) -> what the thing is; book-like objects
-- (PrintInteractableObjectText) use their own name text instead
local OBJECT_KINDS = {
  [0x47ea] = "PC", [0x5932] = "Auto Deck Machine",
  [0x593f] = "Fighting Medal Auto Deck Machine", [0x5995] = "Rock Medal Auto Deck Machine",
  [0x59c2] = "Water Medal Auto Deck Machine", [0x59ef] = "Lightning Medal Auto Deck Machine",
  [0x5a1c] = "Grass Medal Auto Deck Machine", [0x5a49] = "Psychic Medal Auto Deck Machine",
  [0x5a76] = "Science Medal Auto Deck Machine", [0x5aa3] = "Fire Medal Auto Deck Machine",
  [0x5ad0] = "Auto Deck Machine", [0x7c7a] = "Gift Center", [0x7c52] = "Battle Center",
  [0x7631] = "Plate of Legends", [0x76af] = "Pokemon Dome door",
  [0x7be1] = "Legendary Auto Deck Machine", [0x7bf1] = "Legendary Cards",
}
local PRINT_OBJECT_TEXT = 0x4c25

local DIRS = { [0] = { 0, -1, "up" }, { 1, 0, "right" }, { 0, 1, "down" }, { -1, 0, "left" } }

local NAV = { cat = 1, idx = 1, guiding = nil, lastMap = nil }

local function world()
  local w = { map = rb(0xd32f), px = rb(0xd330) // 2, py = rb(0xd331) // 2, facing = rb(0xd334) }
  local perm = rbytes(0xd133, 256)
  w.walk = function(x, y)
    if x < 0 or y < 0 or x > 15 or y > 15 then return false end
    return (perm[y * 16 + x + 1] & 0xc0) == 0
  end
  return w
end

-- breadth-first search from the player over walkable blocks
local function bfs(w)
  local dist, prev = {}, {}
  local q, head = { { w.px, w.py } }, 1
  dist[w.py * 16 + w.px] = 0
  while head <= #q do
    local x, y = q[head][1], q[head][2]
    head = head + 1
    for d = 0, 3 do
      local nx, ny = x + DIRS[d][1], y + DIRS[d][2]
      local k = ny * 16 + nx
      if dist[k] == nil and w.walk(nx, ny) then
        dist[k] = dist[y * 16 + x] + 1
        prev[k] = { x, y, d }
        q[#q + 1] = { nx, ny }
      end
    end
  end
  return dist, prev
end

local function bestGoal(t, dist)
  local best, bd = nil, nil
  for _, g in ipairs(t.goals) do
    local d = dist[g.y * 16 + g.x]
    if d and (not bd or d < bd) then best, bd = g, d end
  end
  return best, bd
end

-- Fewest turns among the shortest routes, so directions come out as
-- "1 step left, then 5 steps up" rather than a zig-zag. turns[k][d] =
-- fewest turns reaching block k on a shortest route whose last step
-- went in direction d; built in order of distance from the player.
local function turnTable(dist, w)
  local order = {}
  for k, d in pairs(dist) do order[#order + 1] = { k, d } end
  table.sort(order, function(a, b) return a[2] < b[2] end)
  local turns = {}
  for _, e in ipairs(order) do
    local k, d = e[1], e[2]
    local x, y = k % 16, k // 16
    local t = {}
    if d == 0 then t[-1] = 0 end
    for dir = 0, 3 do
      local px, py = x - DIRS[dir][1], y - DIRS[dir][2]
      local pk = py * 16 + px
      if px >= 0 and py >= 0 and px <= 15 and py <= 15 and dist[pk] == d - 1 and turns[pk] then
        for pd, pt in pairs(turns[pk]) do
          local c = pt + ((pd ~= -1 and pd ~= dir) and 1 or 0)
          if t[dir] == nil or c < t[dir] then t[dir] = c end
        end
      end
    end
    turns[k] = t
  end
  return turns
end

-- the path to goal as legs { d = direction, n = steps }
local function legs(dist, w, g)
  local moves = {}
  local x, y = g.x, g.y
  local d = dist[y * 16 + x]
  if not d then return {} end
  local turns = turnTable(dist, w)
  -- last step: the direction with fewest turns
  local want
  for dir, c in pairs(turns[y * 16 + x] or {}) do
    if dir ~= -1 and (want == nil or c < turns[y * 16 + x][want]) then want = dir end
  end
  while d > 0 and want ~= nil do
    table.insert(moves, 1, want)
    local here = turns[y * 16 + x][want]
    x, y, d = x - DIRS[want][1], y - DIRS[want][2], d - 1
    if d == 0 then break end
    -- the step before: one whose turn count leads to `here`
    local nextWant
    for pd, pt in pairs(turns[y * 16 + x] or {}) do
      if pd ~= -1 and pt + ((pd ~= want) and 1 or 0) == here then
        if nextWant == nil or pd == want then nextWant = pd end
      end
    end
    want = nextWant
  end
  local out = {}
  for _, d in ipairs(moves) do
    if #out > 0 and out[#out].d == d then out[#out].n = out[#out].n + 1
    else out[#out + 1] = { d = d, n = 1 } end
  end
  return out
end

local function legText(l)
  return string.format("%d %s %s", l.n, l.n == 1 and "step" or "steps", DIRS[l.d][3])
end

local function npcName(id)
  local hdr = romWord(0x04, 0x58f5 + id * 2)
  if hdr < 0x4000 then return nil end
  local s = textFromId(romWord(0x04, hdr + 7))
  return (s ~= "" and s ~= "...") and s or nil
end

-- an event's value (GetEventValue): EventVarMasks 03:4b37 gives each
-- event's byte in wEventVars $D3D2 and its bits
local function eventValue(ev)
  local off, mask = romByte(0x03, 0x4b37 + ev * 2), romByte(0x03, 0x4b37 + ev * 2 + 1)
  if mask == 0 then return 0 end
  local v = rb(0xd3d2 + off) & mask
  while mask & 1 == 0 do mask, v = mask >> 1, v >> 1 end
  return v
end

-- objects not in MapScripts, added by a room's own script (all facing
-- north; the player's tile coordinates): Dr. Mason's Challenge Machine
-- once the legendary cards are received (EVENT_RECEIVED_LEGENDARY_CARDS
-- $22), and the Fire Club Lobby wall a man tells you to check
-- (EVENT_LAD2_STATE $21 = 1; his words: "Check the wall 2 tiles left of
-- the bookcase")
local EXTRA_THINGS = {
  [0x01] = { event = 0x22, value = 1, name = "Challenge Machine", spots = { { 10, 4 }, { 12, 4 } } },
  [0x1a] = { event = 0x21, value = 1, name = "Wall 2 tiles left of the bookcase", spots = { { 16, 2 } } },
}

-- all targets in the current room, by category
local function targets(w)
  local cats = { { name = "People", items = {} }, { name = "Exits", items = {} },
    { name = "Things", items = {} } }
  -- standing on a neighbour block and facing the target
  local function around(bx, by)
    local g = {}
    for d = 0, 3 do
      local x, y = bx - DIRS[d][1], by - DIRS[d][2]
      if w.walk(x, y) then g[#g + 1] = { x = x, y = y, face = d } end
    end
    return g
  end
  for i = 0, 7 do
    local b = 0xd34a + i * 12
    local id = rb(b)
    if id ~= 0 then
      local bx, by = rb(b + 2) // 2, rb(b + 3) // 2
      local name = npcName(id)
      if not name then
        name = "someone"
        GAP.note("npc", string.format("map %d npc %02X", w.map, id), "no name text", false)
      end
      cats[1].items[#cats[1].items + 1] = { name = name, bx = bx, by = by,
        goals = around(bx, by), kind = "person" }
    end
  end
  -- exits; doors side by side with the same destination are one exit
  local wp = romWord(0x07, 0x4099 + w.map * 2)
  if w.map > 0 and wp >= 0x4000 then
    local byDest = {}
    for i = 0, 40 do
      local e = wp + i * 5
      local x, y = romByte(0x07, e), romByte(0x07, e + 1)
      if x == 0 and y == 0 then break end
      local dest = romByte(0x07, e + 2)
      local t = byDest[dest]
      if not t then
        local where = (dest == 0) and "Exit outside" or ("Door to " .. (MAP_NAMES[dest] or ("room " .. dest)))
        t = { name = where, goals = {}, kind = "exit", bx = x // 2, by = y // 2 }
        byDest[dest] = t
        cats[2].items[#cats[2].items + 1] = t
      end
      t.goals[#t.goals + 1] = { x = x // 2, y = y // 2 }
    end
  end
  -- things you face and press A on
  local op = romWord(0x04, 0x562a + w.map * 16 + 4)
  if w.map > 0 and op >= 0x4000 then
    local seen = {}
    for i = 0, 40 do
      local e = op + i * 9
      local face = romByte(0x04, e)
      if face == 0xff then break end
      local x, y = romByte(0x04, e + 1) // 2, romByte(0x04, e + 2) // 2
      local routine = romWord(0x04, e + 3)
      local name
      if routine == PRINT_OBJECT_TEXT then name = textFromId(romWord(0x04, e + 7))
      else name = OBJECT_KINDS[routine] end
      if not name or name == "" then
        name = "something to examine"
        GAP.note("object", string.format("map %d routine %04X", w.map, routine),
          string.format("block %d,%d", x, y), false)
      end
      local d = face & 3
      local g = { x = x - DIRS[d][1], y = y - DIRS[d][2], face = d }
      local k = name .. "|" .. routine
      local t = seen[k]
      -- one machine drawn over two blocks is listed once
      if t and math.abs(t.bx - x) + math.abs(t.by - y) <= 1 then
        t.goals[#t.goals + 1] = g
      else
        t = { name = name, bx = x, by = y, goals = { g }, kind = "thing" }
        seen[k] = t
        cats[3].items[#cats[3].items + 1] = t
      end
    end
  end
  -- things a room's own script adds once an event is set
  -- (FindExtraInteractableObjects: the player's tile and facing)
  local ex = EXTRA_THINGS[w.map]
  if ex and eventValue(ex.event) == ex.value then
    local t = { name = ex.name, goals = {}, kind = "thing" }
    for _, s in ipairs(ex.spots) do
      local px, py = s[1] // 2, s[2] // 2
      t.bx, t.by = px, py - 1
      t.goals[#t.goals + 1] = { x = px, y = py, face = 0 }
    end
    cats[3].items[#cats[3].items + 1] = t
  end
  return cats
end

-- "All" first, then only the categories that hold something
local function categories(w)
  local cats = targets(w)
  local dist, prev = bfs(w)
  local all = { name = "All", items = {} }
  local out = { all }
  local function near(a, b) return (a.steps or 999) < (b.steps or 999) end
  for _, c in ipairs(cats) do
    for _, t in ipairs(c.items) do
      t.goal, t.steps = bestGoal(t, dist)
      all.items[#all.items + 1] = t
    end
    table.sort(c.items, near)
    if #c.items > 0 then out[#out + 1] = c end
  end
  table.sort(all.items, near)
  return out, dist, prev
end

local function describe(t)
  if not t.goal then return t.name .. ", can't be reached from here" end
  if t.steps == 0 then
    if t.goal.face then return t.name .. ", right here, " .. DIRS[t.goal.face][3] end
    return t.name .. ", you are on it"
  end
  return string.format("%s, %d %s", t.name, t.steps, t.steps == 1 and "step" or "steps")
end

local function current()
  local w = world()
  if w.map == 0 then return nil end
  local cats, dist, prev = categories(w)
  NAV.cat = math.max(1, math.min(NAV.cat, #cats))
  local c = cats[NAV.cat]
  NAV.idx = math.max(1, math.min(NAV.idx, math.max(1, #c.items)))
  return w, cats, c, c.items[NAV.idx], dist
end

local function routeText(w, t, dist)
  if not t.goal then return t.name .. " can't be reached from here." end
  local l = legs(dist, w, t.goal)
  if #l == 0 then
    if t.goal.face then return "Arrived. " .. t.name .. " is " .. DIRS[t.goal.face][3] .. "." end
    return "Arrived at " .. t.name .. "."
  end
  local parts = {}
  for i, leg in ipairs(l) do parts[i] = legText(leg) end
  local s = table.concat(parts, ", then ")
  if t.goal.face then s = s .. ", then " .. t.name .. " is " .. DIRS[t.goal.face][3] end
  return s .. "."
end

local M = {}

-- ---------- the island map ----------
-- Moving the d-pad steps a selection between places along
-- OverworldMap_CursorTransitions (04:4ebc, 4 bytes per place: the place
-- reached going north, east, south, west, 0 = none); the selected
-- place's name is printed at the top. wOverworldMapSelection $D32E.
-- J/L list the places with the d-pad route from the selected one; P
-- presses those directions for you (as the DBZ mod drives its world
-- map crosshair), leaving only A to go there.
local PLACES = { "Mason Laboratory", "Ishihara's House", "Fighting Club", "Rock Club",
  "Water Club", "Lightning Club", "Grass Club", "Psychic Club", "Science Club",
  "Fire Club", "Challenge Hall", "Pokemon Dome" }
local PAD = { [0] = "Up", "Right", "Down", "Left" }
local ISLAND = { idx = 0, queue = {} } -- idx 0: the first L gives the nearest

local function islandRoutes(from)
  -- breadth-first over the transition table
  local route = { [from] = {} }
  local q, head = { from }, 1
  while head <= #q do
    local p = q[head]
    head = head + 1
    for d = 0, 3 do
      local n = romByte(0x04, 0x4ebc + p * 4 + d)
      if n ~= 0 and route[n] == nil then
        local r = {}
        for i, v in ipairs(route[p]) do r[i] = v end
        r[#r + 1] = d
        route[n] = r
        q[#q + 1] = n
      end
    end
  end
  return route
end

local function islandList()
  local from = rb(0xd32e)
  local route = islandRoutes(from)
  local items = {}
  for id = 1, #PLACES do
    if id ~= from and route[id] then
      items[#items + 1] = { id = id, name = PLACES[id], route = route[id] }
    end
  end
  table.sort(items, function(a, b)
    if #a.route ~= #b.route then return #a.route < #b.route end
    return a.id < b.id
  end)
  return items, from
end

local function routeWords(r)
  local t = {}
  for i, d in ipairs(r) do t[i] = DIRS[d][3] end
  return table.concat(t, ", ")
end

M.island = false -- set by the core while the island map reads input

function M.islandItem(step)
  local items = islandList()
  if #items == 0 then return end
  if ISLAND.idx == 0 and step < 0 then ISLAND.idx = #items
  else ISLAND.idx = ((ISLAND.idx - 1 + step) % #items) + 1 end
  local it = items[ISLAND.idx]
  say(it.name .. ", " .. routeWords(it.route), true)
end

function M.islandRepeat()
  local from = rb(0xd32e)
  say("Island map. On " .. (PLACES[from] or "?") .. ".", true)
end

function M.islandGo()
  local items = islandList()
  if ISLAND.idx < 1 then say("Choose a place with J or L first.", true) return end
  local it = items[math.min(ISLAND.idx, #items)]
  if not it then return end
  say("Moving to " .. it.name .. ".", true)
  for _, d in ipairs(it.route) do ISLAND.queue[#ISLAND.queue + 1] = PAD[d] end
  ISLAND.hold, ISLAND.gap = 0, 0
  ISLAND.idx = 0
end

-- each frame: the d-pad button to hold for a queued island move
function M.pad()
  if #ISLAND.queue == 0 then return nil end
  if ISLAND.gap > 0 then ISLAND.gap = ISLAND.gap - 1 return nil end
  ISLAND.hold = ISLAND.hold + 1
  local b = ISLAND.queue[1]
  if ISLAND.hold >= 4 then
    table.remove(ISLAND.queue, 1)
    ISLAND.hold, ISLAND.gap = 0, 12
  end
  return b
end

-- true when there is a room to navigate
function M.active() return rb(0xd32f) ~= 0 end

function M.category(step)
  local w, cats = current()
  if not w then say("Nothing to list here.", true) return end
  NAV.cat = ((NAV.cat - 1 + step) % #cats) + 1
  NAV.idx = 1
  local _, _, c, t = current()
  say(c.name .. ". " .. (t and describe(t) or "empty"), true)
end

function M.item(step)
  local w, cats, c = current()
  if not w then say("Nothing to list here.", true) return end
  if #c.items == 0 then say(c.name .. ", empty", true) return end
  NAV.idx = ((NAV.idx - 1 + step) % #c.items) + 1
  say(describe(c.items[NAV.idx]), true)
end

function M.repeatCurrent()
  local w, cats, c, t = current()
  if not w then say("Nothing to list here.", true) return end
  say(MAP_NAMES[w.map] .. ". " .. c.name .. ": " .. (t and describe(t) or "empty"), true)
end

function M.guide()
  local w, cats, c, t, dist = current()
  if not w or not t then say("Nothing chosen.", true) return end
  if NAV.guiding and NAV.guiding.name == t.name and NAV.guiding.bx == t.bx and NAV.guiding.by == t.by then
    NAV.guiding = nil
    say("Guidance off.", true)
    return
  end
  -- remembered by name and place: a room can have several TECHs
  NAV.guiding = { name = t.name, bx = t.bx, by = t.by, map = w.map, lastPos = w.px .. "," .. w.py }
  local l = t.goal and legs(dist, w, t.goal) or {}
  NAV.guiding.lastLeg = l[1] and l[1].d or nil
  if #l == 0 or not t.goal then
    NAV.guiding = nil
    say(routeText(w, t, dist), true)
  else
    say(t.name .. ": " .. routeText(w, t, dist), true)
  end
end

-- every few frames: say the new room's name, and keep guiding
function M.tick()
  local w = world()
  if NAV.lastMap ~= w.map then
    if NAV.lastMap ~= nil and w.map ~= 0 then (E.sayRoom or say)(MAP_NAMES[w.map] or "", false) end
    NAV.lastMap = w.map
    NAV.cat, NAV.idx = 1, 1
    NAV.guiding = nil
  end
  local g = NAV.guiding
  if not g or w.map == 0 then return end
  local pos = w.px .. "," .. w.py
  if pos == g.lastPos then return end
  g.lastPos = pos
  local cats, dist, prev = categories(w)
  local t
  -- the same-named target nearest where it was (people walk about)
  local bestD
  for _, x in ipairs(cats[1].items) do
    if x.name == g.name then
      local d = math.abs(x.bx - g.bx) + math.abs(x.by - g.by)
      if not bestD or d < bestD then t, bestD = x, d end
    end
  end
  if t then g.bx, g.by = t.bx, t.by end
  if not t then NAV.guiding = nil return end
  if not t.goal then
    say(t.name .. " can't be reached from here.", true)
    NAV.guiding = nil
    return
  end
  local l = legs(dist, w, t.goal)
  if #l == 0 then
    say(routeText(w, t, dist), true)
    NAV.guiding = nil
    return
  end
  -- speak only at a turn, when the way ahead changes direction
  if g.lastLeg ~= l[1].d then
    g.lastLeg = l[1].d
    say(legText(l[1]) .. (#l > 1 and (", then " .. legText(l[2])) or ""), true)
  end
end

-- for the bridge: every target and its route
function M.dump()
  local w = world()
  local cats, dist, prev = categories(w)
  local out = { string.format("map %d (%s) player %d,%d facing %d", w.map,
    MAP_NAMES[w.map] or "?", w.px, w.py, w.facing) }
  for _, c in ipairs(cats) do
    for _, t in ipairs(c.items) do
      out[#out + 1] = c.name .. ": " .. describe(t) .. " -> " .. routeText(w, t, dist)
    end
  end
  return table.concat(out, "\n")
end

M.mapName = function(id) return MAP_NAMES[id] end
return M
end
