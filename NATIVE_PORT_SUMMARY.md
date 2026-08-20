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
| S5 river override (WorldRiver.apply_river) | (S5) | S5 river 0.42-0.53ms (bỏ hẳn loop GD); A/B 9/9 bit-exact (chunk(0,0) 14 river cells, chunk(5,-3) 242 cells) |
| S8 terrain_mesh (WorldTerrain.build_terrain_mesh_mesh) | (S8) | S8 1.08-1.38→0.98-1.19ms (ArrayMesh C++ trực tiếp, bỏ Dictionary round-trip); bit-exact 0/12282 mismatch vs GD fallback; 13 regression suites green |
| S3 marshalling lazy (bỏ oct/oct_small GD khi native) | (S3) | S3 ocean_mask+bfs 0.91-1.30→0.13-0.33ms; oct/oct_small (Array[Array] 84²+total²) build lazy chỉ khi GD fallback chạy; native path không còn ~0.7ms marshalling vô ích; 9/9 forced-GD A/B bit-exact + 12 suites green |
| S13b gate scan (WorldOre.scan_textured_blocks) | (S13b2) | S13b ore 0.68-0.70→0.03-0.06ms; scan gate (max_top_ly + has_ore_blocks) chuyển sang C++ — GD chỉ còn 2 loop get_block/column khi forced-gd; A/B 13/13 + 13 regression suites green |

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

## Đang làm
- (không — S13b gate scan vừa xong; đang xét tiếp hotspot)

## Hotspot hiện tại (test_prof_chunk, non-first chunks — bỏ artifact chunk đầu)
Sau S11a/S12/S9/S2/S10/S5/S8/S3-marshalling/S13b-scan, các phase còn lại lớn nhất (chunk(0,0) khi không đầu): S4 biome_grid+height 0.90-1.12 (land_grid native — computation thật), S8 terrain_mesh 0.93-2.18, S5 river 0.46-0.61, S3 ocean_mask+bfs 0.14-0.34, S10 water_mesh 0.39-0.87, S11 aquatic+plants 0.31-0.37, S13b ore 0.03-0.06 ("đã xong" về mặt lý thuyết nhưng gate scan còn nhỏ). S13c tavern nhỏ (~0.03).
Lưu ý: chunk ĐẦU TIÊN trong 1 tiến trình luôn có S2 ~8ms (artifact harness: stdout flush/GC đầu compute — verified bằng reorder: chunk đầu nào cũng ~8ms, còn là 0.7-1.1ms).

## Next steps (candidates)
1. S4 biome_grid+height (0.90-1.12ms) + S8 terrain_mesh (0.93-2.18ms) — còn lại lớn nhất; S4 land_grid native là computation thật (824 ô × noise stack) — đã đo split: bio_flat 0.16 + land_grid_call 0.60-0.79 + copy-back 0.22-0.23 (marshalling GD ~0.37ms, khó cắt vì biome_grid/height_grid là Array[Array]).
2. S13c tavern/village — bỏ qua (663 dòng, ~0.6ms, deterministic).
3. S9 tiếp: native trả flat `PackedFloat32Array` n×16 cho `_multimesh_buffer` trực tiếp (bỏ Variant boxing ~1.5ms+).
4. S13b ore — mesh build đã native; gate scan mới xong 0.68→0.03-0.06ms.

## Relevant files
- `scripts\world\chunk\world_chunk.gd` — S9 wrapper + fallback (~683-709, 1955-1980), S12 (2022+), S11a bridge (_native_aquatic/_force_s11a_gd/_aquatic_mesh_from_arrays) + aquatic loop (~2094-2175), `_cell_hash01`, `_multimesh_buffer`.
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_grass.{h,cpp}` — native S9.
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_aquatic.{h,cpp}` — native S11a.
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_ore.{h,cpp}` — native S13b (build_textured_block_mesh + scan_textured_blocks).
- `C:\Users\gnasv\AppData\Local\Temp\opencode\src\world_river.{h,cpp}` — native S5 (apply_river + factors_grid + set_curves).
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