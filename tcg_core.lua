-- ============================================================
-- Pokemon Trading Card Game (GBC, USA) - blind accessibility mod
-- by Spacefrag5000. Speaks what is on screen through NVDA (BizHawk's
-- Prism speech bridge). Accessibility only; no game files included.
-- ============================================================
-- How it reads the screen (see PROGRESS.md for the evidence):
-- the game builds text tiles on the fly and keeps a cache in WRAM of
-- which characters each tile holds ($C600+t / $C700+t for tile t).
-- Fixed symbol tiles $00-$30 (energy icons, digits, cursor, borders)
-- are placed straight into the BG map. So every text tile on screen
-- can be turned back into its characters without OCR. Each tile is
-- checked against the font in ROM first, because the cache keeps old
-- entries after a screen switches to pictures.
--
-- When to speak comes from the game's own routines (execution hooks):
-- every cursor wait runs RefreshMenuCursor once per frame, and the
-- duel's main menu runs HandleDuelMenuInput. When one of those starts,
-- the text that is new since the last announcement is spoken, then the
-- item under the cursor. Text that appears with no input wait is
-- spoken once it has stayed unchanged for a moment.
-- ============================================================

-- the folder this file is in, so the mod works from any folder
local ROOT = debug.getinfo(1, "S").source:match("^@(.*[\\/])") or ""
local WORK = ROOT .. "work\\"
os.execute('mkdir "' .. WORK:sub(1, -2) .. '" 2> nul')

-- ---------- memory ----------
local function rb(addr) return memory.read_u8(addr, "System Bus") end
local function rbytes(addr, n, domain)
  return memory.read_bytes_as_array(addr, n, domain or "System Bus")
end

-- ---------- state ----------
local S = { speechOn = true }
local HOOK = { last = {}, count = {} } -- see "execution hooks" below

-- ---------- speech ----------
local function speak(text, interrupt)
  if not S.speechOn or text == nil or text == "" then return end
  pcall(function() speech.output(text, interrupt) end)
end

local function logLine(text)
  local f = io.open(WORK .. "speech_log.txt", "a")
  if f then
    f:write(string.format("[frame %d] %s\n", emu.framecount(), text))
    f:close()
  end
end

-- ---------- the gaps log ----------
-- Anything the mod meets but cannot read yet is written once to
-- work\gaps_log.txt for Claude to work through after play. Nothing is
-- spoken about it ("silence is fine as long as you know what was
-- silent"). Keys already in the file are not written again.
local GAP = { FILE = WORK .. "gaps_log.txt", SNAP_MAX = 6, snaps = 0 }
GAP.note = function(kind, key, detail, snap)
  if not GAP.seen then
    GAP.seen = {}
    local f = io.open(GAP.FILE, "r")
    if f then
      for line in f:lines() do
        local k = line:match("%] (.-) |")
        if k then GAP.seen[k] = true end
      end
      f:close()
    end
  end
  local id = kind .. " " .. key
  if GAP.seen[id] then return end
  GAP.seen[id] = true
  local shot = ""
  if snap and GAP.snaps < GAP.SNAP_MAX then
    GAP.snaps = GAP.snaps + 1
    local name = "gap_" .. os.date("%m%d_%H%M%S")
    if pcall(savestate.save, WORK .. "st_" .. name .. ".State") then shot = " | state st_" .. name end
  end
  local f = io.open(GAP.FILE, "a")
  if f then
    f:write(string.format("[%s frame %d] %s | %s%s\n", os.date("%Y-%m-%d %H:%M"),
      emu.framecount(), id, detail or "", shot))
    f:close()
  end
end

local function say(text, interrupt)
  if text == nil or text == "" then return end
  -- a room's name just said is not cut off by the first text there
  -- (Ronald greeting you at a club's door; see sayRoom)
  local f = emu.framecount()
  if interrupt and S.keepUntil and f <= S.keepUntil and f >= S.keepUntil - 120 then interrupt = false end
  logLine((interrupt and "! " or "") .. text)
  speak(text, interrupt)
end

-- ---------- character tables ----------
-- Half-width ASCII font (the "text" macro). Specials per charmaps.asm.
local HALF = {}
for c = 0x20, 0x7e do HALF[c] = string.char(c) end
-- É and é are given as plain E and e: screen readers say "Pokemon"
-- the same either way, and it keeps the speech text plain ASCII there.
HALF[0x22] = "\"" HALF[0x23] = "≠" HALF[0x24] = "♂" HALF[0x25] = "♀"
HALF[0x40] = "E" HALF[0x60] = "e" HALF[0x7b] = "{" HALF[0x7c] = "¦"
HALF[0x7d] = "}" HALF[0x7e] = "|" HALF[0x7f] = "‾"

-- Full-width charset 3: English letters and symbols.
local FW3 = {}
do
  local up = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  for i = 1, 26 do FW3[0x2f + i] = up:sub(i, i) end
  FW3[0x4a] = "g" FW3[0x4b] = "c" FW3[0x4c] = "m" FW3[0x4d] = "r."
  FW3[0x4e] = "♀" FW3[0x4f] = "♂" FW3[0x50] = "【" FW3[0x51] = "】"
  FW3[0x52] = "●" FW3[0x53] = "◆" FW3[0x54] = "★" FW3[0x55] = "☆"
  FW3[0x56] = "_" FW3[0x57] = "▪" FW3[0x58] = "℃" FW3[0x5a] = "°"
  FW3[0x5c] = "_" FW3[0x5d] = "&" FW3[0x5e] = ":" FW3[0x5f] = "○"
  FW3[0x60] = "※" FW3[0x61] = "o" FW3[0x62] = "^" FW3[0x63] = "♪"
  local lo = "abdefhijklnopqstuvwxyz"
  for i = 1, #lo do FW3[0x63 + i] = lo:sub(i, i) end
  FW3[0x7a] = "'" FW3[0x7b] = "\"" FW3[0x7c] = "■" FW3[0x8e] = "r"
  FW3[0x98] = "\\" FW3[0x9a] = "|" FW3[0x9f] = "#" FW3[0xa0] = "$"
  FW3[0xa1] = "%" FW3[0xa6] = "*" FW3[0xb7] = ";" FW3[0xb8] = "<"
  FW3[0xb9] = "=" FW3[0xba] = ">" FW3[0xbc] = "@" FW3[0xd7] = "["
  FW3[0xd9] = "]"
end

-- Full-width charset 0, codes $60-$79: digits and punctuation.
local FW0 = {}
do
  local t = { "0","1","2","3","4","5","6","7","8","9","+","-","×","/","!","?",
    " ","(",")","「","」","、","。","・","ー","~" }
  for i = 1, #t do FW0[0x5f + i] = t[i] end
end

-- Fixed symbol tiles $00-$30 (TX_SYMBOL). Icons become {tokens} here
-- and are turned into words by speakable(); digits and punctuation are
-- the characters themselves. Box borders become spaces.
local SYM = {
  [0x00] = " ", [0x01] = "{Fire}", [0x02] = "{Grass}", [0x03] = "{Lightning}",
  [0x04] = "{Water}", [0x05] = "{Fighting}", [0x06] = "{Psychic}",
  [0x07] = "{Colorless}", [0x08] = "{Poisoned}", [0x09] = "{Asleep}",
  [0x0a] = "{Confused}", [0x0b] = "{Paralyzed}", [0x0c] = "{up}",
  [0x0d] = "{Pokemon}", [0x0e] = "{attack}", [0x0f] = "{cursor}",
  [0x10] = "{HP}", [0x11] = "Lv", [0x12] = "{E}", [0x13] = "No.",
  [0x14] = "{PlusPower}", [0x15] = "{Defender}", [0x16] = "{hp}", [0x17] = "{dmg}",
  [0x18] = " ", [0x19] = " ", [0x1a] = " ", [0x1b] = " ", [0x1c] = " ",
  [0x1d] = " ", [0x1e] = " ", [0x1f] = " ",
  [0x2a] = ".", [0x2b] = "+", [0x2c] = "-", [0x2d] = " x", [0x2e] = "/",
  [0x2f] = "{more}", [0x30] = "{prize}",
}
for d = 0, 9 do SYM[0x20 + d] = tostring(d) end

-- ---------- fonts from ROM (read once) ----------
local ROM_HALF = 0x1d * 0x4000 + (0x6668 - 0x4000) -- HalfWidthFont, 8 bytes per char from $20
local ROM_SYM = 0x1d * 0x4000 + (0x6968 - 0x4000)  -- SymbolsFont, 16 bytes per tile
local HALF_GLYPH = rbytes(ROM_HALF, 96 * 8, "ROM")  -- 1-indexed
local SYM_GFX = rbytes(ROM_SYM, 0x31 * 16, "ROM")

-- ---------- screen decoding ----------
-- One snapshot of what the decoder needs, read in bulk (a handful of
-- calls instead of thousands).
local function snapshot()
  local v = {}
  v.lcdc = rb(0xff40)
  v.scx, v.scy = rb(0xff43), rb(0xff42)
  v.wx, v.wy = rb(0xff4b) - 7, rb(0xff4a)
  v.vram = rbytes(0x0000, 0x2000, "VRAM")    -- bank 0: tiles + both maps
  v.attr = rbytes(0x3800, 0x0800, "VRAM")    -- bank 1 maps = CGB attributes
  v.vram1 = rbytes(0x2000, 0x1800, "VRAM")   -- bank 1 tiles (icons only)
  v.keys = rbytes(0xc600, 0x200)             -- text tile cache
  v.top = rb(0xffa8)                         -- last text tile in use
  return v
end

local function tileBase(v, t)
  -- returns the 1-based index of the tile's first byte in v.vram
  if (v.lcdc & 0x10) ~= 0 then return t * 16 + 1 end
  if t < 0x80 then return 0x1000 + t * 16 + 1 end
  return 0x0800 + (t - 0x80) * 16 + 1
end

local function halfMatches(v, b, left, right)
  if left < 0x20 or right < 0x20 or left > 0x7f or right > 0x7f then return false end
  local lb, rbase = (left - 0x20) * 8 + 1, (right - 0x20) * 8 + 1
  for r = 0, 7 do
    local want = HALF_GLYPH[lb + r] | (HALF_GLYPH[rbase + r] >> 4)
    if v.vram[b + r * 2] ~= want or v.vram[b + r * 2 + 1] ~= want then return false end
  end
  return true
end

local function symMatches(v, b, t)
  local s = t * 16 + 1
  for i = 0, 15 do
    if v.vram[b + i] ~= SYM_GFX[s + i] then return false end
  end
  return true
end

local function monoTile(v, b)
  for r = 0, 7 do
    if v.vram[b + r * 2] ~= v.vram[b + r * 2 + 1] then return false end
  end
  return true
end

-- ---------- icons ----------
-- Pictures that carry meaning (the deck and hand icons, card type icons
-- in lists...) are recognised by their pixels, since the same tile
-- number holds different pictures on different screens. Key = the
-- tile's 16 bytes as hex. One tile of each icon carries its {Name};
-- the icon's other tiles map to "" so they read as nothing.
local ICONS = {}
do
  local ok, t = pcall(dofile, ROOT .. "tcg_icons.lua")
  if ok and type(t) == "table" then ICONS = t end
end
local function tileKey(v, b)
  local t = {}
  for i = 0, 15 do t[#t + 1] = string.format("%02x", v.vram[b + i]) end
  return table.concat(t)
end

-- The 2x2 card symbols in card lists (home/menus.asm CardSymbolTable),
-- straight from ROM: DuelCgbSymbolGraphics 1d:77f8 and the DMG/SGB set
-- 1d:6fe8, 4 tiles each (top-left, top-right, bottom-left, bottom-right).
-- The name sits on the symbol's bottom row, so the bottom-left tile
-- carries the word. Energy cards' names already say their type, so
-- their symbols read as nothing.
do
  -- Tiles $30-$3f of the same sheets are the face-down cards that show a
  -- Pokemon's stage in the "Pokemon in play" lists and play area screens
  -- (FaceDownCardTileNumbers: one card = Basic, two stacked = Stage 1,
  -- three = Stage 2, twice; LoadDuelFaceDownCardTiles).
  local names = { "{Basic}", "{Stage1}", "{Stage2}", "{Trainer}",
    "", "", "", "", "", "", "", "",
    "{BenchCard}", "{FDStage1}", "{FDStage2}", "{FDStage2}" }
  for _, base in ipairs({ 0x1d * 0x4000 + 0x37f8, 0x1d * 0x4000 + 0x2fe8 }) do
    local gfx = rbytes(base, 0x40 * 16, "ROM")
    for g = 0, 15 do
      for k = 0, 3 do
        local s = (g * 4 + k) * 16
        local t = {}
        for i = 1, 16 do t[i] = string.format("%02x", gfx[s + i]) end
        local key = table.concat(t)
        local word = (k == 2) and names[g + 1] or ""
        if ICONS[key] == nil or ICONS[key] == "" then ICONS[key] = word end
      end
    end
    -- the ACT / BP1-BP5 column of the "choose a Pokemon in play" lists
    -- (LoadDuelCheckPokemonScreenTiles: symbol tiles $40-$49 there =
    -- A,C,T then B,P then the digits 1-5, stacked vertically). The top
    -- tile carries the word; the list position gives the bench number.
    -- deck and discard pile icons of the Play Area / prize screens
    -- (LoadDeckAndDiscardPileIcons: sheet + $54 = hand $d0 unused,
    -- deck $d4, discard pile $d8; 2x2, count on the bottom row)
    local dd = rbytes(base + 0x58 * 16, 8 * 16, "ROM")
    local ddWords = { "", "", "{Deck}", "", "", "", "{Discard}", "" }
    for k = 0, 7 do
      local t = {}
      for i = 1, 16 do t[i] = string.format("%02x", dd[k * 16 + i]) end
      local key = table.concat(t)
      if ICONS[key] == nil or ICONS[key] == "" then ICONS[key] = ddWords[k + 1] end
    end
    -- the opponent's lists use the next 10 tiles (black letters on white,
    -- PrintPlayAreaCardLocation)
    local col = rbytes(base + 0x40 * 16, 20 * 16, "ROM")
    -- (the deck and hand icons follow after this loop)
    local words = { "{Active}", "", "", "{Bench}", "", "", "", "", "", "",
      "{Active}", "", "", "{Bench}", "", "", "", "", "", "" }
    for k = 0, 19 do
      local t = {}
      for i = 1, 16 do t[i] = string.format("%02x", col[k * 16 + i]) end
      local key = table.concat(t)
      if ICONS[key] == nil or ICONS[key] == "" then ICONS[key] = words[k + 1] end
    end
  end
  -- deck and hand icons of the draw-cards screen: DuelOtherGraphics
  -- (1e:4008) + $29 tiles, 8 tiles = deck TL,TR,BL,BR then hand
  -- (LoadDuelDrawCardsScreenTiles). The count sits on the bottom row,
  -- so the bottom-left tile carries the word.
  local g = rbytes(0x1e * 0x4000 + (0x4008 - 0x4000) + 0x29 * 16, 8 * 16, "ROM")
  local words = { "", "", "{Deck}", "", "", "", "{Hand}", "" }
  for k = 0, 7 do
    local t = {}
    for i = 1, 16 do t[i] = string.format("%02x", g[k * 16 + i]) end
    local key = table.concat(t)
    if ICONS[key] == nil or ICONS[key] == "" then ICONS[key] = words[k + 1] end
  end
end

local function textTile(v, t, b)
  -- some screens start their text tiles at $30 (SetupText $30-$bf)
  if t < 0x30 or t > v.top then return nil end
  local k1, k2 = v.keys[t + 1], v.keys[0x100 + t + 1]
  if k1 == 0 and k2 == 0 then return nil end
  if k2 >= 0x20 then
    -- half-width pair: $C700 is the left character, $C600 the right
    if not halfMatches(v, b, k2, k1) then return nil end
    return (HALF[k2] or "?") .. (HALF[k1] or "?")
  end
  if not monoTile(v, b) then return nil end
  if k2 == 3 then
    return FW3[k1] or ("<fw3 %02X>"):format(k1)
  elseif k2 == 0 and k1 >= 0x60 then
    return FW0[k1] or ("<fw0 %02X>"):format(k1)
  end
  return ("<fw%X %02X>"):format(k2, k1)
end

-- The text one tile shows, an icon's {Name}, or nil for pictures.
-- bank1: the CGB attribute says the tile's pixels are in VRAM bank 1,
-- which never holds text.
local function tileText(v, t, bank1)
  local b = tileBase(v, t)
  if bank1 then
    return ICONS[tileKey({ vram = v.vram1 }, b)]
  end
  if t <= 0x30 and symMatches(v, b, t) then return SYM[t] end
  return textTile(v, t, b) or ICONS[tileKey(v, b)]
end

-- Reads the visible 20x18 screen: cells[y][x] (1-based) hold a string
-- or false for pictures; raw[y][x] the tile numbers.
local function readScreen(withKeys)
  local v = snapshot()
  local bgMap = ((v.lcdc & 0x08) ~= 0) and 0x1c00 or 0x1800
  local winOn = (v.lcdc & 0x20) ~= 0
  local winMap = ((v.lcdc & 0x40) ~= 0) and 0x1c00 or 0x1800
  local memo, memo1 = {}, {}
  local cells, raw, keys = {}, {}, {}
  for y = 0, 17 do
    local row, rrow, krow = {}, {}, {}
    for x = 0, 19 do
      local px, py = x * 8, y * 8
      local m
      if winOn and px >= v.wx and py >= v.wy then
        m = winMap + math.floor((py - v.wy) / 8) * 32 + math.floor((px - v.wx) / 8)
      else
        m = bgMap + math.floor(((py + v.scy) % 256) / 8) * 32 + math.floor(((px + v.scx) % 256) / 8)
      end
      local t = v.vram[m + 1]
      rrow[x + 1] = t
      -- CGB attribute bit 3: tile from VRAM bank 1 = never text
      if (v.attr[m - 0x1800 + 1] & 0x08) ~= 0 then
        if memo1[t] == nil then memo1[t] = tileText(v, t, true) or false end
        row[x + 1] = memo1[t]
        if withKeys then krow[x + 1] = "1:" .. tileKey({ vram = v.vram1 }, tileBase(v, t)) end
      else
        if memo[t] == nil then memo[t] = tileText(v, t) or false end
        row[x + 1] = memo[t]
        if withKeys then krow[x + 1] = "0:" .. tileKey(v, tileBase(v, t)) end
      end
    end
    cells[y + 1], raw[y + 1], keys[y + 1] = row, rrow, krow
  end
  return cells, raw, keys
end

-- Cells x1..x2 of a row as raw text (tokens kept), spaces collapsed.
local function cellText(row, x1, x2)
  local parts = {}
  for x = x1 or 1, x2 or 20 do parts[#parts + 1] = row[x] or " " end
  local s = table.concat(parts)
  s = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return s
end

-- Raw row text -> what gets spoken. Icons become words; the HP bar
-- becomes numbers (each circle is 10 HP, damage drawn first).
local ICON_WORDS = {
  Fire = "Fire", Grass = "Grass", Lightning = "Lightning", Water = "Water",
  Fighting = "Fighting", Psychic = "Psychic", Colorless = "Colorless",
  Poisoned = "Poisoned", Asleep = "Asleep", Confused = "Confused",
  Paralyzed = "Paralyzed", Pokemon = "Pokemon", attack = "", HP = "HP",
  E = "Energy:", PlusPower = "PlusPower", Defender = "Defender", prize = "Prizes",
  cursor = "", more = "", up = "",
  Basic = "Basic", Stage1 = "Stage 1", Stage2 = "Stage 2", Trainer = "Trainer",
  Active = "Active", Bench = "Bench", Deck = "Deck", Hand = "Hand", Discard = "Discard pile",
  -- the face-down cards marking a Pokemon's stage (BenchCard is the
  -- one-card Basic picture, also used on the prize screens)
  EmptySlot = "empty", BenchCard = "Basic", FDStage1 = "Stage 1", FDStage2 = "Stage 2",
  CurDeck = "Deck in use:",
}
local function speakable(s)
  -- the stage card sits just before the Energy label in the Pokemon in
  -- play lists: "Basic, Energy: Water", not "Basic Energy"
  s = s:gsub("({BenchCard})%s*{E}", "%1, {E}"):gsub("({FDStage%d})%s*{E}", "%1, {E}")
  -- the Energy label with nothing after it: no Energy attached
  s = s:gsub("{E}%s*$", "no Energy")
  -- a bench slot label with nobody in it
  s = s:gsub("^{Bench}%s*$", "empty bench slot")
  s = s:gsub("{HP}( ?)([{}dmghp]*)", function(sp, bar)
    local rest = bar:gsub("{dmg}", ""):gsub("{hp}", "")
    if bar == "" or rest ~= "" then return "{HP}" .. sp .. bar end
    local _, d = bar:gsub("{dmg}", "")
    local _, h = bar:gsub("{hp}", "")
    return string.format("HP %d of %d", h * 10, (d + h) * 10)
  end)
  s = s:gsub("{(%w+)}", function(w)
    local word = ICON_WORDS[w]
    if word == nil then return w end
    return word == "" and "" or (" " .. word .. " ")
  end)
  -- (a comma at the end is the game's own punctuation: keep it)
  s = s:gsub("%s+", " "):gsub(" ,", ","):gsub("^[ ,]+", ""):gsub(" +$", "")
  return s
end

-- ---------- execution hooks ----------
-- The game's own routines tell us what is on screen right now: each
-- hook records the frame it last ran on. Names start with "tcg_" so a
-- reload can remove the previous run's hooks first.
local HOOKS = {
  tcg_refresh = 0x26da,   -- RefreshMenuCursor: any cursor wait, every frame
  tcg_duelmenu = 0x271a,  -- HandleDuelMenuInput: the duel's main menu
  tcg_cardlist = 0x2626,  -- HandleCardListInput: hand, discard pile...
  -- banked routines: { address, ROM bank } (the hook fires for any
  -- bank mapped at that address, so the bank is checked)
  tcg_island = { 0x4e71, 0x04 }, -- OverworldMap_HandleKeyPress
  -- a duel runs from StartDuel until the overworld takes over again
  -- (wCurMap keeps the room's number all through a duel)
  tcg_duelstart = { 0x40ca, 0x01 }, -- StartDuel
  tcg_duelmain = { 0x426d, 0x01 },  -- DuelMainInterface: each turn's main screen
  tcg_turnloop = { 0x40ee, 0x01 },  -- MainDuelLoop: a turn begins (after setup's coin toss)
  tcg_overworld = { 0x40ce, 0x03 }, -- HandleOverworldMode
  tcg_playarea = { 0x49ae, 0x02 },  -- YourOrOppPlayAreaScreen_HandleInput
  tcg_inplayarea = { 0x43bb, 0x06 }, -- OpenInPlayAreaScreen_HandleInput: Check > IN PLAY AREA
  tcg_mail = { 0x47df, 0x04 },      -- PCMailHandleDPadInput: the PC's mail list
  tcg_config = { 0x46a7, 0x04 },    -- ConfigScreenHandleDPadInput: CONFIG
  tcg_checkmenu = { 0x5065, 0x02 }, -- HandleCheckMenuInput: 2x2 box menus
  -- its twin, same cursor and places: the Auto Deck Machine's BUILD A
  -- DECK / CANCEL / READ THE INSTRUCTIONS and the Play Area screens' menus
  tcg_checkmenu2 = { 0x46ac, 0x02 }, -- HandleCheckMenuInput_YourOrOppPlayArea
  -- deck building (HandleDeckBuildScreen): the card type row, the list
  tcg_deckfilter = { 0x535e, 0x02 }, -- .wait_input
  tcg_decklist = { 0x53d4, 0x02 },   -- .loop_input
  -- the Start menu's CARD screen (HandlePlayersCardsScreen): the same two
  tcg_cardsfilter = { 0x62a2, 0x02 }, -- .wait_input
  tcg_cardslist = { 0x630e, 0x02 },   -- .loop_input
  tcg_albumlist = { 0x698c, 0x02 },   -- CardAlbum.loop_input_3: a set's card list
  tcg_cardselect = { 0x5b25, 0x02 },  -- HandleDeckCardSelectionList: lists of a deck's cards
}
for name, spec in pairs(HOOKS) do
  local addr, bank = spec, nil
  if type(spec) == "table" then addr, bank = spec[1], spec[2] end
  pcall(event.unregisterbyname, name)
  local ok, err = pcall(event.onmemoryexecute, function()
    if bank and memory.read_u8(0xff80, "System Bus") ~= bank then return end
    HOOK.last[name] = emu.framecount()
    HOOK.count[name] = (HOOK.count[name] or 0) + 1
    -- the 2x2 menus' cursor as the input routine saw it: after A, the
    -- duel's Check menu resets it to IN PLAY AREA while the menu is still
    -- on screen (DuelCheckMenu_YourPlayArea), which was said for a moment
    if name == "tcg_checkmenu" or name == "tcg_checkmenu2" then
      HOOK.checkXY = { memory.read_u8(0xceaf, "System Bus"), memory.read_u8(0xceb0, "System Bus") }
    end
  end, addr, name)
  if not ok then logLine("hook " .. name .. " failed: " .. tostring(err)) end
end
-- the deck building screen's card types, in the game's order (CardTypeFilters)
local DECK_FILTERS = { "Grass", "Fire", "Water", "Lightning", "Fighting", "Psychic",
  "Colorless", "Trainer", "Energy" }
local function hookActive(name, f)
  -- the frame counter jumps back on a savestate load or reset, so a
  -- "last" in the future is stale too
  local last = HOOK.last[name] or -100
  return last >= f - 2 and last <= f
end

-- true from a duel's start (or its main screen, after a savestate load)
-- until the overworld or island map runs again
local function inDuel(f)
  local function at(name)
    local last = HOOK.last[name]
    return (last and last <= f) and last or -1
  end
  local d = math.max(at("tcg_duelstart"), at("tcg_duelmain"), at("tcg_duelmenu"))
  local o = math.max(at("tcg_overworld"), at("tcg_island"))
  if d < 0 and o < 0 then
    -- nothing seen since a reload or savestate load: wDuelFinished
    -- ($CC07) is 0 during a duel and stays set after one
    return rb(0xcc07) == 0 and rb(0xc2ee) <= 60 and rb(0xc2bb) ~= 0xff
  end
  return d > o
end

-- ---------- what the player is being asked for ----------
-- Returns nil (no input wait), or a context table:
--   kind "duel" | "menu" | "wait", key (changes when the menu changes),
--   x,y (0-based cursor cell), w (item width in tiles), h (item height
--   in rows: an attack's damage sits on the row under its name),
--   itemRows (set of 1-based rows that hold menu items; they are read
--   as items, not as context).
local DUEL_MENU_XY = { {2, 14}, {2, 16}, {8, 14}, {8, 16}, {14, 14}, {14, 16} }
local textFromId -- defined with the card data below
local inPlayAreaItem -- defined with the Play Area screen below
local PRIZE_PLACES ={ "top left", "top right", "middle left", "middle right", "bottom left", "bottom right" }
local function currentContext(f)
  -- Check > IN PLAY AREA (OpenInPlayAreaScreen, engine/menus/play_area.asm):
  -- both play areas at once, a sprite cursor over the Active Pokemon,
  -- bench cards, hands and discard piles (wInPlayAreaCurPosition $CE52).
  -- The bottom row names what the cursor is on: an item row.
  if hookActive("tcg_inplayarea", f) then
    local pos = rb(0xce52)
    return { kind = "menu", key = "inplayarea", x = pos, y = 0, itemRows = { [18] = true },
      text = inPlayAreaItem(pos) }
  end
  -- choosing a prize card (_SelectPrizeCards, engine/menus/duel.asm): a
  -- sprite cursor over six face-down card places, 2 across and 3 down,
  -- at wYourOrOppPlayAreaCurPosition $CE52; the turn holder's prizes
  -- left are a bit mask (DUELVARS_PRIZES $EC). The prize screen is the
  -- one whose cursor table (wMenuInputTablePointer $CE53) is its own.
  if hookActive("tcg_playarea", f) and (rb(0xce53) | rb(0xce54) << 8) == 0x4b5b then
    local pos = rb(0xce52)
    local has = (rb(rb(0xff97) * 256 + 0xec) >> pos) & 1 == 1
    return { kind = "menu", key = "prize", x = pos, y = 0,
      -- (the cursor skips empty places: it stands on one only for a
      -- moment after that prize was taken, which is not news)
      text = has and ("Prize card, " .. (PRIZE_PLACES[pos + 1] or "?")) or "" }
  end
  -- the deck building screen's menu (CONFIRM MODIFY NAME / SAVE
  -- DISMANTLE CANCEL; the Card Pop "send" one has one row): same input
  -- routine, a sprite cursor moved by a transition table in ROM bank 2,
  -- 7 bytes per place, the first two its sprite x, y (8 and 16 more than
  -- the screen's pixels; the cursor sits one tile left of the item).
  if hookActive("tcg_playarea", f) then
    local tp = rb(0xce53) | rb(0xce54) << 8
    if tp == 0x5679 or tp == 0x61df then
      local xy = rbytes(0x8000 + tp - 0x4000 + rb(0xce52) * 7, 2, "ROM")
      return { kind = "menu", key = string.format("deckcfg %x", tp),
        x = (xy[1] - 8) // 8, y = (xy[2] - 16) // 8, w = 6, h = 1,
        itemRows = { [3] = true, [5] = true } }
    end
    -- the Pokemon Card Glossary (PC and duel Check menu): two columns of
    -- words, 5 rows. No itemRows: turning the page should read the new
    -- page's words, as a sighted player sees them all at once.
    if tp == 0x4c8e then
      local xy = rbytes(0x8000 + tp - 0x4000 + rb(0xce52) * 7, 2, "ROM")
      return { kind = "menu", key = "glossary",
        x = (xy[1] - 8) // 8, y = (xy[2] - 16) // 8, w = 9, h = 1 }
    end
  end
  -- the deck building screen's row of card type pictures, each with the
  -- deck's count of that type under it: a down-arrow cursor above them,
  -- wCardListCursorPos $CEA4 (0-8, the order of CardTypeFilters); counts
  -- in wCardFilterCounts $CEBB
  -- the same row of pictures on the Start menu's CARD screen (all your
  -- cards, HandlePlayersCardsScreen): no counts under them there
  -- (the picture row and the list below share $CEA4: for the 2 frames
  -- after moving between them, only the newer of the two counts, or
  -- the list's 0 was said as "Grass")
  local function newer(a, b) return (HOOK.last[a] or -1) >= (HOOK.last[b] or -1) end
  if hookActive("tcg_cardsfilter", f) and newer("tcg_cardsfilter", "tcg_cardslist") then
    local k = rb(0xcea4)
    return { kind = "menu", key = "cardsfilter", x = 1 + 2 * k, y = 1, itemRows = { [2] = true }, keepItem = true,
      text = DECK_FILTERS[k + 1] or "?", pos = string.format("%d of %d", k + 1, #DECK_FILTERS) }
  end
  -- the card list under the pictures (deck building: from row 7, the CARD
  -- screen: from row 5; 2 rows apart). Cursor wCardListCursorPos $CEA4,
  -- scrolled by wCardListVisibleOffset $CEA1, wNumCardListEntries $CFE6
  -- cards in the list. The count beside each name is read too.
  local lx, ly
  if hookActive("tcg_decklist", f) and newer("tcg_decklist", "tcg_deckfilter") then lx, ly = 0, 7
  elseif hookActive("tcg_cardslist", f) then lx, ly = 1, 5
  elseif hookActive("tcg_albumlist", f) then lx, ly = 1, 4 end -- the card album (PC)
  if lx then
    local cur = rb(0xcea4)
    local rows = {}
    for y = ly, 17 do rows[y + 1] = true end
    return { kind = "menu", key = "cardpick " .. ly, x = lx, y = ly + 2 * cur, w = 19 - lx, h = 1,
      itemRows = rows, fields = true,
      pos = string.format("%d of %d", rb(0xcea1) + cur + 1, rb(0xcfe6)) }
  end
  if hookActive("tcg_deckfilter", f) then
    local k = rb(0xcea4)
    -- (the card list below changes with it: that is not a reason to say
    -- the type again after the list)
    return { kind = "menu", key = "deckfilter", x = 1 + 2 * k, y = 1, itemRows = { [2] = true }, keepItem = true,
      text = string.format("%s, %d card%s", DECK_FILTERS[k + 1] or "?", rb(0xcebb + k), rb(0xcebb + k) == 1 and "" or "s"),
      pos = string.format("%d of %d", k + 1, #DECK_FILTERS) }
  end
  -- any other list of a deck's cards (HandleDeckCardSelectionList): the
  -- Auto Deck Machine's READ THE INSTRUCTIONS and deck lists, the Deck
  -- Machine's... Its place comes from InitCardSelectionParams: column
  -- wCardListCursorXPos $CEA5, row $CEA6, rows apart $CEA7, places on
  -- screen $CEA9. A text box under the list is still read.
  if hookActive("tcg_cardselect", f) and rb(0xcea8) == 0 then
    local cur, lx, ly, sep = rb(0xcea4), rb(0xcea5), rb(0xcea6), math.max(1, rb(0xcea7))
    local rows = {}
    for y = ly, math.min(17, ly + sep * rb(0xcea9) - 1) do rows[y + 1] = true end
    return { kind = "menu", key = "cardselect " .. ly, x = lx, y = ly + sep * cur, w = 19 - lx, h = 1,
      itemRows = rows, fields = true,
      pos = string.format("%d of %d", rb(0xcea1) + cur + 1, rb(0xcfe6)) }
  end
  -- the PC's mail list (_PCMenu_ReadMail, engine/menus/mail.asm): up to
  -- 15 mails, 3 across and 5 down, drawn as names (Mail1Text.. = text
  -- IDs $35d..); wPCPackSelection $D11D is the cursor, wPCPacks $D11E
  -- the mails (0 = none, bit 7 = unread: its name blinks). The blinking
  -- names are item rows, so they are not news.
  if hookActive("tcg_mail", f) then
    local sel = rb(0xd11d)
    local unread = rb(0xd11e + sel) & 0x80 ~= 0
    local rows = {}
    for y = 3, 11 do rows[y] = true end
    return { kind = "menu", key = "mail", x = sel, y = 0, itemRows = rows,
      text = textFromId(0x35d + sel) .. (unread and ", unread" or "") }
  end
  -- CONFIG (_PauseMenu_Config, engine/menus/config.asm): three rows,
  -- wConfigCursorYPos $D11B; each setting keeps its own cursor on its
  -- choice (message speed $D118: 0-4 = 1-5; duel animation $D119),
  -- moved with left/right. The words are the screen's own.
  if hookActive("tcg_config", f) then
    local row = rb(0xd11b)
    local text
    if row == 0 then text = "MESSAGE SPEED: " .. (rb(0xd118) + 1)
    elseif row == 1 then
      text = "DUEL ANIMATION: " .. (({ [0] = "SHOW ALL", "SKIP SOME", "NONE" })[rb(0xd119)] or "?")
    else text = "EXIT SETTINGS" end
    return { kind = "menu", key = "config", x = row, y = 0, text = text }
  end
  -- 2x2 menus in the bottom text box (HandleCheckMenuInput,
  -- engine/menus/deck_check.asm): the deck submenu (MODIFY DECK...),
  -- the Deck Machine's submenu and the duel's Check menu. Cursor at
  -- wCheckMenuCursorXPosition $CEAF / YPosition $CEB0, drawn at column
  -- 1 + 10x, row 14 + 2y. The deck list's cursor stays drawn above it,
  -- so the on-screen fallback would read the wrong one.
  -- (HandleCheckMenuInput_YourOrOppPlayArea, engine/menus/duel.asm, works
  -- the same way.) A left item with nothing to its right can run past
  -- the second column (READ THE INSTRUCTIONS): then the whole row is read.
  local check2 = hookActive("tcg_checkmenu2", f)
  if hookActive("tcg_checkmenu", f) or check2 then
    local cx, cy = HOOK.checkXY[1], HOOK.checkXY[2]
    local y = 14 + 2 * cy
    local w = (cx == 0 and memory.read_u8(0x1800 + y * 32 + 11, "VRAM") >= 0x30) and 19 or 9
    -- (the twin's menus were read whole on arrival before it had a hook:
    -- they still are)
    return { kind = "menu", key = check2 and "check2" or "check", x = 1 + 10 * cx, y = y, w = w, h = 1,
      itemRows = { [15] = true, [17] = true }, listOnArrival = check2 }
  end
  if hookActive("tcg_duelmenu", f) then
    local item = rb(0xcd10)
    local xy = DUEL_MENU_XY[item + 1] or DUEL_MENU_XY[1]
    return { kind = "duel", key = "duel", x = xy[1], y = xy[2], w = 5, h = 1,
      itemRows = { [15] = true, [17] = true } }
  end
  if hookActive("tcg_refresh", f) then
    local item, cx, cy, sep, num, vis = rb(0xcd10), rb(0xcd11), rb(0xcd12), rb(0xcd13), rb(0xcd14), rb(0xcd15)
    if vis == 0x2f then
      return { kind = "wait", key = string.format("wait %d %d", cx, cy) }
    end
    if sep == 0 and num == 1 and cx == 0 then
      -- a cursor pointing at one thing, waiting for A
      -- (SetCursorParametersForTextBox_Default): after an opponent's
      -- card or attack changed one of your Pokemon (Energy Removal,
      -- DrawPlayAreaScreenToShowChanges), it points at that Pokemon in
      -- the list, 3 rows each. That Pokemon is the news, not the list.
      return { kind = "menu", key = string.format("point %d", cy), x = 0, y = cy, w = 19, h = 3,
        itemRows = { [cy + 1] = true, [cy + 2] = true, [cy + 3] = true }, point = true }
    end
    if sep == 0 then
      -- two items side by side (Yes/No): the cursor X moves 4 tiles
      return { kind = "menu", key = string.format("h %d", cy), x = cx, y = cy, w = 3, h = 1,
        itemRows = { [cy + 1] = true } }
    end
    local rows = {}
    for k = 0, num - 1 do
      for r = 0, sep - 1 do rows[cy + k * sep + r + 1] = true end
    end
    -- position in the list, as a sighted player sees it: card lists
    -- (hand, discard pile...) count across pages
    local pos, total = item + 1, num
    local cardlist = hookActive("tcg_cardlist", f)
    if cardlist then
      pos, total = rb(0xcd19) + item + 1, rb(0xcd1b)
    end
    return { kind = "menu", key = string.format("v %d %d %d %d", rb(0xcd11), cy, sep, num),
      x = cx, y = cy + item * sep, w = 19 - cx, h = sep, itemRows = rows, cardlist = cardlist,
      pos = (total > 1) and string.format("%d of %d", pos, total) or nil }
  end
  return nil
end

-- Menus with their own input code (the duel's Check menu, deck
-- screens...) still draw the same cursor symbol, so as a fallback the
-- cursor is found on screen. It blinks, so it counts as present for a
-- while after it was last seen.
local VCURSOR_HOLD = 40
local function findCursor(cells)
  for y = 1, 18 do
    for x = 1, 20 do
      if cells[y][x] == "{cursor}" then return x - 1, y - 1 end
    end
  end
  return nil
end

-- Item text right of a cursor found on screen: skip pictures and
-- spaces, then read until a gap of two blank cells (the next column).
local function blankCell(c) return not c or c:match("^%s*$") ~= nil end
local function visualItem(cells, x, y)
  local row = cells[y + 1]
  local i = x + 2
  while i <= 20 and blankCell(row[i]) do i = i + 1 end
  -- a grid of one-tile items with one blank between them (letters on
  -- the name screen): the item is that one tile
  if i + 3 <= 20 and not blankCell(row[i]) and blankCell(row[i + 1])
    and not blankCell(row[i + 2]) and blankCell(row[i + 3]) then
    return speakable(row[i])
  end
  local parts, gap = {}, 0
  while i <= 20 do
    if blankCell(row[i]) then
      gap = gap + 1
      if gap >= 2 then break end
      parts[#parts + 1] = " "
    else
      gap = 0
      parts[#parts + 1] = row[i]
    end
    i = i + 1
  end
  return speakable(table.concat(parts))
end

-- ---------- narrator ----------
-- Rows are spoken when they are new: changed since they were last
-- announced ("dirty"). In a menu, a dirty row whose text is the same as
-- when this menu was last announced is not repeated, so coming back to
-- a menu says only the item and whatever really changed. Text boxes
-- ("wait") always say their dirty rows, since a new page can repeat a
-- line.
local N = {
  spoken = {},        -- menu key -> row texts as last announced there
  dirty = {},         -- row -> true if it changed since last announced
  prevRows = nil,     -- row texts on the previous check
  lastChange = 0,     -- frame the screen text last changed
  ctxKey = nil,       -- context key on the previous check
  itemKey = nil,      -- last item spoken
  lastPress = -100,   -- frame of the player's last button press
  quietDone = -1,     -- lastChange value already announced with no context
  duelLine = {},      -- "Opponent"/"You" -> that status line as last said
}
local STABLE_FRAMES = 24 -- text with no input wait: spoken once still this long
local SETTLE_FRAMES = 8  -- a menu's screen must be still this long first (text
                         -- printing letter by letter pauses up to ~6 frames)

-- ---------- game text and cards from ROM ----------
-- Text IDs index TextOffsets (0d:4000, 3 bytes each); see
-- GetTextOffsetFromTextID in home/print_text.asm.
local function romAt(bank, addr) return bank * 0x4000 + (addr - 0x4000) end
local function romByte(bank, addr) return memory.read_u8(romAt(bank, addr), "ROM") end
local function romWord(bank, addr) return romByte(bank, addr) + romByte(bank, addr + 1) * 256 end

function textFromId(id)
  if not id or id == 0 then return "" end
  local o = romAt(0x0d, 0x4000 + id * 3)
  local b0, b1, b2 = memory.read_u8(o, "ROM"), memory.read_u8(o + 1, "ROM"), memory.read_u8(o + 2, "ROM")
  local bank = (0x0d + (((b2 << 2) | (b1 >> 6)) & 0xff)) & 0xff
  local p = romAt(bank, 0x4000 + (((b1 & 0x3f) << 8) | b0))
  local out, half, n = {}, false, 0
  while n < 400 do
    local c = memory.read_u8(p, "ROM")
    p, n = p + 1, n + 1
    if c == 0 then break
    elseif c == 0x06 then half = true
    elseif c == 0x07 then half = false
    elseif c == 0x0a then out[#out + 1] = "\n"
    elseif c == 0x09 or c == 0x0b or c == 0x0c then out[#out + 1] = "..."
    elseif half then out[#out + 1] = HALF[c] or "?"
    elseif c >= 1 and c <= 4 then
      local ch = memory.read_u8(p, "ROM")
      p = p + 1
      out[#out + 1] = (c == 3) and (FW3[ch] or "?") or "?"
    elseif c == 0x05 then
      out[#out + 1] = SYM[memory.read_u8(p, "ROM")] or ""
      p = p + 1
    elseif c >= 0x60 then out[#out + 1] = FW0[c] or "?"
    end
  end
  return table.concat(out)
end

local CARD_POINTERS = 0x4c5c -- bank 0c
local function cardData(cardId)
  if not cardId or cardId == 0 then return nil end
  local ptr = romWord(0x0c, CARD_POINTERS + cardId * 2)
  if ptr < 0x4000 then return nil end
  return {
    ptr = ptr,
    type = romByte(0x0c, ptr),
    name = textFromId(romWord(0x0c, ptr + 3)),
    hp = romByte(0x0c, ptr + 8),
    stage = romByte(0x0c, ptr + 9),
  }
end

-- duelist = "player" or "opp": duel variables at $C200 / $C300, card
-- IDs of each deck index at $C400 / $C480
local function duelVars(duelist) return duelist == "player" and 0xc200 or 0xc300 end
local function deckCardId(duelist, idx)
  return rb((duelist == "player" and 0xc400 or 0xc480) + idx)
end
local STAGES = { [0] = "Basic", [1] = "Stage 1", [2] = "Stage 2" }


-- ---------- the duel's main scene ----------
-- The top of the screen is the opponent's Active Pokemon, the middle
-- yours; a sighted player knows whose is whose from where it sits. So
-- the two halves are read as one labelled line each instead of as rows
-- (layout from DrawDuelMainScene / DrawDuelHUD, engine/duel/core.asm):
--   opponent: info row 0 (bench count, prizes, name), Energy row 1
--   from x 3, HP bar rows 2-3 from x 3 (6 per row), PlusPower/Defender
--   row 2 from x 9, status icons row 6 x 9-11.
--   you: name row 11 x 0-14, bench/prizes row 11 x 15-18, Energy row 8
--   from x 11, HP bar rows 9-10 from x 11, PlusPower/Defender row 9
--   from x 17, status icons row 5 x 8-10.
local function isDuelMainScene(cells)
  return cells[2][2] == "{E}" and cells[3][2] == "{HP}"
    and cells[9][10] == "{E}" and cells[10][10] == "{HP}"
end

local function hpBar(cells, y, x)
  local d, h = 0, 0
  for r = 0, 1 do
    for i = 0, 5 do
      local c = cells[y + r + 1][x + i + 1]
      if c == "{dmg}" then d = d + 1 elseif c == "{hp}" then h = h + 1 end
    end
  end
  if d + h == 0 then return nil end
  return string.format("HP %d of %d", h * 10, (d + h) * 10)
end

local function energyList(cells, y, x1, x2)
  local t = {}
  for x = x1, x2 do
    local c = cells[y + 1][x + 1]
    local w = c and c:match("^{(%a+)}$")
    if w then t[#t + 1] = w end
  end
  return #t > 0 and ("Energy: " .. table.concat(t, ", ")) or "no Energy"
end

local function iconsIn(cells, y, x1, x2)
  return speakable(cellText(cells[y + 1], x1 + 1, x2 + 1))
end

-- "{Pokemon}0{prize}2 ..." -> bench count, prizes, rest of the text
local function benchPrizes(s)
  local bench = s:match("{Pokemon}(%d)")
  local prizes = s:match("{prize}(%d)")
  local rest = s:gsub("{Pokemon}%d", ""):gsub("{prize}%d", "")
  return bench, prizes, rest
end

local function duelSide(label, info, cells, eY, eX, hpY, hpX, ppY, ppX, stY, stX)
  local bench, prizes, name = benchPrizes(info)
  local parts = { label .. " " .. speakable(name) }
  parts[#parts + 1] = hpBar(cells, hpY, hpX)
  parts[#parts + 1] = energyList(cells, eY, eX, 19)
  local st = iconsIn(cells, stY, stX, stX + 2)
  if st ~= "" then parts[#parts + 1] = st end
  local pp = iconsIn(cells, ppY, ppX, ppX + 2)
  if pp ~= "" then parts[#parts + 1] = pp end
  if bench then parts[#parts + 1] = "Bench " .. bench end
  if prizes then parts[#parts + 1] = "Prizes " .. prizes end
  return table.concat(parts, ", ") .. "."
end

-- rows 1-12 (1-based) of the main scene as two labelled lines
local function duelSceneRows(cells, t)
  local opp = duelSide("Opponent:", cellText(cells[1]), cells, 1, 3, 2, 3, 2, 9, 6, 9)
  local you = duelSide("You:", cellText(cells[12]), cells, 8, 11, 9, 11, 9, 17, 5, 8)
  for y = 1, 12 do t[y] = "" end
  t[1], t[12] = opp, you
end

-- ---------- the Play Area screen (Check > Your/Opp. Play Area) ----------
-- Mostly pictures: face-down prize cards, the Active Pokemon's art,
-- deck / discard pile / hand counts beside icons, and the bench as
-- face-down cards marked with their stage (or empty frames). Drawn by
-- _DrawYourOrOppPlayAreaScreen (engine/menus/duel.asm); the same facts
-- come from the duel variables. Rows 2-12 (1-based) are replaced.
local function popcount(n)
  local c = 0
  while n > 0 do c = c + (n & 1) n = n >> 1 end
  return c
end

local function cardNameLv(duelist, idx)
  local cd = cardData(deckCardId(duelist, idx))
  if not cd then return "?" end
  local lv = (cd.type < 8) and romByte(0x0c, cd.ptr + 0x39) or nil
  -- names are shown in capitals in duels
  return cd.name:upper() .. (lv and lv > 0 and (" LV" .. lv) or "")
end

local function playAreaRows(t, duelist)
  duelist = duelist or ((rb(0xce50) == 0xc2) and "player" or "opp")
  local v = duelVars(duelist)
  local active = rb(v + 0xbb)
  local bench, empty = {}, 0
  for i = 0, 4 do
    if rb(v + 0xbc + i) == 0xff then empty = empty + 1
    else bench[#bench + 1] = STAGES[rb(v + 0xcf + i)] or "?" end
  end
  local benchText = table.concat(bench, ", ")
  if #bench == 0 then benchText = "empty"
  elseif empty > 0 then benchText = benchText .. string.format(", %d empty", empty) end
  for y = 2, 12 do t[y] = "" end
  t[2] = string.format("Prizes %d.", popcount(rb(v + 0xec)))
  t[3] = "Active: " .. (active ~= 0xff and cardNameLv(duelist, active) or "none") .. "."
  t[4] = string.format("Deck %d. Discard pile %d. Hand %d.",
    60 - rb(v + 0xba), rb(v + 0xed), rb(v + 0xee))
  t[5] = "Bench: " .. benchText .. "."
end

-- The IN PLAY AREA screen: the turn holder's side is at the bottom.
-- What the cursor is on, as the bottom row names it, plus whose and
-- where (a sighted player sees where the cursor stands).
local function cardsWord(n) return n .. (n == 1 and " card" or " cards") end
function inPlayAreaItem(pos)
  local turn = (rb(0xff97) == 0xc3) and "opp" or "player"
  local other = (turn == "player") and "opp" or "player"
  local d = (pos <= 7) and turn or other
  local who = (d == "player") and "your" or "opponent's"
  local v = duelVars(d)
  local slot -- 0 = Active, 1-5 = bench
  if pos <= 4 then slot = pos + 1
  elseif pos == 5 or pos == 8 then slot = 0
  elseif pos >= 11 and pos <= 15 then slot = pos - 10 end
  if slot then
    local idx = rb(v + 0xbb + slot)
    local name = (idx ~= 0xff) and cardNameLv(d, idx) or "empty"
    return name .. ", " .. who .. (slot == 0 and " Active Pokemon" or (" Bench " .. slot))
  end
  local Who = who:sub(1, 1):upper() .. who:sub(2)
  if pos == 6 or pos == 9 then return Who .. " Hand, " .. cardsWord(rb(v + 0xee)) end
  if pos == 7 or pos == 10 then return Who .. " discard pile, " .. cardsWord(rb(v + 0xed)) end
  return ""
end

-- The IN PLAY AREA screen's pictures as two lines, opponent (top) first
local function inPlayAreaRows(t)
  local turn = (rb(0xff97) == 0xc3) and "opp" or "player"
  local other = (turn == "player") and "opp" or "player"
  local function line(d)
    local s = {}
    playAreaRows(s, d)
    return (d == "player" and "You: " or "Opponent: ") .. table.concat({ s[2], s[3], s[4], s[5] }, " ")
  end
  for y = 1, 17 do t[y] = "" end
  t[1], t[9] = line(other), line(turn)
end

-- H / Shift+H: your or the opponent's card counts, as the draw screen
-- and Play Area show them (Spacefrag, 2026-10-20: these were said on
-- every draw; the hand itself he reads from the HAND menu).
local function countsText(duelist)
  local v = duelVars(duelist)
  return string.format("%sHand %d, Deck %d, Discard pile %d, Prizes %d.",
    duelist == "opp" and "Opponent: " or "", rb(v + 0xee), 60 - rb(v + 0xba),
    rb(v + 0xed), popcount(rb(v + 0xec)))
end

-- A row as text where a gap of two or more blank cells between two
-- pieces of text becomes ", ": such gaps separate fields or columns
-- ("RESISTANCE" and the card's "No.119" share a row), never words.
local function blankish(c) return not c or c:match("^%s*$") ~= nil end
local function rowText(row)
  local parts, gap = {}, 0
  for x = 1, 20 do
    local c = row[x]
    if c == "{cursor}" or c == "{more}" then c = nil end
    if blankish(c) then
      gap = gap + 1
    else
      if #parts > 0 then parts[#parts + 1] = (gap >= 2) and ", " or ((gap == 1) and " " or "") end
      parts[#parts + 1] = c
      gap = 0
    end
  end
  return (table.concat(parts):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local MEDALS = { "Grass Club", "Science Club", "Fire Club", "Water Club",
  "Lightning Club", "Psychic Club", "Rock Club", "Fighting Club" }
local function rowsOf(cells, live)
  local t = {}
  for y = 1, 18 do
    -- the blinking cursor and "more" arrows are not text changes
    t[y] = rowText(cells[y])
  end
  -- the deck building screen: card type pictures on rows 2-3 (0-based)
  -- with the deck's count of each type under them on row 4, printed as
  -- one run of digits (PrintCardTypeCounts). Said as one line of names
  -- and counts instead. (Its menu covers these rows: then row 4 is words.)
  local f = emu.framecount()
  local lastDeck = math.max(HOOK.last.tcg_deckfilter or -1000, HOOK.last.tcg_decklist or -1000)
  if lastDeck <= f and f - lastDeck < 90 and t[5]:match("^[%d ]+$") then
    local parts, counts = {}, {}
    for k, name in ipairs(DECK_FILTERS) do
      counts[k] = rb(0xcebb + k - 1)
      parts[k] = name .. " " .. counts[k]
    end
    local line = table.concat(parts, ", ")
    -- adding or removing a card changes one count: only that one is
    -- said ("Fire 9"), not all nine again. T reads them all.
    local prev = N.typeLine
    if not live then
      local key = table.concat(counts, ",")
      -- (within half a minute: a card page looked at in between is not
      -- a new visit)
      local fresh = prev and prev.f <= f and f - prev.f < 1800
      if fresh and prev.key == key then
        line = prev.text
      elseif fresh then
        local changed = {}
        for k, name in ipairs(DECK_FILTERS) do
          if counts[k] ~= prev.counts[k] then changed[#changed + 1] = name .. " " .. counts[k] end
        end
        line = table.concat(changed, ", ")
      end
      N.typeLine = { key = key, counts = counts, text = line, f = f }
    end
    t[3], t[4], t[5] = line, "", ""
  end
  -- the CARD screen's row of type pictures (no counts): their names
  local lastCards = math.max(HOOK.last.tcg_cardsfilter or -1000, HOOK.last.tcg_cardslist or -1000)
  if lastCards <= f and f - lastCards < 90 and t[3] == "" and t[4] == "{Trainer}" then
    t[3], t[4] = table.concat(DECK_FILTERS, ", "), ""
  end
  -- a Pokemon card page: the card's number shares the RESISTANCE row
  -- ("RESISTANCE, No. 58" sounded like a resistance of No. 58): the
  -- number moves to the empty box-border row below. An empty weakness or
  -- resistance is blank on screen: said as "none".
  for y = 1, 18 do
    if t[y] == "WEAKNESS" then
      t[y] = "WEAKNESS, none"
    elseif t[y] == "RETREAT COST" then
      t[y] = "RETREAT COST, none"
    elseif t[y]:match("^RESISTANCE") then
      local res, num = t[y]:match("^RESISTANCE(.-)(No%..*)$")
      if num and y < 18 and t[y + 1] == "" then
        res = res:gsub("^[, ]+", ""):gsub("[, ]+$", "")
        t[y], t[y + 1] = "RESISTANCE, " .. (res == "" and "none" or res), num
      end
    end
  end
  -- name entry (input_name.asm): the question and the name typed so far
  -- share a row ("WHAT IS YOUR NAME?, AN____"), so every letter repeated
  -- the question. The name moves to the blank row below, without its
  -- empty places, so typing says only the name.
  for y = 1, 17 do
    local q, name = t[y]:match("^(.+), (%S*_+)$")
    if q and t[y + 1] == "" then
      local typed = name:gsub("_+$", "")
      t[y], t[y + 1] = q, (typed ~= "" and typed or name)
      t.nameRow = y + 1 -- (typing is not a new screen: the letter under the cursor is not said again)
      break
    end
  end
  -- the medals under "MASTER MEDALS" (Start menu STATUS, and the medal
  -- won screen) are pictures, one place each in the game's order
  -- (DrawCollectedMedals, MedalCoordsAndTilemaps: two rows of four
  -- under the title, 5 tiles apart); a medal not won leaves its place blank
  for y = 1, 13 do
    if t[y] == "MASTER MEDALS" then
      local won = {}
      for i, name in ipairs(MEDALS) do
        local row = cells[y + 1 + ((i > 4) and 4 or 0)]
        if row and row[2 + ((i - 1) % 4) * 5] == false then won[#won + 1] = name end
      end
      t[y] = "MASTER MEDALS, " .. (#won > 0 and table.concat(won, ", ") or "none")
      break
    end
  end
  -- the "placing the prizes" screen: opponent's hand, discard pile and
  -- deck top left, yours bottom right (DrawPlayAreaToPlacePrizeCards)
  -- Spoken: only what the opponent has out, as a sighted player sees it
  -- (an Active card and bench cards, all face down; Spacefrag,
  -- 2026-10-20: the counts and his own side, which he just set, were too
  -- much). The deck counts ticking down as prizes are dealt are not news
  -- either. T still reads everything.
  if t[1]:match("^HAND") and t[12] and t[12]:match("HAND") then
    if live then
      t[1] = "Opponent: " .. t[1]
      for y = 7, 11 do
        if t[y]:match("Deck") then t[y] = "You: " .. t[y] break end
      end
    else
      local _, cards = t[2]:gsub("{BenchCard}", "")
      local _, empty = t[2]:gsub("{EmptySlot}", "")
      for y = 1, 12 do t[y] = "" end
      t[1] = "Opponent: Active Pokemon face down. " .. (cards == 0 and "Bench empty."
        or string.format("Bench: %d Pokemon face down, %d empty.", cards, empty))
    end
  end
  -- the draw-cards screen: the opponent's hand and deck counts on row 3,
  -- yours on row 10 (DeckAndHandIconsTileData, engine/duel/core.asm).
  -- While cards fly over, the counts tick up one card at a time; the
  -- narrator says only who drew, once the draw is over (Spacefrag,
  -- 2026-10-17: the names, the counts before and "DRAW 1 CARD(S)" every
  -- turn were too much; T still reads it all; 2026-10-20: the counts
  -- after moved to H / Shift+H too). wNumCardsBeingDrawn
  -- $CBE9 runs up to 7 when each player draws a hand, or up to
  -- wNumCardsTryingToDraw $CBE8 when drawing during a turn.
  local screen = rb(0xcac2) -- wDuelDisplayedScreen
  if (screen == 0x07 or screen == 0x09) and t[4]:match("{Hand}") and t[11]:match("{Hand}") then
    local function counts(s)
      return tonumber(s:match("{Hand}[^%d]*(%d+)")), tonumber(s:match("{Deck}[^%d]*(%d+)"))
    end
    local oh, od = counts(t[4])
    local yh, yd = counts(t[11])
    if oh and od and yh and yd then
      local drawn = rb(0xcbe9)
      local target = (screen == 0x09) and 7 or rb(0xcbe8)
      if live then
        t[4] = string.format("Opponent: Hand %d, Deck %d.", oh, od)
        t[11] = string.format("You: Hand %d, Deck %d.", yh, yd)
      else
        t.drawScreen = true
        if drawn == 0 then N.drawBase = { oh, yh } end
        t[4], t[11] = "", ""
        local base = N.drawBase
        if drawn > 0 and drawn >= target and base then
          local function drew(label, h, d, h0)
            if h <= h0 then return "" end
            return string.format("%s drew %d card%s.", label, h - h0, (h - h0 == 1) and "" or "s")
          end
          t[4] = drew("Opponent", oh, od, base[1])
          t[11] = drew("You", yh, yd, base[2])
        end
      end
    end
  elseif not live then
    N.drawBase = nil
  end
  if isDuelMainScene(cells) then
    -- damage to an Active Pokemon is shown on this scene. Its HP bar
    -- drops a moment AFTER the message appears: the game takes the HP
    -- off only once the animation and its message are done
    -- (PlayAttackAnimation_DealAttackDamage: WaitAttackAnimation, then
    -- SubtractHP and DrawDuelHUDs, with the message still up). So the
    -- message is said as it is, and when the bar drops, the HP it now
    -- shows is said on its own: "DUGTRIO LV36 TOOK / 20 DAMAGE." then
    -- "HP 20 of 70." (Spacefrag, 2026-10-25; at first both lines carried
    -- an HP, the first one still the old one). The bar on screen is read,
    -- so it says exactly what a sighted player sees. Damage to the bench
    -- plays on the play area screen, which shows no HP: nothing added.
    local found = false
    for y = 13, 17 do
      local name = t[y]:match("^(.-) TOOK$") or t[y]:match("^(.-) RECEIVED$")
      if name then
        for y2 = y + 1, 17 do
          if t[y2]:match("DAMAGE") then
            -- whose Active it is: the name on that side's HUD row
            local bar
            if cellText(cells[1]):find(name, 1, true) then bar = hpBar(cells, 2, 3)
            elseif cellText(cells[12]):find(name, 1, true) then bar = hpBar(cells, 9, 11) end
            if bar then
              found = true
              local key = name .. "|" .. t[y2]
              local m = N.dmgMsg
              if not (m and m.key == key) then
                m = { key = key, before = bar }
                if not live then N.dmgMsg = m end
              end
              -- the row under the message (the box's bottom edge) is empty
              if bar ~= m.before and t[y2 + 1] == "" then t[y2 + 1] = bar .. "." end
            end
            break
          elseif t[y2] ~= "" then break end
        end
        break
      end
    end
    -- (the message gone: the same damage next time starts afresh)
    if not found and not live then N.dmgMsg = nil end
    duelSceneRows(cells, t)
    t.duelScene = true
  elseif hookActive("tcg_inplayarea", f) then
    inPlayAreaRows(t)
  elseif hookActive("tcg_checkmenu", f) and HOOK.last.tcg_inplayarea
    and HOOK.last.tcg_inplayarea <= f and f - HOOK.last.tcg_inplayarea < 3600 then
    -- back in the Check menu from IN PLAY AREA: that screen's pictures
    -- stay drawn above the menu until the duel scene returns ("x 6",
    -- "Deck x51"...). Nothing new there.
    for y = 1, 12 do t[y] = "" end
  elseif t[1]:match("'S PLAY AREA$") then
    -- (wDuelDisplayedScreen reads 0 on this screen, so the title is the test)
    -- Said only when opened from the Check menu (its menu of YOUR/OPP.
    -- POKEMON ... DISCARD PILE is under it, YourPlayAreaMenuData). Shown
    -- by the game on its own (an attack hitting the bench, the prize
    -- choice) it stays quiet: P / Shift+P read it any time (Spacefrag,
    -- 2026-10-20).
    -- (the prize choice runs the same input routine with its own cursor
    -- table, $4b5b: quiet, the cursor says which prize)
    local prizeChoice = (rb(0xce53) | rb(0xce54) << 8) == 0x4b5b
    if live or (hookActive("tcg_playarea", f) and not prizeChoice)
      or (t[15]:match("POKEMON") and t[17]:match("DISCARD PILE")) then
      playAreaRows(t)
      t.playArea = true
    else
      for y = 1, 12 do t[y] = "" end
    end
  end
  return t
end

-- The hand list (title "...'S HAND" on row 1, 0-based) with a text box
-- over its bottom (rows 12-17), as while Dr. Mason coaches
local function handBehindBox(rows)
  if not rows[2]:match("'S HAND") then return false end
  for y = 13, 18 do
    if rows[y] ~= "" then return true end
  end
  return false
end

-- Speaks the dirty rows (see above), skipping item rows. Returns true if
-- anything was said.
local function announceNew(rows, ctx, interrupt)
  local mem = ctx and ctx.kind ~= "wait" and N.spoken[ctx.key] or nil
  -- a Yes/No question asked again ("WOULD YOU LIKE TO DUEL ISAAC?" the
  -- second time) is a new question: said again, like a text box
  if ctx and ctx.key:match("^h ") then mem = nil end
  local parts = {}
  -- a "Pokemon in play" list (Active first, then the bench, 3 rows each,
  -- the ACT/BP column on the left; PrintPlayAreaCardInformation) redrawn
  -- with no choice being asked: after Energy is attached, or during an
  -- animation. The game's own message says what happened (Spacefrag,
  -- 2026-10-20: "Pokemon, Energy: Fire Fire" before it was too much).
  -- (the mail list's title on top, the open mail's "MAIL 1" box label)
  local mailBehindBox = rows[1]:match("^MAIL ") and rows[13]:match("^MAIL %d+$")
  local listRows = {}
  -- (the whole list: Active, then a bench row. One Pokemon alone at the
  -- top is a card shown for its Pokemon Power, DisplayUsePokemonPowerScreen:
  -- that is read.)
  if (not ctx or ctx.kind == "wait") and rows[1]:match("^{Active}") and rows[4]:match("^{Bench}") then
    for g = 1, 16, 3 do
      if rows[g]:match("^{Active}") or rows[g]:match("^{Bench}") then
        listRows[g], listRows[g + 1], listRows[g + 2] = true, true, true
      end
    end
  end
  -- the list with a cursor pointing at the one Pokemon that changed: the
  -- other Pokemon are not read (their empty bench slots still are)
  if ctx and ctx.point and rows[1]:match("^{Active}") then
    for g = 1, 16, 3 do
      if rows[g]:match("^{Active}.") or rows[g]:match("^{Bench}.") then
        listRows[g], listRows[g + 1], listRows[g + 2] = true, true, true
      end
    end
  end
  for y = 1, 18 do
    local skip = ctx and ctx.itemRows and ctx.itemRows[y]
    -- a menu whose choices are all on screen at once: listed when it opens
    -- (as a sighted player takes them in), then only the item
    -- (even if they are the same as last time it was open)
    local arrival = skip and ctx.listOnArrival and N.ctxKey ~= ctx.key
    if arrival then skip = false end
    -- a card list's "3/ 6" header follows the cursor; the item already
    -- says "3 of 6", so a change of numbers alone there is not news
    if ctx and ctx.cardlist and mem and mem[y] and N.dirty[y]
      and mem[y]:gsub("%d", "") == rows[y]:gsub("%d", "") then
      skip = true
    end
    -- the hand list redrawn behind a text box (after a card is played)
    -- is not read out: only its changed rows would be, a muddle
    if (not ctx or ctx.kind == "wait") and y <= 12 and handBehindBox(rows) then skip = true end
    -- a mail being read: the mail list stays above it, and an unread
    -- mail's name blinks there ("MAIL 4" said before the mail)
    if (not ctx or ctx.kind == "wait") and y <= 11 and mailBehindBox then skip = true end
    -- the draw-cards screen: only who drew (rowsOf); a text box that
    -- waits for A there ("no cards in deck") is still read
    if rows.drawScreen and not ctx and y ~= 4 and y ~= 11 then skip = true end
    -- the duel scene's two status lines (Spacefrag, 2026-10-20: not
    -- said automatically any more; B says yours and
    -- Shift+B the opponent's, as last shown. The game's own messages say
    -- what happened: damage, evolving, Energy attached, knock outs.)
    local side = rows.duelScene and (rows[y]:match("^(Opponent):") or rows[y]:match("^(You):"))
    if side then N.duelLine[side] = rows[y] skip = true end
    if listRows[y] then skip = true end
    -- a Play Area screen is opened to hear it: all its facts, even one
    -- the last screen had in the same row (the opponent's "Prizes 2."
    -- after yours was dropped)
    local same = mem and mem[y] == rows[y] and not (rows.playArea and y <= 12) and not arrival
    if N.dirty[y] and not skip and not same then
      local s = speakable(rows[y])
      if s ~= "" then
        -- the empty bench slots of a Pokemon list: "4 empty bench slots"
        local last = parts[#parts]
        local n = last and (last == "empty bench slot" and 1 or tonumber(last:match("^(%d+) empty bench slots$")))
        if s == "empty bench slot" and n then
          parts[#parts] = (n + 1) .. " empty bench slots"
        else
          parts[#parts + 1] = s
        end
      end
    end
    N.dirty[y] = false
  end
  if ctx then N.spoken[ctx.key] = rows end
  if #parts > 0 then
    say(table.concat(parts, "\n"), interrupt)
    return true
  end
  return false
end

local function itemText(cells, ctx)
  if ctx.fields then
    -- a name and a number far apart: "SQUIRTLE LV8, 1"
    local row, slice = cells[ctx.y + 1] or {}, {}
    for x = ctx.x + 2, 20 do slice[#slice + 1] = row[x] end
    return speakable(rowText(slice))
  end
  local parts = {}
  for r = 0, (ctx.h or 1) - 1 do
    local row = cells[ctx.y + 1 + r]
    if row then
      local s = speakable(cellText(row, ctx.x + 2, math.min(20, ctx.x + 1 + ctx.w)))
      if s ~= "" then parts[#parts + 1] = s end
    end
  end
  return table.concat(parts, ", ")
end

-- ---------- coin tosses ----------
-- The result is only a picture (the coin's face, and o/x marks for
-- several coins). _TossCoin (engine/duel/core.asm) counts the coins
-- tossed in wCoinTossNumTossed $CD9F and the heads in
-- wCoinTossNumHeads $CD9D (total wanted: wCoinTossTotalNum $CD9C), so
-- each new coin is heads if the heads count went up with it.
local COIN = {}
local function coinTick()
  local tossed, heads = rb(0xcd9f), rb(0xcd9d)
  if COIN.tossed and tossed == COIN.tossed + 1 then
    local total = rb(0xcd9c)
    local res = (heads > COIN.heads) and "Heads" or "Tails"
    if total > 1 then say(string.format("%s, coin %d of %d.", res, tossed, total))
    else say(res .. ".") end
  end
  COIN.tossed, COIN.heads = tossed, heads
end

local function narrate()
  local f = emu.framecount()
  coinTick()
  -- a savestate load or reset makes the frame counter jump: start
  -- fresh, so the screen is described as if just arrived
  if N.lastF and (f < N.lastF or f > N.lastF + 120) then
    N.spoken, N.dirty, N.prevRows, N.itemKey, N.vcursor, N.duelLine = {}, {}, nil, nil, nil, {}
    N.lastPress = -100
    -- hook times from the old timeline would count as "now" again once
    -- the frame counter catches up with them (a stray "Grass, 1 of 9"
    -- in a room after loading a state)
    HOOK.last = {}
  end
  N.lastF = f
  local cells = readScreen()
  local rows = rowsOf(cells)
  local ctx = currentContext(f)
  -- walking in a room: a menu opened from here is a fresh arrival, even
  -- if it looks as it did last time (an Auto Deck Machine's title and
  -- "PLEASE SELECT DECK." were silent on the second visit)
  if hookActive("tcg_overworld", f) then N.spoken = {} end
  -- a keepItem menu's own redraw can take a few frames with no input
  -- wait (the deck screen's card list): that gap keeps it too
  if ctx and ctx.keepItem then N.keepItemF = f end
  local keep = ctx and ctx.keepItem or (not ctx and N.keepItemF and f >= N.keepItemF and f - N.keepItemF < 15)
  local changed = 0
  for y = 1, 18 do
    if not N.prevRows or rows[y] ~= N.prevRows[y] then
      changed = changed + 1
      N.dirty[y] = true
      N.lastChange = f
      -- the item is said again only if the screen changed meanwhile:
      -- a menu that only flickers out for a frame stays quiet. Blinking
      -- items (unread mail) are not a change of screen.
      if not (keep or (ctx and ctx.text and ctx.itemRows and ctx.itemRows[y]) or y == rows.nameRow) then
        N.itemKey = nil
      end
    end
  end
  N.prevRows = rows

  local cx, cy = findCursor(cells)
  -- only a BLINKING cursor means the game is waiting on it: one left
  -- standing after a choice was made (the Pokemon list while Energy
  -- is attached) must not be read as a menu
  -- a whole new screen (a card page opened from the hand list) takes
  -- the old cursor with it; otherwise the row where it stood would be
  -- read as a menu item (the first attack's damage, "20", cutting the
  -- card page off)
  if changed >= 8 then N.vcursor = nil end
  local vc = N.vcursor
  if cx then
    if vc and vc.x == cx and vc.y == cy then vc.f = f
    else N.vcursor = { x = cx, y = cy, f = f } end
  elseif vc then
    if blankCell(cells[vc.y + 1][vc.x + 1]) then vc.blank = f
    else N.vcursor = nil end -- something else is drawn where the cursor was
  end
  vc = N.vcursor
  -- a menu that uses the game's own cursor code has just closed: its
  -- cursor can stay drawn for a moment and is not a new menu
  local lastRefresh = math.max(HOOK.last.tcg_refresh or -100, HOOK.last.tcg_duelmenu or -100)
  local recentRam = lastRefresh <= f and f - lastRefresh < 40
  if not ctx and not recentRam and vc and vc.blank and f - vc.f <= VCURSOR_HOLD and f - vc.blank <= VCURSOR_HOLD then
    ctx = { kind = "vmenu", key = "vmenu", vx = N.vcursor.x, vy = N.vcursor.y }
  end
  local still = f - N.lastChange
  if ctx and ctx.vx then
    -- cursor found on screen: no item rows known, so the whole screen
    -- is context and the item is read off the cursor's row
    if still < SETTLE_FRAMES then return end
    local said = announceNew(rows, ctx, (f - N.lastPress) < 30)
    local item = visualItem(cells, ctx.vx, ctx.vy)
    local key = "v|" .. ctx.vx .. "," .. ctx.vy .. "|" .. item
    if key ~= N.itemKey then
      if item ~= "" then say(item, not said) N.lastItem = item end
      N.itemKey = key
    end
    N.ctxKey = ctx.key
  elseif ctx then
    if still < SETTLE_FRAMES then return end
    -- a keepItem menu's redraw (the card list under a new card type)
    -- follows the item it was just said with, rather than cutting it off
    local recentPress = (f - N.lastPress) < 30 and not (keep and N.keepSaidF and f - N.keepSaidF < 30)
    local said = announceNew(rows, ctx, recentPress)
    if ctx.x then
      local item = ctx.text or itemText(cells, ctx)
      local key = ctx.key .. "|" .. ctx.x .. "," .. ctx.y .. "|" .. item
      if key ~= N.itemKey then
        if item ~= "" then
          N.lastItem = item .. (ctx.pos and (", " .. ctx.pos) or "")
          say(N.lastItem, not said)
          if ctx.keepItem then N.keepSaidF = f end
        end
        N.itemKey = key
      end
    else
      N.itemKey = nil
    end
    N.ctxKey = ctx.key
  else
    N.ctxKey = nil
    if still >= STABLE_FRAMES and N.quietDone ~= N.lastChange then
      N.quietDone = N.lastChange
      announceNew(rows, nil, false)
    end
  end
end

-- Reads the whole screen on demand (K).
local function readAll()
  local rows = rowsOf(readScreen(), true)
  local parts = {}
  -- the dialogue over the hand list first: it is what is being said
  local order = {}
  local first = handBehindBox(rows) and 13 or 1
  for i = 0, 17 do order[#order + 1] = (first - 1 + i) % 18 + 1 end
  -- in a duel, whose turn it is comes first (hWhoseTurn $FF97: $C2 you,
  -- $C3 the opponent)
  -- not while the duel is being set up: nobody has a turn until the coin
  -- toss has decided who goes first (StartDuel seen, MainDuelLoop not yet)
  local f = emu.framecount()
  local start, loop = HOOK.last.tcg_duelstart, HOOK.last.tcg_turnloop
  local settingUp = start and start <= f and not (loop and loop >= start and loop <= f)
  if inDuel(f) and not settingUp then
    local w = rb(0xff97)
    if w == 0xc2 then parts[1] = "Your turn."
    elseif w == 0xc3 then parts[1] = "Opponent's turn." end
  end
  for _, y in ipairs(order) do
    local s = speakable(rows[y])
    if s ~= "" then parts[#parts + 1] = s end
  end
  say(#parts > 0 and table.concat(parts, "\n") or "No text on screen.", true)
end

-- ---------- walking around (tcg_nav.lua) ----------
local NAVM = dofile(ROOT .. "tcg_nav.lua")({ rb = rb, rbytes = rbytes, romByte = romByte,
  romWord = romWord, textFromId = textFromId, say = say, GAP = GAP,
  sayRoom = function(text) say(text, false) S.keepUntil = emu.framecount() + 120 end })

-- ---------- keys ----------
-- J/L step through a list, I/O change category, K says where you are /
-- repeats, P guides you there, T reads the whole screen, Q mutes. None
-- of these are Game Boy buttons in BizHawk (arrows, X, Z, Enter, Space).
local function inMenu()
  return currentContext(emu.framecount()) ~= nil
end

local function onKey(k)
  local duel = inDuel(emu.framecount())
  if k == "SHIFTP" and not duel then k = "P" end
  if k == "T" then readAll()
  elseif k == "H" or k == "SHIFTH" then
    say(duel and countsText(k == "H" and "player" or "opp") or "Not in a duel.", true)
  elseif duel and (k == "P" or k == "SHIFTP") then
    -- the Play Area screen's facts (there is no walking in a duel)
    local duelist = (k == "P") and "player" or "opp"
    local t = {}
    playAreaRows(t, duelist)
    say((duelist == "opp" and "Opponent: " or "") .. table.concat({ t[2], t[3], t[4], t[5] }, " "), true)
  elseif k == "B" or k == "SHIFTB" then
    local line = N.duelLine[k == "B" and "You" or "Opponent"]
    say(not duel and "Not in a duel." or (line and speakable(line)) or "No Active Pokemon shown yet.", true)
  elseif k == "Q" then
    S.speechOn = not S.speechOn
    pcall(function() speech.output(S.speechOn and "Speech on." or "Speech off.", true) end)
  elseif hookActive("tcg_island", emu.framecount()) then
    if k == "J" then NAVM.islandItem(-1)
    elseif k == "L" then NAVM.islandItem(1)
    elseif k == "K" then NAVM.islandRepeat()
    elseif k == "P" then NAVM.islandGo()
    elseif k == "I" or k == "O" then say("Island map: J and L choose a place.", true) end
  elseif k == "K" then
    if inMenu() and N.lastItem then say(N.lastItem, true)
    elseif NAVM.active() and not duel then NAVM.repeatCurrent()
    else readAll() end
  elseif not NAVM.active() or duel or inMenu() then
    if k == "J" or k == "L" or k == "I" or k == "O" or k == "P" then
      say("Nothing to list here.", true)
    end
  elseif k == "J" then NAVM.item(-1)
  elseif k == "L" then NAVM.item(1)
  elseif k == "I" then NAVM.category(-1)
  elseif k == "O" then NAVM.category(1)
  elseif k == "P" then NAVM.guide()
  end
end

-- ---------- developer bridge (Claude drives the emulator) ----------
-- work\cmd.txt holds one command; the result goes to work\ack.txt.
local CMD_FILE, ACK_FILE = WORK .. "cmd.txt", WORK .. "ack.txt"

local function writeAck(text)
  local f = io.open(ACK_FILE, "w")
  if f then f:write(text) f:close() end
end

local function dumpScreen(path)
  local cells, raw = readScreen()
  local f = io.open(path, "w")
  if not f then return end
  f:write(string.format("frame %d  LCDC %02X SCX %d SCY %d WX %d WY %d  top %02X\n",
    emu.framecount(), rb(0xff40), rb(0xff43), rb(0xff42), rb(0xff4b), rb(0xff4a), rb(0xffa8)))
  for y = 1, 18 do
    local hex = {}
    for x = 1, 20 do hex[x] = string.format("%02X", raw[y][x]) end
    f:write(string.format("%2d %s | %s\n", y - 1, table.concat(hex, " "), cellText(cells[y])))
  end
  f:close()
end

local function runCommand(line)
  local parts = {}
  for w in line:gmatch("%S+") do parts[#parts + 1] = w end
  local c = (parts[1] or ""):upper()
  if c == "SCREENSHOT" then
    client.screenshot(WORK .. "screen.png")
    writeAck("OK screenshot frame=" .. emu.framecount())
  elseif c == "PRESS" then
    local n = tonumber(parts[3]) or 6
    N.lastPress = emu.framecount()
    for i = 1, n do joypad.set({ [parts[2]] = true }) narrate() emu.frameadvance() end
    writeAck("OK press " .. parts[2] .. " frame=" .. emu.framecount())
  elseif c == "WAIT" then
    for i = 1, (tonumber(parts[2]) or 1) do
      if i % 2 == 0 then narrate() end
      local hold = NAVM.pad()
      if hold then joypad.set({ [hold] = true }) end
      emu.frameadvance()
    end
    writeAck("OK wait frame=" .. emu.framecount())
  elseif c == "READ" then
    local a, n = tonumber(parts[2], 16), tonumber(parts[3]) or 1
    local t = {}
    for i = 0, n - 1 do t[#t + 1] = string.format("%02X", rb(a + i)) end
    writeAck("OK read " .. parts[2] .. " = " .. table.concat(t, " "))
  elseif c == "WRITE" then
    -- WRITE <hexaddr> <hexbyte>: test copies only (e.g. allow another Energy)
    memory.write_u8(tonumber(parts[2], 16), tonumber(parts[3], 16), "System Bus")
    writeAck("OK write " .. parts[2])
  elseif c == "LOADSTATE" then
    local ok = pcall(savestate.load, line:match("^%S+%s+(.+)$"))
    writeAck((ok and "OK" or "FAIL") .. " loadstate frame=" .. emu.framecount())
  elseif c == "SAVESTATE" then
    local ok = pcall(savestate.save, line:match("^%S+%s+(.+)$"))
    writeAck((ok and "OK" or "FAIL") .. " savestate")
  elseif c == "FLUSHSAVE" then
    -- writes the game's save memory to the SaveRAM file now (BizHawk
    -- otherwise does it only when the game is closed)
    local ok, err = pcall(client.saveram)
    writeAck((ok and "OK" or ("FAIL " .. tostring(err))) .. " flushsave")
  elseif c == "DUMP" then
    dumpScreen(WORK .. "screen.txt")
    writeAck("OK dump frame=" .. emu.framecount())
  elseif c == "HITS" then
    local t = {}
    for k, v in pairs(HOOK.count) do t[#t + 1] = k .. "=" .. v .. "@" .. tostring(HOOK.last[k]) end
    writeAck("frame " .. emu.framecount() .. " " .. table.concat(t, " "))
  elseif c == "CTX" then
    local ctx = currentContext(emu.framecount())
    local t = { "ctx " .. (ctx and (ctx.kind .. " key=" .. ctx.key .. " x=" .. tostring(ctx.x) .. " y=" .. tostring(ctx.y)) or "none") }
    if ctx and ctx.itemRows then
      local r = {}
      for k in pairs(ctx.itemRows) do r[#r + 1] = k end
      table.sort(r)
      t[#t + 1] = "itemRows " .. table.concat(r, ",")
    end
    local mem = ctx and N.spoken[ctx.key] or {}
    for y = 1, 18 do t[#t + 1] = y .. (N.dirty[y] and "*" or "") .. ": " .. tostring(mem[y]) end
    writeAck(table.concat(t, "\n"))
  elseif c == "PROF" then
    local t0 = os.clock()
    for i = 1, 5 do rbytes(0x0000, 0x2000, "VRAM") end
    local t1 = os.clock()
    for i = 1, 5 do rbytes(0xc600, 0x200) end
    local t2 = os.clock()
    for i = 1, 5 do readScreen() end
    local t3 = os.clock()
    writeAck(string.format("vram8k %.1fms  keys512 %.1fms  readScreen %.1fms",
      (t1 - t0) * 200, (t2 - t1) * 200, (t3 - t2) * 200))
  elseif c == "ICONDUMP" then
    -- every distinct unread picture tile on screen, first position only
    local cells, raw, keys = readScreen(true)
    local f = io.open(WORK .. "icons_dump.txt", "w")
    local seen = {}
    for y = 1, 18 do
      for x = 1, 20 do
        local k = keys[y][x]
        local data = k:sub(3)
        if not cells[y][x] and not seen[data] and not data:match("^0+$") and not data:match("^f+$") then
          seen[data] = true
          f:write(string.format("x%2d y%2d tile %02X bank%s %s\n", x - 1, y - 1, raw[y][x], k:sub(1, 1), data))
          seen[data] = true
        end
      end
    end
    f:close()
    client.screenshot(WORK .. "screen.png")
    writeAck("OK icondump")
  elseif c == "NAV" then
    writeAck(NAVM.dump())
  elseif c == "KEY" then
    onKey((parts[2] or ""):upper())
    writeAck("OK key " .. tostring(parts[2]))
  elseif c == "READALL" then
    readAll()
    writeAck("OK readall")
  elseif c == "DOMAINS" then
    local t = {}
    for _, d in ipairs(memory.getmemorydomainlist()) do t[#t + 1] = d .. "=" .. memory.getmemorydomainsize(d) end
    writeAck(table.concat(t, " "))
  elseif c == "READD" then
    -- READD <domain> <hexaddr> <n>
    local a, n = tonumber(parts[3], 16), tonumber(parts[4]) or 1
    local bytes = rbytes(a, n, parts[2])
    local t = {}
    for i = 1, #bytes do t[#t + 1] = string.format("%02X", bytes[i]) end
    writeAck("OK " .. table.concat(t, " "))
  elseif c == "REBOOT" then
    client.reboot_core()
    writeAck("OK reboot frame=" .. emu.framecount())
  elseif c == "RELOAD" then
    S.reload = true
    writeAck("OK reload")
  elseif c == "SPEECH" then
    S.speechOn = (parts[2] ~= "off")
    writeAck("OK speech " .. tostring(S.speechOn))
  else
    writeAck("ERR unknown command: " .. line)
  end
end

local function pollBridge()
  local f = io.open(CMD_FILE, "r")
  if not f then return end
  local line = f:read("*l")
  f:close()
  os.remove(CMD_FILE)
  if line and line:match("%S") then
    local ok, err = pcall(runCommand, line)
    if not ok then writeAck("ERR " .. tostring(err)) end
  end
end

-- ---------- main loop ----------
-- Returns when a RELOAD command arrives; tcg_access.lua then runs this
-- file again, so changes take effect without restarting the emulator.
say(TCG_RELOADED and "Reloaded." or "Trading card game reader ready.")
local prevPad, prevKeys = {}, {}
while not S.reload do
  local f = emu.framecount()
  local keys = input.get()
  for _, k in ipairs({ "J", "K", "L", "I", "O", "P", "T", "Q", "H", "B" }) do
    if keys[k] and not prevKeys[k] then
      -- BizHawk reports either Shift key as "Shift" (not LeftShift),
      -- along with "H" and "Shift+H"
      onKey(((k == "H" or k == "B" or k == "P") and keys.Shift) and ("SHIFT" .. k) or k)
    end
  end
  prevKeys = keys
  if f % 4 == 0 then pcall(NAVM.tick) end
  local hold = NAVM.pad()
  if hold then joypad.set({ [hold] = true }) end
  local pad = joypad.get()
  for _, b in ipairs({ "A", "B", "Start", "Select", "Up", "Down", "Left", "Right" }) do
    if pad[b] and not prevPad[b] then N.lastPress = f end
  end
  prevPad = pad
  if f % 2 == 0 then narrate() end
  if f % 10 == 0 then pollBridge() end
  emu.frameadvance()
end
