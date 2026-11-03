================================================================
  COZY VILLAGE & FARM  -  16x16 Top-Down Mega Asset Pack  v1.0
================================================================

Thank you for buying this pack! Everything you need to build a
complete cozy farming / village game: terrain for 4 seasons,
auto-tiles, buildings, interiors, 16 crops, tools, animals,
12 characters with animations, beach & fishing, 160+ items,
a full UI kit and effects.

TILE SIZE: 16x16 pixels. Characters are 16x32 (2 tiles tall).
All art uses ONE shared 34-color palette (see /Palette), so
everything matches. Import with "Point / No filter" and no
compression to keep pixels crisp (Unity: Filter Mode = Point,
Compression = None, Pixels Per Unit = 16).

----------------------------------------------------------------
FOLDERS
----------------------------------------------------------------
01_Terrain        Base tiles + auto-tiles for spring/summer/
                  autumn/winter, animated water, cliffs, bridges
02_Nature         Trees (4 seasons + fruit trees, cherry, maple,
                  palm), bushes, rocks, ores, crystals, flowers,
                  grass, mushrooms, decor
03_Buildings      Houses (8), shop, bakery, blacksmith, fish shop,
                  inn, barn, coop, greenhouse, well, market stalls,
                  windmill (animated blades)
04_Props          Fences & stone wall (auto-tile), gates, lamps,
                  barrels, crates, signs, carts, scarecrow,
                  fountain (anim), campfire (anim) and more
05_Interiors      Floors, walls, furniture, fireplace (anim)
06_Farming        16 crops x 5 growth stages, harvest items,
                  seed packets, 9 tools x 4 upgrade tiers
07_Animals        Cow, sheep, pig, goat, horse, dog, cat, rabbit,
                  chickens, duck, chick
08_Characters     Player (2 styles) with walk/idle + 5 tool
                  actions, 10 villagers
09_Beach_Fishing  Palm, umbrellas, towels, pier, boat, crab,
                  seagull, buoy, fishing bobber, coral, seaweed
10_Items          Food, resources, ores/bars, gems, fish (22),
                  animal products, potions, misc
11_UI             Panels (9-slice), buttons, slots, hotbar, bars,
                  hearts, icons, weather/season icons, cursors,
                  emotes, dialogue box, clock panel
12_Effects        Splash, dust, sparkle, leaves, rain, snow,
                  harvest pop, hit, smoke, ripple, hearts, coin,
                  slash, fire
Example_Scenes    Ready-made example maps (1x)
Previews          Enlarged screenshots, GIFs, content overviews
Palette           .png / .gpl (GIMP, Aseprite) / .hex

----------------------------------------------------------------
AUTO-TILES (01_Terrain/Autotiles)
----------------------------------------------------------------
Each auto-tile sheet is 64x64 = 16 tiles using a CORNER layout
(see _AUTOTILE_LAYOUT_GUIDE.png). Bits = TL TR BL BR corners,
1 = upper terrain (e.g. grass), 0 = lower terrain (e.g. dirt).
  - Tiled:   create a Wang set of type "Corner"
  - Godot 4: TileSet > Terrains > mode "Match Corners"
  - Unity:   Rule Tile / any corner-based auto-tiler
"_anim_4f" sheets contain 4 frames side by side (256x64).
Recommended water speed: 4-6 fps.

----------------------------------------------------------------
SPRITE SHEET LAYOUTS
----------------------------------------------------------------
Characters  *_walk_idle_sheet.png  (16x32 frames, 6x4)
   rows:  down, up, right, left
   cols:  walk 1-4, idle 1-2
   Each direction is also included as separate strips.
   Walk 6-8 fps, idle 2-3 fps.
Player actions  *_action_<tool>.png  (32x32 frames, 3x4)
   rows: down, up, right, left  -  cols: wind-up, swing, end
   tools: hoe, axe, pickaxe, water, fish.  8-10 fps.
Animals  *_sheet.png  (6 cols x 4 rows)
   rows: down, up, right, left
   cols: walk 1-4, idle, eat/graze (eat only on side rows)
   Big animals 32x32, small 16x16.
Chickens/duck  6 cols x 2 rows (right, left): walk 1-4, peck, idle
Crops  *_stages_5.png  (16x32 frames)
   seed, sprout, young, grown, ready-to-harvest
Fences  4x4 sheet, index = N*8 + E*4 + S*2 + W*1 (connections)
Animations  *_anim_Nf.png = N frames in a horizontal strip.

----------------------------------------------------------------
LICENSE (short) - see LICENSE.txt
----------------------------------------------------------------
Use in unlimited personal & commercial games. Edit freely.
Do NOT resell or redistribute the assets themselves.
Credit is appreciated but not required.

Made with AI assistance: these assets were created
programmatically with the help of an AI model (Claude), then
reviewed and curated by the author.
