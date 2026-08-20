# Trạng thái native port (perf stages)

## Goal
Port per-chunk GDScript hot spots sang Godot 4.7 GDExtension DLL (`C:\Users\gnasv\AppData\Local\Temp\opencode`), mỗi stage verify bit-exact qua A/B test scenes, giữ GD fallback (`_force_*_gd`).

## Quy ước chung
- Native path + GD fallback + toggle `_force_*_gd` (static); A/B phải bit-exact (grids maxdiff 0.0; props/blades bằng nhau).
- `randf()` không deterministic (compute chạy trên `WorkerThreadPool`) → thay bằng `_cell_hash01(vx+S1,vz+S2)` salts riêng mỗi loại; dùng ở cả C++ lẫn GD fallback.
- `_is_on_road` equivalence: `road_grid[i]!=0` (`_point_to_seg_d2<=md2`, `ROAD_HALF_W=2.0`).
- Rebuild: `scons -C "C:\Users\gnasv\AppData\Local\Temp\opencode" target=template_debug` rồi copy DLL vào `cpp\bin\`.
- `.gd` phải giữ LF + no BOM — dùng Edit tool / string splice với `UTF8Encoding($false)`, `List[string]` rõ ràng (inline `$T + '...'` trong `@()` sập còn 1 phần tử).
- Godot: `D:\portApp\Godot\Godot_v4.7-stable_win64_console.exe`. Seed test: `20260804` + `SeedSnapshot.set_seed(...)`.
- `_Data._Dim.DimensionID`: `TWILIGHT=0`, `REAL_WORLD=1`. Các test S3/S4/S6b/S12/S9 phải chạy dim `REAL_WORLD` để chạm nhánh thật (đường/sông/biome mặc định).

## Đã xong (committed)
| Stage | Commit | Kết quả |
|---|---|---|
| S4 biome_grid+height (WorldLand) | `2336f8c` | S4 4-6.5→~1.5ms; A/B 9/9 maxdiff 0.0 |
| S6b 4x Chebyshev BFS (WorldDist.bfs_grids) | `fd6b769` | S6b 3.2→0.2ms; A/B 9/9×4 |
| S3B ocean odst/shore_dst (WorldDist.ocean_dists) | `dbcc1ce` | S3 1.5→0.9ms; S4 1.7→1.1ms |
| S12 plant_props (WorldProps) | `368b859` | S12 2.3-2.8→0.20-0.26ms; A/B 10/10 (98 props native=gd); dist REAL dim 55 PASS |
| S9 grass (WorldGrass) | `710b047` | S9 3.61→1.92ms chunk(0,0); A/B 10/10 (6020 blades native=gd) |
| S2 bfs_dst (WorldBfsDst) | `4c10b15` | S2 ~1ms→0.15-0.44ms (micro); chunk total 18-25→16-24ms; A/B 15/15 (REAL 7 + TWILIGHT BFS 7) |
| S11 seagrass (WorldGrass.add_seagrass_chunk) | (S11) | S11 2.0-2.6→0.83-0.96ms (có seagrass); A/B 10/10 (6020 blades native=gd, gồm seagrass); test_seagrass 28/28 |
| S10 water_mesh (WorldWater) | (S10) | S10 1.2-3.9→0.47-0.83ms (chunk(-302,-230) 3.9→0.83ms); A/B 10/10 (25230 verts native=gd); 10 regression suites green |
| S11a aquatic plants (WorldAquatic.build_aquatic) | (S11a) | S11 aquatic+plants 2.0-2.75→0.38-0.39ms; A/B 11/11 suites green (aquatic 28/28: mesh 108-0 verts, lotus_lights, plant_props 0-33 bit-exact) |
| S13b ore (WorldOre.build_textured_block_mesh) | (S13b) | S13b ore 0.79-0.80→0.68-0.70ms; A/B 13/13 (ore ids + mesh verts/normals/colors/uvs bit-exact; chunk(5,-3) 20+33, chunk(-3,7) 17) |
| S6a road_grid (WorldRoad.paint_grid) | (S6a) | S6a road_grid 0.13-0.80→0.14-0.25ms; A/B 10/10 (801 road cells native=gd bit-exact) |
| S5 river override (WorldRiver.apply_river) | (S5) | S5 river 0.42-0.53→0.28-0.49ms (bỏ hẳn loop GD + marshalling); A/B 9/9 bit-exact (chunk(0,0) 14 river cells, chunk(5,-3) 242 cells) |
| S8 terrain_mesh (WorldTerrain.build_terrain_mesh_mesh) | (S8) | S8 1.08-1.38→0.98-1.19ms (ArrayMesh C++ trực tiếp, bỏ Dictionary round-trip); bit-exact 0/12282 mismatch vs GD fallback; 13 regression suites green |
| S3 marshalling lazy (bỏ oct/oct_small GD khi native) | (S3) | S3 ocean_mask+bfs 0.91-1.30→0.13-0.33ms; oct/oct_small (Array[Array] 84²+total²) build lazy chỉ khi GD fallback chạy; native path không còn ~0.7ms marshalling vô ích; 9/9 forced-GD A/B bit-exact + 12 suites green |
| S13b gate scan (WorldOre.scan_textured_blocks) | (S13b2) | S13b ore 0.68-0.70→0.03-0.06ms; scan gate (max_top_ly + has_ore_blocks) chuyển sang C++ — GD chỉ còn 2 loop get_block/column khi forced-gd; A/B 13/13 + 13 regression suites green |
| S1+S2 flat bio (WorldBfsDst.bfs_dst_flat) | (S1S2) | S2 bfs_dst 0.12-0.28→0.03-0.13ms (bỏ Variant boxing từng cell); S1 giữ bio flat từ native (bỏ wrap 42²→Array[Array] + S4 re-flatten); A/B bfsdst 15/15 + land 0-fail + 13 suites green |
| S4 lake-noise cache (WorldLand.land_grid) | (S4-opt) | S4 land_grid 0.77-1.03→0.56-0.66ms (S4 total ~1.0-1.4→0.80-0.91ms); lake noise (5-octave FBM) tính trước swap-cache `lake_at` 1 lần/ô thay vì 3 lần (main pass + lake mask + lake fill); thử std::thread rows → revert (spawn/join overhead ≈ thời gian song song, không thắng); A/B land 9/9 maxdiff 0.0 + 14 suites green |
| S1 biome noise cache (WorldBiome) | (S1-cache) | chunk kề reuse → S1 0.51-0.55→0.42-0.44ms (chunk(1,0) sau (0,0)); open-addressing 32K per NoiseSet, reset 50%, hash fix; 14 regression suites green bit-exact; chunk đầu trả ~0.3ms alloc 1 lần |

### S9 grass chi tiết (`710b047`)
- `src\world_grass.{h,cpp}`: `WorldGrass::add_grass_chunk(half, cols, fast_mode, height(PackedFloat64Array), biome(PackedInt32Array), wdist, hdist, road, water_y, voxel, const_inf)` → `{xforms: Array[Transform3D], colors: Array[Color]}`.
- Mirror `chunk_grass.gd` `add_voxel_grass` + `_add_clump`: `_noise` = 4 sin term (double như GDScript), cell 12×12, `cell_n < -0.15` skip, ox/oz `*4.0` round, radius `3.0+(noise*0.5+0.5)*3.0`, edge fade, LCG `ss=ss*16807+1`.
- Banned biomes numeric: DESERT=9, FROST=20, FROST_SNOW=21, SWAMP=22, SWAMP_MUD=23, SWAMP_DIRT=24 (đối chiếu `chunk_data.gd`).
- `_add_clump` màu: mature để hạt → `green.lerp(gold, seed_t)`; non-mature → `base.lerp(Color(base.r+0.18, base.g+0.10, base.b*0.7), t)` (KHÔNG phải min(base*1.4/1.3/1.15) — từng sai rồi fix); jitter `(cv2-0.5)*0.04/0.04/0.03`; cuối `col*0.88`, alpha `=t`.
- GD: `_native_grass()` bridge + `_force_s9_gd` + `_grass_gd_fallback()` (loop gate giữ nguyên) + wrapper S9 (build flat arrays, native path, else fallback). Village (S13c phần tavern `village.gd`) VẪN GD.
- A/B `tools/_native_grass_test.{gd,tscn}`: 10/10 PASS, totals native=6020 gd=6020.
- Profile so sánh (seed 20260802, `test_prof_chunk`): chunk(0,0) native 1.92 vs GD 3.61ms; chunk(1,0) 0.74 vs 1.23ms. Mức giảm bị chặn bởi chi phí Variant-boxing 1824 Transform3D — phần này chung cả 2 path (cả nhà hiện tại `grass_blade_data` = Array + `_multimesh_buffer`).
- Lưu ý kiến trúc: vì S7 (fill_blocks) REBUILD height_grid/biome_grid SAU S6b, wdist/hdist trong compute_chunk là bản "cũ" so với height_grid S9 — không thể tái dựng wd/hd từ return dict để micro-bench tách (phải đo qua compute_chunk).

### S11 seagrass chi tiết (cùng WorldGrass)
- `src\world_grass.{h,cpp}`: `WorldGrass::add_seagrass_chunk(half, cols, height(PackedFloat64Array), biome(PackedInt32Array), water_y, voxel, world_ox, world_oz)` → `{xforms, colors}` — native chạy SAU loop aquatic, append kết quả vào grass_xforms/grass_colors (giữ thứ tự như GD: seagrass sau hết cỏ S9).
- Mirror `chunk_grass.gd` `add_voxel_seagrass` + `_add_seagrass_clump` + `_sea_zone`: gate `water_gap<1.25 or >3.5` skip; `_sea_zone` = `sin(wx*0.0023+4.0)*0.5+sin(wz*0.0027-3.0)*0.5+0.5` → zone 0 tím/1 xanh dương theo world_ox/world_oz (float, KHÔNG round).
- Meadow patch-hash 5×5: `ph = int(world_x/5)*73856093 + int(world_z/5)*19349663; ph=(ph^(ph>>13))*1274126177; ph^=ph>>16; in_meadow = (ph&0x7FFFFFFF)/2147483648.0 < 0.30` — GDScript int64, dùng `int64_t` với wrap shift như GD.
- `_add_seagrass_clump`: LCG `ss*16807+1`; voxel_count `5+(ss&0x3)`; curve `t*t*0.045*height_scale`; 2 màu theo zone (tím `Color(0.45+cv*0.25,0.12+cv*0.22,0.62+cv*0.28)` tip `(0.80,0.58,0.95)`; xanh `Color(0.06+cv*0.16,0.42+cv*0.20,0.62+cv*0.26)` tip `(0.45,0.92,0.95)`); t>0.60 → lerp tip; else → lerp `Color(min(r*1.4,1),min(g*1.3,1),min(b*1.15,1))`; jitter `(cv2-0.5)*0.05/0.05/0.04`; cuối `col*0.72`, alpha `=t`.
- GD: `_force_s11_gd` toggle; loop aquatic bỏ call per-cell khi native (`not sg_native`), sau commit gọi `add_seagrass_chunk` 1 lần + append; còn `_Aquatic.add_aquatic_plants` VẪN GD.
- A/B: `tools\_native_grass_test.{gd,tscn}` (mở rộng: toggle cả `_force_s9_gd`+`_force_s11_gd`) — 10/10 PASS, totals native=6020 gd=6020 (seagrass nằm trong grass_blade_data).
- `tools\test_seagrass.tscn` — 28/28 PASS (gồm pipeline thật chunk(28,0) có 132 lá).
- Profile (seed 20260802): chunk(0,0) S11 2.0-2.6→0.96ms, chunk(1,0) ~2.0→0.83ms, chunk(-302,-230) 2.26ms (nhiều OCEAN_DEEP — chạy full, không print debug). Chunk totals 16-24→9-14ms.

### S10 water_mesh chi tiết (WorldWater)
- `src\world_water.{h,cpp}`: `WorldWater::build_water_mesh(data(PackedByteArray), cols, h_vox, half, max_ly, skip_mask)` → `{verts, normals, colors}`.
- Mirror `world_chunk.gd:_build_water_mesh` cho **path generate compute_chunk** (nb_data={}): column-top map scan (z-major như GD), fluid IDs WATER=6/WATER_SOURCE=24..LEVEL_1=31/LAVA_SOURCE=52..LEVEL_1=59, color theo levs (lava cam/water xanh), top face + 4 side band giống `_add_quad`, EPS=0.02 chống z-fight. Skip_mask: cột `height>WATER_Y` bỏ scan.
- GD: `_native_watermesh()` bridge + `_force_s10_gd` + `_water_mesh_from_arrays()` (wrap {verts,normals,colors} → ArrayMesh.add_surface_from_arrays, giống build_terrain_mesh_native). Fallback vẫn `_build_water_mesh` khi `nb_data != {}` (rebuild_water_mesh / _build_water_mesh_job dùng nb thật — giữ GD).
- A/B `tools\_native_water_test.{gd,tscn}`: 10/10 PASS, totals native=25230 gd=25230 verts (7 chunk có nước trong 9).
- Profile (seed 20260802): S10 chunk(0,0) 1.19→0.53ms, chunk(1,0) 1.69→0.47ms, chunk(-302,-230) 3.90→0.83ms. Chunk totals ~16→9-11ms.

### S11a aquatic plants chi tiết (WorldAquatic)
- `src\world_aquatic.{h,cpp}`: `WorldAquatic::build_aquatic(cx, cz, cols, total, pad, half, voxel, water_y, biome(PackedInt32Array), height(PackedFloat64Array), river(PackedByteArray), dmask(PackedByteArray), dland(PackedInt32Array))` → `{verts, normals, colors, lotus_lights, plant_props}`.
- Mirror `chunk_aquatic.gd:add_aquatic_plants` cho MỌI ô nước trong 1 call: filter b ∈ {SAND,SAND_WHITE,SILT,MUDDY_SAND,OCEAN_DEEP} ∧ h≤water_y; `is_desert_water` = dmask[(vx+PAD)*total+(vz+PAD)]==1 (hoặc dland[i]≤3 với SAND/MUDDY_SAND); `is_river` từ river flag; pos `Vector3(-half+(vx+0.5)*voxel, (float)h, ...)` — float32 truncation h như GD; `water_gap = water_y - (double)pos.y`.
- Hash int64 wrap 2^64 giống GD: lotus h5/h6, weed r1 (0.04/0.10/0.04 river/silt/other), sea plants gate 16×16 hash<0.40 + water_gap 1.5–6.0 + r1<0.035, kelp_tall gate 20×20 hash<0.45 + 6–22 + r1<0.05 (r2'=r2*0.7+0.15), taro shore `r1<0.03` on SAND/MUDDY_SAND/SILT/DIRT ∧ !is_desert ∧ is_shore.
- Lotus mesh native (lily 2 quads + stem 4 petals khi r5<0.05, y=WATER_Y+0.005); `lotus_lights` trả Vector3 array riêng. Chỉ weed/sea/kelp/taro → `plant_props` dicts `{type,pos,seed_h1,seed_h2,water_gap}` (+`has_silt` weed/taro) thứ tự như GD.
- Seagrass KHÔNG trong build_aquatic — `WorldGrass.add_seagrass_chunk` (S11) vẫn chạy riêng sau `st_aq.commit()`.
- GD: `_native_aquatic()` bridge + `_force_s11a_gd` toggle + `_aquatic_mesh_from_arrays()` (wrap {verts,normals,colors} → ArrayMesh, null khi rỗng). Loop GD chỉ chạy khi `not aq_native or not sg_native` (mỗi nhánh guard riêng) → giữ `_native_grass_test` A/B toàn seagrass.
- A/B `tools\_native_aquatic_test.{gd,tscn}`: 28/28 PASS (aquatic_mesh 108 verts chunk(5,-3)/(8,2) native=gd, lotus_lights 0–3, plant_props 0–33; 7 chunk rỗng GD commit-surface=rỗng native=null → empty-equiv).
- Profile (seed 20260802): S11 aquatic+plants 2.0–2.75→0.38-0.39ms cả 3 chunk; chunk totals ~8.4-14ms.
- Ghi chú: `compute_chunk` trả key `"aquatic_mesh"` (KHÔNG phải `"mesh_aquatic"`).

### S13b textured-block (ore) meshes chi tiết (WorldOre)
- `src\world_ore.{h,cpp}`: `WorldOre::build_textured_block_mesh(data(PackedByteArray), cols, max_ly)` → `{block_id: {verts, normals, colors, uvs}}`.
- Mirror `world_chunk.gd:_build_textured_block_meshes` (top map 1 pass từ max_ly xuống, 9 loại `_TEXTURED_BLOCK_IDS` 17-23/33/37) + `_build_textured_block_mesh` (mesh UV qua `_Terrain._add_quad_uv`): top face, bottom face (khi block dưới AIR/WATER, mul 0.40), 4 side (mul 0.62, UV tscale.y = side_height/SLAB).
- Layout block data native: `_idx = x*CHUNK_H*cols + y*cols + z` (CHUNK_H=69, Y_MIN=-18, SLAB=0.5, VOXEL=1.0).
- GD: `_native_ore_mesh()` bridge + `_force_s13_gd` + `_ore_mesh_from_arrays()` (wrap 4 arrays → ArrayMesh, gồm ARRAY_TEX_UV). Chỉ thay trong compute_chunk; `rebuild_mesh`/save-restore vẫn GD.
- A/B `tools\_native_ore_test.{gd,tscn}`: 13/13 PASS (trong 9 chunk chỉ 2 chunk có ore: (5,-3) IRON 318 + COAL 390 verts, (-3,7) COPPER 30 verts; 7 chunk còn lại rỗng — bit-exact cả verts/normals/colors/uvs).
- Profile (seed 20260802): S13b ore 0.79-0.80→0.68-0.70ms cả 3 chunk; chunk totals ~7.2-12.9ms.

### S5 river override chi tiết (WorldRiver)
- `src\world_river.{h,cpp}`: `WorldRiver::apply_river(wx0, wz0, cols, seed, biome(PackedInt32Array), height(PackedFloat64Array), factors(PackedFloat32Array))` → `{biome, height, river_flag}` — mirror S5 block nguyên cụm: loop 1024 ô (skip OCEAN_DEEP=6, factor<0), `bottom_var = _noise_river.GetNoise(wx*0.5, wz*0.5) * 1.5 * SLAB`, `deep_h = WATER_Y - 6*SLAB + bottom_var`, smoothstep `t = clamp(factor,0,1)²·(3-2t)`, lerp height (orig_h ≤ WATER_Y ? orig_h : max(orig_h, WATER_Y-0.1)), bed classification (bed_n <0.25 SAND / <0.55 MUDDY_SAND / else SILT) khi t<0.4, bank flatten (orig_heights copy + dirs4, h=WATER_Y-0.1 + MUDDY_SAND).
- **Gotcha (đã sửa)**: Godot wrapper `FastNoiseLite` default `fractal_type = FRACTAL_FBM` / octaves 5 / lacunarity 2 / gain 0.5 / weighted 0 / pingpong 2 — áp trong constructor wrapper; còn header vendor default `FractalType_None`/3 octaves. Các port trước (S4/S2/S11/S11a) đều set FBM tường minh; S5 ban đầu quên → native dùng 1 octave, GD FBM 5 octave → height-chỉ diff ~3e-2 (biome khớp vì bed noise hiếm khi vượt ngưỡng). Fix: set đủ `SetFractalType(FBm)+SetFractalOctaves(5)+SetFractalLacunarity(2)+SetFractalGain(0.5)+SetFractalWeightedStrength(0)+SetFractalPingPongStrength(2)` cho cả 2 noise. A/B cũ sai ở 2/9 chunk (chỉ HEIGHT DIFF, biome+river_flag khớp) → 9/9 sau fix.
- `factors_grid` + `set_curves` (spatial index 8×8, skey=ci*10000+i, 3×3 query) đã native trước — `river_distance_factors` GD gọi thẳng nên factor grid giống nhau ở cả 2 path.
- GD: `_force_s5_gd` toggle; S5 block refactor (native push bflat5/hflat5 → apply_river → copy ngược; fallback gồm cả bank flatten gating `not r5_native`).
- A/B `tools\_native_river_override_test.{gd,tscn}`: 9/9 PASS bit-exact (biome_grid + height_grid + river_flag).
- Profile (seed 20260802, chunk(5,-3) 242 river cells): S5 stage 0.41-0.53ms cả 2 path; chunk totals ~8.5-9ms.

### S8 terrain_mesh chi tiết (WorldTerrain.build_terrain_mesh_mesh)
- `src\world_terrain.{h,cpp}`: tách `static MeshBuilder build_geometry(...)` (toàn bộ greedy mesher từ đầu `build_terrain_mesh`) + `fill_packed_arrays()`; giữ `build_terrain_mesh` (Dictionary) cho `_native_terrain_test`, THÊM `Ref<ArrayMesh> build_terrain_mesh_mesh(...)` — instantiate ArrayMesh + `add_surface_from_arrays` ngay trong C++, bỏ Dictionary round-trip + GD-side ArrayMesh assembly.
- GD: `chunk_terrain.gd:build_terrain_mesh_native` gọi `wt.build_terrain_mesh_mesh(...)` trực tiếp, return null nếu `m == null or m.get_surface_count() == 0`; `world_chunk.gd` S8 call site giữ nguyên (null → fallback GD SurfaceTool).
- A/B `tools\_probe_s8_time.gd` (tạm, đã xóa): so từng vertex/normal/color `==` giữa native mesh vs GD SurfaceTool commit → 4 chunk bit-exact 0/12282, 0/12672, 0/10854, 0/7026 mismatch.
- Profile (seed 20260802): native_mesh 0.98-1.19ms vs GD fallback 7.9-14.8ms; hint loop 0.13-0.16ms.
- Lưu ý: tốc độ ~bằng path Dictionary cũ (cpp_marshal 0.33-0.43 + arr_mesh 0.73-0.95) — hiệu quả chính là bỏ 2 lớp marshal Variant, không tối ưu mesher (buildphase chỉ ~0.3ms).

### S1+S2 flat bio chi tiết (WorldBfsDst.bfs_dst_flat)
- Trước: `chunk_noise._biome_grid` gọi native `compute_biome_grid` (trả flat PackedInt32Array) rồi GD wrap 42²→`Array[Array]` bio; S2 native `bfs_dst` đọc từng cell qua Variant boxing (`bio_at`), S4 native re-flatten bio→bio_flat (~0.16ms).
- Sau: compute_chunk S1 giữ thẳng flat native (nếu có DLL) — `bio_flat` dùng trực tiếp cho S2 (`bfs_dst_flat`) + S4 (`land_grid`); `bio` Array[Array] chỉ build lazy qua `_bio_from_flat` khi GD fallback chạy (S4 fallback / non-REAL branch / force-gd). Add `WorldBfsDst::bfs_dst_flat` (đọc flat trực tiếp, giữ `bfs_dst` bọc-flatten cho test).
- A/B: `_native_bfsdst_test` 15/15 (REAL + TWILIGHT), biome/land/dist/ocean/fill 0-fail, tổng 13 suites green.
- Profile (seed 20260802): S2 0.12-0.28→0.03-0.13ms; S1 ~0.55-0.74 (nhẹ hơn). S4 vẫn 0.82-1.42 (đa phần land_grid computation thật).

### S13b gate scan chi tiết (WorldOre.scan_textured_blocks)
- Trước: dù chunk KHÔNG có ore, GD vẫn chạy 2 scan loop tốn ~0.68-0.70ms/chunk: (1) `max_top_ly` = max top_ly_hint over cols², (2) `has_ore_blocks` = top-layer textured-block check qua `bd.get_block` (bounded calls `_TEXTURED_BLOCK_IDS`). Phần lớn là chi phí GDScript function-call `get_block` (bounds-check + index) × cols².
- Sau: thêm `WorldOre::scan_textured_blocks(data(PackedByteArray), cols, top_ly_hint)` → `PackedInt32Array [max_top_ly, has_ore]` — scan 1 pass C++: max top_ly_hint + lookup `seen[256]` texture-id table tại lớp top_ly_hint (đúng 1 lớp, không scan depth). GD giữ `ore_hill_info.cx>=0` làm OR gate (không đụng tới — cheap).
- GD: S13b block refactor: `ore_native` tính trước → native scan khi có DLL, GD loop scan chỉ chạy khi forced-gd/null DLL. Mesh build giữ nguyên (native `build_textured_block_mesh` / fallback `_build_textured_block_meshes`).
- A/B: `_native_ore_test` 13/13 PASS — scan C++ cho has_ore/max_top_ly khớp hẳn GD loop (2 chunk có ore (5,-3)/( -3,7) cho mesh verts/normals/colors/uvs bit-exact; 7 chunk rỗng). 13 regression suites green.
- Profile (seed 20260802, chunk(0,0))/(1,0)/(-302,-230): S13b 0.68-0.70 → 0.03-0.06ms; chunk total giảm ~0.65ms.

### S3 marshalling lazy chi tiết (world_chunk.gd S3 block)
- Trước: sau `oc.ocean_grid` native, GD vẫn build `oct` (Array[Array] 84²) rồi `oct_small` (total²) một cách vô điều kiện — nhưng chỉ GD fallback (oc==null / dist BFS fallback / S4 fallback) mới đọc 2 mảng này → mất ~0.7ms/chunk.
- Sau: `oct`/`oct_small` khởi tạo rỗng; chỉ build trong các nhánh fallback: (a) `oc==null` (GD ocean stride-2 cần oct để sinh s3_grid), (b) `odst.size()!=total²` → `_oct_from_grid(s3_grid, oct_total)` + `_oct_small_from_oct(...)`, (c) `if not s4_native_ok:` → đảm bảo cả 2 mảng.
- Native path đầy đủ (ocean+dist+land C++) không còn đụng Array[Array] nào — s3_grid/odst/shore_dst/oct_mask đi thẳng bằng Packed arrays.
- A/B: `_native_land_test` (force S4 GD giữ native ocean+dist) + probe tạm force `_force_s6_gd` — 9/9 chunk biome/height/river_flag bit-exact maxdiff 0; 12 regression suites green.

### S4 lake-noise cache chi tiết (WorldLand.land_grid)
- Trước: noise `lake` (5-octave FBM) được gọi GetNoise tới 3 lần cho cùng 1 ô (32²): main pass (nhánh FROST/SWAMP/GRASSLAND), lake mask loop (total² = 42², tìm ô hồ trên GRASS_DIRT), lake fill loop (lại từng ô lm≠0). ≈ 2× công thừa của noise đắt nhất trong stack.
- Sau: thêm lambda `lake_at(pvx,pvz)` với cache mảng `lake_raw[total*total]` (sentinel −2) — mỗi ô chỉ tính lake 1 lần; 3 loop cùng đọc cache. Toạ độ đồng nhất `wx0+(pvx-PAD)+0.5` (các loop vốn đã dùng cùng công thức → bit-exact aut và không đổi output).
- Thử song song hoá main loop theo hàng `std::thread` (cols=32, 12 core): spawn+join 11 threads ~0.3-0.9ms ≈ thời gian computation (1024 ô / 12 luồng + FBM bandwidth-bound trên cùng LUT), và thread bên trong per-chunk còn cạnh tranh WorkerThreadPool của game (nhiều chunk chạy song song) → hoàn lại, chỉ giữ cache.
- A/B: `_native_land_test` 9/9 PASS maxdiff 0.0 (biome+height+reef). 14 regression suites green (thêm `_native_bfsdst_test` 15 PASS).
- Profile (seed 20260802, 3 chunk): S4 land_grid 0.77-1.03 → 0.56-0.66ms; S4 total ~1.0-1.4 → 0.80-0.91ms (prep 0.02 + call + copy-back 0.21).

### S5 marshalling tối ưu chi tiết (world_chunk.gd S5 block)
- Trước: dù `apply_river` đã native, GD vẫn (a) rebuild `bflat5/hflat5` từ grids 32², (b) build `orig_heights` vô điều kiện, (c) copy-back toàn bộ 32² biome/height/river_flag → ~0.26ms marshalling không cần thiết.
- Sau:
  - Hoist `s4_native_ok`/`b4`/`h4` lên function scope (trước `if dim_id == REAL_WORLD` — GDScript block-scope không chia sẻ giữa S4 và S5) → S5 reuse `b4/h4` thẳng làm `bflat5/hflat5` (grid không đổi từ sau S4 native) khi `s4_native_ok`; else rebuild như cũ. S5b flatten 0.28 → 0.02-0.03ms.
  - `orig_heights` build lazy vào nhánh `not r5_native` (bản gốc build mọi path) — nhưng phải capture NGAY TRƯỚC river override loop (override mutate `height_grid` cho cell sông). Bug gặp khi đặt build SAU override: `orig_heights` chứa height đã đào sông → flatten thừa ô (nghĩ neighbor là hồ) → `_native_river_override_test` 2 fail (8 pass) ở các ô sông giáp bờ chunk(0,0)/(5,-3), gd=0.400000 (WATER_Y-0.1) vs nat 0.53-1.12. Fix = build trước override → 10/10 PASS.
  - Copy-back chỉ cell sông (`rf5[i] != 0`) khi `s4_native_ok` + flat size đủ (native chỉ đổi cell sông; cell khác == grids hiện tại từ S4) → S5c apply+copy 0.16-0.45 → 0.07-0.45ms (chunk(1,0) vẫn nặng vì nhiều river cell).
- A/B: `_native_river_override_test` 10/10 PASS + `_native_river_test` 0 fail; full 14 regression suites green.
- Profile (seed 20260802, 3 chunk): S5a factors 0.09-0.32 (river_distance_factors C++), S5b flatten 0.02-0.03, S5c apply+copy 0.07-0.45, S5 river (native apply_river) 0.03-0.08; S5 total ~0.28-0.58 → ~0.28-0.49ms.
- Commit `6cb3865` (S5 marshalling opt) — DLL + world_chunk.gd + NATIVE_PORT_SUMMARY.md.

### S10/S7/S4-copy khảo sát thêm — kết luận: đã tối ưu sát
- S10 water_mesh split (marker tạm): S10a has_water+water_skip (GD loops) 0.10-0.11, S10b native call (build_water_mesh C++) 0.11-0.16, S10c from_arrays (engine add_surface_from_arrays) 0.22-0.49ms → giống S8: phần lớn là engine upload không cắt được.
- S7 fill_blocks split (Time print tạm trong `_fill_blocks_native`): flatten GD (bio/hgt flat từ grids) 0.09-0.12, native fill_blocks C++ 0.09-0.12ms → cả 2 đều nhỏ, không đáng port flatten (chỉ ~0.1ms).
- S4 copy-back (marker tạm S4b/S4c): copy 32² (biome+height+beach+reef) ≈ 0.15-0.2ms + dmask 42² 0.06ms — cần thiết vì S5-S13 đọc Array[Array]; không tách được khỏi computation S4 (land_grid native 0.56-0.66ms là chính).
- S6b bfs_water đã native (bfs_grids). S1 biome_sample 0.51-0.55ms = native compute_biome_grid noise stack thật — khó cắt hơn nữa.

### S8 khảo sát sâu (WorldTerrain timers) — kết luận: đã tối ưu sát
- Split GD bằng marker tạm S8a top_ly / S8b native build: S8a 0.14-0.22ms (loop GD top_ly_hint), S8b 0.83-2.97ms.
- Thêm timer C++ trong `build_terrain_mesh_mesh` (`Time::get_ticks_usec` + print `[tdbg] geom/pack/surf/verts`): geom (greedy mesher) 174-885µs, pack (fill_packed_arrays) 61-286µs, surf (engine `add_surface_from_arrays`) 468-1054µs, verts 7026-12282.
- Kết luận: S8 đã tối ưu sát — `surf` là upload vertex thật của engine (không cắt được), geom/pack hợp lý. S8a top_ly (loop GD) 0.14-0.22ms có thể chuyển C++ sau nhưng ưu tiên thấp — không đào sâu thêm, chuyển sang S5/S10.

### S1 biome noise cache toàn cục chi tiết (WorldBiome)
- Trước: `compute_biome_grid` tính lại noise cho mọi ô 42² mỗi chunk — 2 chunk KỀ nhau sample trùng ~10 cột thế giới (chồng PAD) → tính lặp ~420 ô.
- Sau: thêm cell-cache vào mỗi `NoiseSet` (fixed-size open addressing linear probe): key = `_cell_key(wx,wz)` trộn cả 2 toạ độ (lần đầu `ix<<32 ^ iz` SAIBỞI slot chỉ mask low 18 bit → mọi ô collide vào ~43 slot → reset liên tục → sửa hash trộn `lo = ix*0x9E3779B1 + iz`, `hi = iz*0x85EBCA6B + ix`), `_CELL_CAP = 1<<15` (32K, đủ reuse vài chunk kề, nhỏ để nằm gọn cache CPU + reset chi phí thấp), `KEY_EMPTY = ~0ULL`, lookup probe ≤8, reset bảng khi đầy 50% (không double — cache chỉ cần reuse vùng lân cận).
- 2-pass đầu (lookup dưới cmtx → compute miss → insert dưới lock) TỐN overhead vector + 2 lock ⇒ chuyển 1-pass giữ lock cả grid (test sync; game gen từng chunk nối tiếp) — nhanh hơn và đơn giản hơn.
- `clear_cache()` (đổi seed) reset cả bảng; `cache_ensure_alloc` defer chỉ khởi tạo khi dùng (lần đầu 1 process ~0.3-0.6ms penalty).
- A/B: full 14 regression suites green (land 9/9, river_override 10/10, ...) — bit-exact, không đổi output.
- Profile (seed 20260802, 3 chunk): chunk ĐẦU 0.67-0.89ms (1 lần alloc penalty và ~14.5%), chunk kề (0,0)→(1,0) reuse 0.42-0.44ms (baseline ~0.51-0.55, field thắng ~0.1ms), chunk xa (-302,-230) 0.52-0.61 (chỉ lookup rechạy, không reuse). Lợi ích thực trên chunk kề, nằm gần nhiễu (~1% chunk total 6-10ms) — giữ vì rẻ và đúng.
- Vì chunk kề có ~420/1764 ô reuse nhưng biome noise chỉ chiếm 0.51-0.55/6-10ms, cache chỉ ~0.1ms; ý tưởng mở rộng sang land/lake noise (S4 lake đã tự cache trong chunk) không còn dư để hưởng lợi cross-chunk — dừng ở mức khả quan này.

## Đang làm
- (không — cache noise toàn cục S1 đã xong ở trên; các hotspot còn lại là computation thật hoặc engine upload không cắt được; cân nhắc batching nhiều chunk / worker thread khi generate)

## Hotspot hiện tại (test_prof_chunk, non-first chunks — bỏ artifact chunk đầu)
Sau S11a/S12/S9/S2/S10/S5/S8/S3-marshalling/S13b-scan/S1S2-flat-bio/S4-lake-cache, các phase còn lại lớn nhất (chunk(0,0) khi không đầu): S10 water_mesh 0.37-0.80, S1 biome_sample 0.52-0.56, S4 biome_grid+height 0.80-0.91 (land_grid 0.56-0.66 computation thật + copy-back 0.21), S8 terrain_mesh 0.87-1.97 (sau khảo sát: surf engine + geom/pack hợp lý — đã tối ưu sát, không đào sâu nữa), S5 river 0.28-0.49 (sau marshalling tối ưu), S3 ocean_mask+bfs 0.13-0.33, S11 aquatic+plants 0.30-0.36. S13b ore 0.03-0.06, S13c tavern ~0.02.
Lưu ý: chunk ĐẦU TIÊN trong 1 tiến trình luôn có S2 ~8ms (artifact harness: stdout flush/GC đầu compute — verified bằng reorder: chunk đầu nào cũng ~8ms, còn là 0.7-1.1ms).

## Next steps (candidates)
1. S8/S10 terrain+water — KHẢO SÁT XONG: engine add_surface_from_arrays upload không cắt được; các GD loop nhỏ (S8a top_ly 0.14-0.22, S10a has_water+skip 0.10-0.11) có thể chuyển C++ nếu muốn (ưu tiên thấp).
2. S5 river — XONG (marshalling opt, commit `6cb3865`).
3. S7 fill_blocks — KHẢO SÁT XONG: flatten 0.09-0.12 + native 0.09-0.12; không đáng port flatten.
4. S1 biome_sample (0.51-0.55ms) — ĐÃ LÀM cache noise toàn cục (xem S1-cache): chunk kề 0.42-0.44ms.
5. S4 copy-back 0.15-0.2ms + dmask 0.06ms — cần cho S5-S13; không tách được.
6. Ý tưởng mới: batching nhiều chunk / worker thread khi generate nhiều chunk — giảm qua per-chunk đã bão hòa.

## Triển khai tiếp
2. S13c tavern/village — bỏ qua (663 dòng, ~0.6ms, deterministic).
3. S9 tiếp: native trả flat `PackedFloat32Array` n×16 cho `_multimesh_buffer` trực tiếp (bỏ Variant boxing ~1.5ms+).
4. S13b ore — mesh build đã native; gate scan 0.68→0.03-0.06ms.
5. S1+S2 flat bio — ĐÃ XONG (xem trên).

## Relevant files
- `scripts\world\chunk\world_chunk.gd` — S9 wrapper + fallback (~683-709, 1955-1980), S12 (2022+), S11a bridge (_native_aquatic/_force_s11a_gd/_aquatic_mesh_from_arrays) + aquatic loop (~2094-2175), `_cell_hash01`, `_multimesh_buffer`.
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_grass.{h,cpp}` — native S9.
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_aquatic.{h,cpp}` — native S11a.
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_ore.{h,cpp}` — native S13b (build_textured_block_mesh + scan_textured_blocks).
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_river.{h,cpp}` — native S5 (apply_river + factors_grid + set_curves).
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_terrain.{h,cpp}` — native S8 (build_terrain_mesh_mesh).
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_biome.{h,cpp}` — native S1 (compute_biome_grid + cache noise toàn cục).
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_bfsdst.{h,cpp}` — native S2 (bfs_dst Array + bfs_dst_flat).
- `scripts\world\chunk\chunk_grass.gd` — nguồn tham chiếu (264 dòng, deterministic).
- `scripts\world\chunk\chunk_aquatic.gd` — nguồn tham chiếu S11a (383 dòng, deterministic).
- `scripts\world\chunk\village.gd` — giữ GD.
- `tools\_native_grass_test.{gd,tscn}` — A/B S9.
- `tools\_native_aquatic_test.{gd,tscn}` — A/B S11a.
- `tools\_native_ore_test.{gd,tscn}` — A/B S13b.
- `tools\_native_river_override_test.{gd,tscn}` — A/B S5.
- `tools\test_prof_chunk.tscn` — profile phases (seed 20260802, chunks [0,0],[1,0],[-302,-230]).
- DLL: `cpp\bin\native_test.windows.template_debug.x86_64.dll` (committed).

## Notes / gotchas
- `~native_test.windows.template_debug.x86_64.dll` backup trong `cpp\bin` bị lock (không xóa được), untracked, vô hại.
- Trong micro-bench không tái dựng được wdist/hdist nội bộ (S7 chỉnh height/biome sau S6b) → đo qua compute_chunk.
- `Basis.rows` chỉ có C++; GDScript dùng `basis.x/.y/.z`.