POKEMON TRADING CARD GAME - BLIND ACCESSIBILITY MOD
for the Game Boy Color game, USA version
by Spacefrag5000
Version 1.1

========================================================================
WHAT THIS IS
========================================================================

This mod makes Pokemon Trading Card Game playable for blind players. It
speaks what is on the screen through your screen reader, and gives
walking directions in rooms and on the island map.

It exists for blind accessibility only. The goal is parity, not
advantage: a blind player gets what a sighted player sees on the
screen, and nothing more. It gives no hints, no hidden information and
no cheats.

No game files are included. You need your own copy of the game.

The mod reads the game's own memory and text. It does not use OCR
(text recognition from pictures).


========================================================================
WHAT YOU NEED
========================================================================

1. BizHawk, the emulator, in a version with speech support. The
   regular BizHawk does not have it. Use Amethyst's accessible BizHawk,
   Windows release 1.1: download the file bizhawk-win.zip from
   https://github.com/RealAmethyst/BizHawk/releases/tag/v1.1
   The mod was made and tested with exactly that build. A BizHawk with
   speech support has the file prism.dll in its dll folder.

2. A screen reader. The mod was made with NVDA. BizHawk's speech
   library also supports other screen readers, but only NVDA has been
   tested.

3. Your own game file: Pokemon Trading Card Game for Game Boy Color,
   USA version (the file name usually contains "USA, Australia"). The
   mod was built for the version whose SHA1 checksum is
   0f8670a583255cff3e5b7ca71b5d7454d928fc48. Other versions will not
   work.

4. BizHawk's Game Boy core set to Gambatte (BizHawk's usual choice for
   Game Boy Color games).


========================================================================
SETTING IT UP
========================================================================

1. Put this whole folder inside your BizHawk folder, next to
   EmuHawk.exe. For example: BizHawk\poketcg-access

2. Put your game file (ending in .gbc) in this folder, next to this
   readme.

3. Double-click PlayTCG.bat in this folder. BizHawk starts the game
   with the mod running. You should hear "Trading card game reader
   ready."

The mod writes a few files of its own into a "work" folder here: a log
of everything it said, and a log of anything it could not read. Those
are only for fixing problems. You can delete them at any time.


========================================================================
GAME BOY CONTROLS
========================================================================

These are BizHawk's usual keys. You can change them in BizHawk.

  Arrow keys   the D-pad
  X            A button
  Z            B button
  Enter        Start
  Space        Select


========================================================================
MOD KEYS
========================================================================

Everywhere:
  T        read the whole screen
  K        repeat the menu item you are on (in rooms: where you are
           and the target you chose)
  Q        speech on and off

Menus say the item under the cursor and its place in the list. Text
boxes are read as they appear. Coin tosses say heads or tails.

Walking around in rooms:
  I and O  choose a category: All, People, Exits, Things
           (empty categories are skipped)
  J and L  step through that category, nearest first,
           for example "Sam, 7 steps"
  P        guide me there: the route, then a word at each turn, then
           "Arrived" when you can talk to it or use it.
           Press P again on the same target to stop guiding.
  Things that cannot be reached from where you are stay in the list
  and are said as "can't be reached from here".

On the island map:
  J and L  choose a place; you hear the D-pad route to it
  P        move the cursor there; then press A to go in

In a duel:
  H          your Hand, Deck, Discard pile and Prizes counts
  Shift+H    the same for your opponent
  B          your Active Pokemon: name, HP, Energy, status
  Shift+B    the same for your opponent
  P          your play area: prizes, Active Pokemon, deck, discard
             pile, hand and bench
  Shift+P    the same for your opponent

During a duel the mod stays quiet about things the game's own messages
already say (damage, Energy attached, knock outs). Use the keys above
whenever you want the full picture.


========================================================================
SAVING
========================================================================

The game saves with the Diary: press Start, choose DIARY, then YES.
Turning off the PC in the game does not save. Save with the Diary
before closing BizHawk.


========================================================================
KNOWN LIMITS
========================================================================

- Card Pop and the Gift Center's card sending use the Game Boy Color's
  infrared port, which may not work in an emulator at all. Link cable
  duels have not been tried.
- Right after loading a savestate, B and Shift+B may say "No Active
  Pokemon shown yet." until the duel screen is drawn again.


========================================================================
CREDITS
========================================================================

Made by Spacefrag5000, with the help of Claude, an AI assistant made by
Anthropic. Spacefrag5000 designed and tested the mod as a blind player;
Claude wrote and tested the code.

Built with the help of the pret "poketcg" disassembly project, which
documents how the game works. No part of the game is included here.

The mod speaks through Amethyst's accessible BizHawk, which adds the
speech Lua library to BizHawk. It uses the prism screen reader library
(github.com/ethindp/prism). BizHawk itself is made by the TASEmulators
team. None of these are included here; download BizHawk as described
under WHAT YOU NEED.


========================================================================
LICENSE
========================================================================

The mod is free and open: you may use it, change it and share it under
the MIT License, as long as the copyright notice stays with it. The full
text is in LICENSE.txt. The license covers the mod only, not the game,
which belongs to its owners.
