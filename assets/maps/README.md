# World Map Assets

These assets provide the real-world visual board for Chroma Conquest.

- `world_base.png`: optimized 2048x1024 2.5D raster base map generated from the Natural Earth-derived board mask with procedural ocean depth, coastline glow, and land relief styling.
- `world_borders.svg`: optimized SVG border overlay generated from the same Natural Earth country boundaries.

Natural Earth data is public domain. Source dataset:
https://naturalearth.s3.amazonaws.com/110m_cultural/ne_110m_admin_0_countries.zip

The Flutter map renders these files as fixed layers and draws gameplay ownership, selection highlights, route cues, and army labels over them. The current implementation intentionally keeps the 2:1 normalized coordinate system so territory hit testing and gameplay data remain stable while the board reads as a premium 2.5D command-map/globe surface.

To improve final art quality later, replace `world_base.png` and/or `world_borders.svg` with matching 2:1 world-map assets using the same normalized coordinate system.
