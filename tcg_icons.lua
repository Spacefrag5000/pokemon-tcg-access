-- Icon pictures the narrator recognises, keyed by the tile's 16 bytes
-- (hex). One tile of each icon gives its {Name}; the icon's other tiles
-- give "" so they read as nothing. Collected with the ICONDUMP bridge
-- command and checked against screenshots (see PROGRESS.md). Icons that
-- come straight from known ROM sheets are generated in tcg_core.lua.
return {
  -- "placing the prizes" screen (2026-10-16): an empty bench slot (a
  -- dashed frame) and a Pokemon on the bench (a face-down card with a
  -- green dot). Name on the bottom-left tile.
  ["000000001c0010000000000010001000"] = "",
  ["00000000380008000000000008000800"] = "",
  ["100010000000000010001c0000000000"] = "{EmptySlot}",
  ["08000800000000000800380000000000"] = "",
  ["000000001f1f10101010111013101310"] = "",
  ["00000000f8f8080808088808c808c808"] = "",
  ["131013101110101010101f1f00000000"] = "{BenchCard}",
  ["c808c808880808080808f8f800000000"] = "",
  -- deck screens (2026-10-19): a hand holding cards beside the deck in
  -- use (sCurrentlySelectedDeck; DrawHandCardsTileOnCurDeck). Name on
  -- the bottom-left tile, which shares the row with the deck's name.
  ["07071c1c25244d449d849d854e462727"] = "",
  ["f0f01818e424da42bd811d0109018202"] = "",
  ["15141918333137272121302010100f0f"] = "{CurDeck}",
  ["8484e8e8f0b0f010f090e020e020c0c0"] = "",
}
