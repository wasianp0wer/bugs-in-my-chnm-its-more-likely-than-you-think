# Animal and insect 3D model catalog (RRCHNM office simulation)

Target engine: Godot 4.6, so GLB is preferred. All Poly Pizza files are GLB and import directly.
Poly counts: Poly Pizza = triangles; Sketchfab = faces as reported by its API.
Downloaded files are under `models/<species>/`. Filenames end in the source ID.

## License key
- **CC0**: no attribution needed (Quaternius, OpenGameArt CC0, ffish.asia scans).
- **CC-BY 3.0/4.0**: credit the author and license, e.g. in a CREDITS file. Most "Poly by Google" models are CC-BY 3.0, credited to "Poly by Google".
- **NC / SA**: flagged in notes. Avoid NC if the project could ever be commercial, and avoid SA unless you accept its share-alike terms.

## Sources checked
- Poly Pizza: direct GLB download, no login (main download source).
- Sketchfab: API search works without login, but downloads need an account.
- OpenGameArt: direct download, no login.
- Smithsonian 3d.si.edu: returned 403 to automated requests. Check it manually in a browser.
- NIH 3D: the search UI is JavaScript-only, so nothing could be retrieved.
- CGTrader, TurboSquid, Free3D, RenderHub: firefly and flea results were almost all paid. The free ones need login.

## Gaps
- No firefly or flea model could be downloaded without login. All candidates are on Sketchfab and need an account.
- Placeholder firefly: the Poly Pizza `beetle` GLB with an emissive material added to the abdomen.
- Mosquito: no good free candidate was found, only a mosquito in amber and a 1.1M-face model.

## Catalog
| species | model name | source URL | author | license | format | approx poly count | downloaded? (local path) | notes |
|---|---|---|---|---|---|---|---|---|
| ant | Red ant | https://poly.pizza/m/8Ry1m9dbzhK | Poly by Google | CC-BY 3.0 | GLB | 1.1k | models/ant/red_ant_poly_by_google_polypizza_8Ry1m9dbzhK.glb | Attribution required ("Red ant by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| ant | Ant | https://poly.pizza/m/90PJjBye5ZC | Poly by Google | CC-BY 3.0 | GLB | 2k | models/ant/ant_poly_by_google_polypizza_90PJjBye5ZC.glb | Attribution required ("Ant by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| ant | Ant | https://poly.pizza/m/9x6pGMV83jt | jeremy | CC-BY 3.0 | GLB | 412 | models/ant/ant_jeremy_polypizza_9x6pGMV83jt.glb | Attribution required ("Ant by jeremy [CC-BY 3.0] via Poly Pizza") |
| ant | Ant 3D Model + Rigging + Animated (Low-poly-ish) | https://opengameart.org/content/ant-3d-model-rigging-animated-low-poly-ish | mujtaba-io | CC0 | .blend | low | models/ant/ant_mujtaba-io_opengameart.blend | Blender file; Godot 4.6 imports .blend only if Blender is installed/configured, else export to GLB |
| ant | Ant | https://sketchfab.com/3d-models/6ea6dfb45845443b9f99b2fe4456f9a3 | Ergin ERYILDIR | CC-BY 4.0 | glTF/GLB | 6k faces | no (login) | Sketchfab, needs login to download |
| ant | Camponotus pennsylvanicus (carpenter ant) | https://sketchfab.com/3d-models/5bd729db1baa4816870ec009b472fb7f | Epic_devolepment | CC-BY 4.0 | glTF/GLB | 8.1k faces | no (login) | Sketchfab, needs login to download; native to Virginia |
| ant | Camponotus gigas (scan-style) | https://sketchfab.com/3d-models/251b8c2768af45ef9edc5633bac628af | Nobilis 2 | CC-BY 4.0 | glTF/GLB | 429k faces | no (login) | Sketchfab, needs login to download; realistic, heavy |
| bat | Bat | https://poly.pizza/m/5_XBqyrOY7x | Poly by Google | CC-BY 3.0 | GLB | 328 | models/bat/bat_poly_by_google_polypizza_5_XBqyrOY7x.glb | Attribution required ("Bat by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| bat | Bat | https://poly.pizza/m/hNO9XvjlKa | Quaternius | CC0 1.0 | GLB | 772 | models/bat/bat_quaternius_polypizza_hNO9XvjlKa.glb | CC0, no attribution needed |
| bee | Bumblebee | https://poly.pizza/m/42S5XD_3C4O | Poly by Google | CC-BY 3.0 | GLB | 624 | models/bee/bumblebee_poly_by_google_polypizza_42S5XD_3C4O.glb | Attribution required ("Bumblebee by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| bee | Bee | https://poly.pizza/m/6ktZgxSVVn1 | jeremy | CC-BY 3.0 | GLB | 568 | models/bee/bee_jeremy_polypizza_6ktZgxSVVn1.glb | Attribution required ("Bee by jeremy [CC-BY 3.0] via Poly Pizza") |
| bee | Bee | https://poly.pizza/m/HvfIku26CK | Quaternius | CC0 1.0 | GLB | 914 | models/bee/bee_quaternius_polypizza_HvfIku26CK.glb | CC0, no attribution needed |
| beetle | Beetle | https://poly.pizza/m/4yufxgZ1QQ2 | Poly by Google | CC-BY 3.0 | GLB | 904 | models/beetle/beetle_poly_by_google_polypizza_4yufxgZ1QQ2.glb | Attribution required ("Beetle by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| beetle | Rhinoceros Beetle (scan) | https://sketchfab.com/3d-models/27c5c17dab7c4143821a7ecc1bfa2def | ffish.asia / floraZia.com | CC-BY (despite CC0 label) | glTF/GLB | 342k faces | no (login) | Sketchfab, needs login to download; description says treat as CC-BY |
| butterfly | Butterfly | https://poly.pizza/m/e9NAQQrCbLu | Poly by Google | CC-BY 3.0 | GLB | 1.9k | models/butterfly/butterfly_poly_by_google_polypizza_e9NAQQrCbLu.glb | Attribution required ("Butterfly by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| butterfly | Monarch Butterfly | https://poly.pizza/m/eeO11BVjvsO | Paul Spooner | CC-BY 3.0 | GLB | 58.8k | models/butterfly/monarch_butterfly_paul_spooner_polypizza_eeO11BVjvsO.glb | Attribution required ("Monarch Butterfly by Paul Spooner [CC-BY 3.0] via Poly Pizza") |
| cat | Cat | https://poly.pizza/m/6dM1J6f6pm9 | Poly by Google | CC-BY 3.0 | GLB | 594 | models/cat/cat_poly_by_google_polypizza_6dM1J6f6pm9.glb | Attribution required ("Cat by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| caterpillar | Caterpillar | https://poly.pizza/m/64T47O5VHAB | Poly by Google | CC-BY 3.0 | GLB | 784 | models/caterpillar/caterpillar_poly_by_google_polypizza_64T47O5VHAB.glb | Attribution required ("Caterpillar by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| centipede | Centipede | https://poly.pizza/m/8C36B7L_2hR | Poly by Google | CC-BY 3.0 | GLB | 1.3k | models/centipede/centipede_poly_by_google_polypizza_8C36B7L_2hR.glb | Attribution required ("Centipede by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| chicken | Chicken | https://poly.pizza/m/Z3RCoCYss4 | Quaternius | CC0 1.0 | GLB | 2.1k | models/chicken/chicken_quaternius_polypizza_Z3RCoCYss4.glb | CC0, no attribution needed |
| cockroach | Cockroach | https://poly.pizza/m/eSCFQN_47V4 | Poly by Google | CC-BY 3.0 | GLB | 548 | models/cockroach/cockroach_poly_by_google_polypizza_eSCFQN_47V4.glb | Attribution required ("Cockroach by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| cockroach | Cockroach (3D photogrammetry scan) | https://sketchfab.com/3d-models/cff6ea065e2e4029be5ba20f03937b63 | Kathrin&Christian | CC-BY 4.0 | glTF/GLB | 425k faces | no (login) | Sketchfab, needs login to download |
| cockroach | Roach, game-ready and animated | https://opengameart.org/content/roach-game-ready-and-animated | danimal | CC-BY-SA 3.0 | zip | low | no | Direct download available but ShareAlike; not downloaded |
| crow | Crow | https://poly.pizza/m/1MIvWQ5Q3R9 | Poly by Google | CC-BY 3.0 | GLB | 682 | models/crow/crow_poly_by_google_polypizza_1MIvWQ5Q3R9.glb | Attribution required ("Crow by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| deer | Deer | https://poly.pizza/m/fUo4AIcd8XR | Poly by Google | CC-BY 3.0 | GLB | 836 | models/deer/deer_poly_by_google_polypizza_fUo4AIcd8XR.glb | Attribution required ("Deer by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| dog | Dog | https://poly.pizza/m/eDmSVe4TKwF | Poly by Google | CC-BY 3.0 | GLB | 558 | models/dog/dog_poly_by_google_polypizza_eDmSVe4TKwF.glb | Attribution required ("Dog by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| dragonfly | Dragonfly | https://poly.pizza/m/0myA_BOcZrD | Poly by Google | CC-BY 3.0 | GLB | 466 | models/dragonfly/dragonfly_poly_by_google_polypizza_0myA_BOcZrD.glb | Attribution required ("Dragonfly by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| firefly | Lowpoly Firefly | https://sketchfab.com/3d-models/5effa6605b5545f2915da8b8fff8fa48 | Caledhril | CC-BY 4.0 | glTF/GLB (+orig) | 2.3k faces | no (login) | Sketchfab, needs login to download; stylized "angry" firefly; has 2 anims (can ignore). Best low-poly pick |
| firefly | Firefly | https://sketchfab.com/3d-models/111cc8dc99c84940a8bd4dc83a4f430a | 1catalogue | CC-BY 4.0 | glTF/GLB | 5.5k faces | no (login) | Sketchfab, needs login to download; low-res, UV-mapped |
| firefly | Firefly (glowing) | https://sketchfab.com/3d-models/a73e81ae4d2245e0af6fb96d81d87168 | bezope | CC-BY 4.0 | glTF/GLB | 44k faces | no (login) | Sketchfab, needs login to download; Tinkercad-made, toy-like |
| firefly | Firefly | https://sketchfab.com/3d-models/be265d5ef06a406cbb2cd91488298ee7 | Dami_Nuga | CC-BY 4.0 | glTF/GLB | 216k faces | no (login) | Sketchfab, needs login to download; high poly, decimate |
| firefly | Bob the Firefly | https://sketchfab.com/3d-models/5bb58c26254446a081797adae8df947e | Oranges25 | CC-BY 4.0 | glTF/GLB | 15.6k faces | no (login) | Sketchfab, needs login to download; cartoon character |
| flea | Flea (animation test) | https://sketchfab.com/3d-models/707ebd86ea2a471681e558ab70fe45a3 | nodoxi | CC-BY 4.0 | glTF/GLB | 2.2k faces | no (login) | Sketchfab, needs login to download; best low-poly flea |
| flea | Flea | https://sketchfab.com/3d-models/eb0e2b6782ee4309892947f044a8eecd | XLPHV | CC-BY 4.0 | glTF/GLB | 460k faces | no (login) | Sketchfab, needs login to download; high poly, needs decimation |
| flea | Cat Flea (scan) | https://sketchfab.com/3d-models/e343c81f94354dbaacb965d4381b60de | Blackburn Lab | CC-BY-NC 4.0 | glTF/GLB | 1.85M faces | no (login) | Sketchfab, needs login to download; NON-COMMERCIAL; scientific scan; very heavy |
| flea | Ctenocephalides felis | https://sketchfab.com/3d-models/74c4f92a6ec542e097d26d1663876d21 | tunosemi | CC-BY-NC-SA 4.0 | glTF/GLB | 410k faces | no (login) | Sketchfab, needs login to download; NON-COMMERCIAL + ShareAlike; author asks to read terms before downloading |
| frog | Frog | https://poly.pizza/m/07-wJ9bkzul | jeremy | CC-BY 3.0 | GLB | 416 | models/frog/frog_jeremy_polypizza_07-wJ9bkzul.glb | Attribution required ("Frog by jeremy [CC-BY 3.0] via Poly Pizza") |
| frog | Frog | https://poly.pizza/m/9Z2V8fpazF | Quaternius | CC0 1.0 | GLB | 4.9k | models/frog/frog_quaternius_polypizza_9Z2V8fpazF.glb | CC0, no attribution needed |
| grasshopper | Grasshopper | https://poly.pizza/m/3VFH5hQvI8R | Poly by Google | CC-BY 3.0 | GLB | 2.1k | models/grasshopper/grasshopper_poly_by_google_polypizza_3VFH5hQvI8R.glb | Attribution required ("Grasshopper by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| hornet | Hornet | https://poly.pizza/m/6h7-AWppj5e | Poly by Google | CC-BY 3.0 | GLB | 792 | models/hornet/hornet_poly_by_google_polypizza_6h7-AWppj5e.glb | Attribution required ("Hornet by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| hornet | Japanese Giant Hornet (scan) | https://sketchfab.com/3d-models/f9c1f7e3f373491fbf01adf94ec8169e | ffish.asia / floraZia.com | CC0 | glTF/GLB | 376k faces | no (login) | Sketchfab, needs login to download |
| hornet | Dead European Hornet - Macro Scan | https://sketchfab.com/3d-models/e8f39640a5b742b180ee0d34a72ae49c | Nik | CC-BY 4.0 | glTF/GLB | 46k faces | no (login) | Sketchfab, needs login to download; Vespa crabro, dead pose |
| housefly | Fly | https://poly.pizza/m/f8kM9xA_5sV | jeremy | CC-BY 3.0 | GLB | 512 | models/housefly/fly_jeremy_polypizza_f8kM9xA_5sV.glb | Attribution required ("Fly by jeremy [CC-BY 3.0] via Poly Pizza") |
| ladybug | Ladybug | https://poly.pizza/m/0k_YwE0g_C9 | Poly by Google | CC-BY 3.0 | GLB | 760 | models/ladybug/ladybug_poly_by_google_polypizza_0k_YwE0g_C9.glb | Attribution required ("Ladybug by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| ladybug | Ladybug | https://poly.pizza/m/0oADEnspgZu | jeremy | CC-BY 3.0 | GLB | 428 | models/ladybug/ladybug_jeremy_polypizza_0oADEnspgZu.glb | Attribution required ("Ladybug by jeremy [CC-BY 3.0] via Poly Pizza") |
| moth | Lil' Moth | https://poly.pizza/m/8ojwMQpu6DK | Lee Mason | CC-BY 3.0 | GLB | 770 | models/moth/lil_moth_lee_mason_polypizza_8ojwMQpu6DK.glb | Attribution required ("Lil' Moth by Lee Mason [CC-BY 3.0] via Poly Pizza") |
| mouse | Mouse | https://poly.pizza/m/4KKE4D2FV1D | Poly by Google | CC-BY 3.0 | GLB | 776 | models/mouse/mouse_poly_by_google_polypizza_4KKE4D2FV1D.glb | Attribution required ("Mouse by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| mouse | Mouse | https://poly.pizza/m/9Nw9BpWzqAx | Poly by Google | CC-BY 3.0 | GLB | 32 | models/mouse/mouse_poly_by_google_polypizza_9Nw9BpWzqAx.glb | Attribution required ("Mouse by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| mouse | House Mouse | https://sketchfab.com/3d-models/b2737ba987794081bfb9cebc6aa6b55e | Jean-Christophe Sekinger | CC-BY 4.0 | glTF/GLB | 168k faces | no (login) | Sketchfab, needs login to download; realistic |
| pigeon | Pigeon | https://poly.pizza/m/9NGlBTpDEr | Quaternius | CC0 1.0 | GLB | 2k | models/pigeon/pigeon_quaternius_polypizza_9NGlBTpDEr.glb | CC0, no attribution needed |
| raccoon | Raccoon | https://poly.pizza/m/2iYORwFng3_ | Poly by Google | CC-BY 3.0 | GLB | 1.2k | models/raccoon/raccoon_poly_by_google_polypizza_2iYORwFng3_.glb | Attribution required ("Raccoon by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| raccoon | Raccoon | https://poly.pizza/m/xMmx6VQP3r | Quaternius | CC0 1.0 | GLB | 2.9k | models/raccoon/raccoon_quaternius_polypizza_xMmx6VQP3r.glb | CC0, no attribution needed |
| rat | Rat | https://poly.pizza/m/9h_k4Jkm3Le | jeremy | CC-BY 3.0 | GLB | 466 | models/rat/rat_jeremy_polypizza_9h_k4Jkm3Le.glb | Attribution required ("Rat by jeremy [CC-BY 3.0] via Poly Pizza") |
| rat | Rat | https://poly.pizza/m/iltq5bVNaV | Quaternius | CC0 1.0 | GLB | 4k | models/rat/rat_quaternius_polypizza_iltq5bVNaV.glb | CC0, no attribution needed |
| snake | Snake | https://poly.pizza/m/2ovwPNrRijL | Poly by Google | CC-BY 3.0 | GLB | 334 | models/snake/snake_poly_by_google_polypizza_2ovwPNrRijL.glb | Attribution required ("Snake by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| snake | Snake | https://poly.pizza/m/x9x0viZs8V | Quaternius | CC0 1.0 | GLB | 1.6k | models/snake/snake_quaternius_polypizza_x9x0viZs8V.glb | CC0, no attribution needed |
| spider | Spider | https://poly.pizza/m/7ky8XvFh9Wf | jeremy | CC-BY 3.0 | GLB | 1.1k | models/spider/spider_jeremy_polypizza_7ky8XvFh9Wf.glb | Attribution required ("Spider by jeremy [CC-BY 3.0] via Poly Pizza") |
| spider | Spider | https://poly.pizza/m/yRYJiAJyiM | Quaternius | CC0 1.0 | GLB | 2.7k | models/spider/spider_quaternius_polypizza_yRYJiAJyiM.glb | CC0, no attribution needed |
| squirrel | Squirrel | https://poly.pizza/m/caxos24uWC9 | Poly by Google | CC-BY 3.0 | GLB | 716 | models/squirrel/squirrel_poly_by_google_polypizza_caxos24uWC9.glb | Attribution required ("Squirrel by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| squirrel | Lowpoly Squirrel | https://poly.pizza/m/eGdXC-5V2wM | Tipatat Chennavasin | CC-BY 3.0 | GLB | 260 | models/squirrel/lowpoly_squirrel_tipatat_chennavasin_polypizza_eGdXC-5V2wM.glb | Attribution required ("Lowpoly Squirrel by Tipatat Chennavasin [CC-BY 3.0] via Poly Pizza") |
| stink bug | Brown Marmorated Stink Bug | https://sketchfab.com/3d-models/1254d74508a1428b8f21679a6da80096 | Libraries of Life | CC-BY 4.0 | glTF/GLB | 4.1k faces | no (login) | Sketchfab, needs login to download; common indoor pest in Northern Virginia offices |
| wasp | Wasp | https://poly.pizza/m/2aKeIJiUspL | Poly by Google | CC-BY 3.0 | GLB | 1.6k | models/wasp/wasp_poly_by_google_polypizza_2aKeIJiUspL.glb | Attribution required ("Wasp by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| wasp | Wasp | https://poly.pizza/m/3aQgc75sUR | Quaternius | CC0 1.0 | GLB | 3.7k | models/wasp/wasp_quaternius_polypizza_3aQgc75sUR.glb | CC0, no attribution needed |
| wasp | Wasp | https://poly.pizza/m/4UdWQxbm0-B | Poly by Google | CC-BY 3.0 | GLB | 664 | models/wasp/wasp_poly_by_google_polypizza_4UdWQxbm0-B.glb | Attribution required ("Wasp by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| wasp | Wasp | https://poly.pizza/m/e-maR6CzcKc | Poly by Google | CC-BY 3.0 | GLB | 1.7k | models/wasp/wasp_poly_by_google_polypizza_e-maR6CzcKc.glb | Attribution required ("Wasp by Poly by Google [CC-BY 3.0] via Poly Pizza") |
| wasp | Hornet/Wasp (rigged) | https://opengameart.org/content/3d-hornetwasp | mikemoon | CC0 | .blend (zip) | ? | models/wasp/hornet_wasp_mikemoon_opengameart.zip | Zip of 21 .blend iterations; use Hornet6(Animating).blend or Hornet3. Needs Blender to convert |
| wasp | Paper Wasp, Polistes rothneyi (scan) | https://sketchfab.com/3d-models/c657df47633f408e98268ae66419788e | ffish.asia / floraZia.com | CC0 | glTF/GLB | 174k faces | no (login) | Sketchfab, needs login to download; photoreal scan |
| wasp | Dark-waisted Paper Wasp (scan) | https://sketchfab.com/3d-models/3a4f03cbde924ff7b02e4bbcbc26b63a | ffish.asia / floraZia.com | CC0 | glTF/GLB | 173k faces | no (login) | Sketchfab, needs login to download |
| wasp | German wasp, Vespula germanica (scAnt scan) | https://sketchfab.com/3d-models/a59f6b5b50094940b75258a28e57c8c3 | Peter_TR | CC-BY 4.0 | glTF/GLB | 217k faces | no (login) | Sketchfab, needs login to download; yellowjacket, found in Virginia |
| wasp | Vespula vulgaris | https://sketchfab.com/3d-models/9423b9adee8b4545b9d05f8f42f5b2d7 | Nobilis the Palaeovespa | CC-BY 4.0 | glTF/GLB | 337k faces | no (login) | Sketchfab, needs login to download |
