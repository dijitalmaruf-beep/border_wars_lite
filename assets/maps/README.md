# World Map Assets

These assets provide the real-world visual board for Chroma Conquest.

- `world_base.png`: optimized raster base map generated from Natural Earth 110m Admin 0 country boundaries.
- `world_borders.svg`: optimized SVG border overlay generated from the same Natural Earth country boundaries.

Natural Earth data is public domain. Source dataset:
https://naturalearth.s3.amazonaws.com/110m_cultural/ne_110m_admin_0_countries.zip

The Flutter map renders these files as fixed layers and draws gameplay ownership, selection highlights, and army labels over them. To improve final art quality later, replace `world_base.png` and/or `world_borders.svg` with matching 2:1 world-map assets using the same normalized coordinate system.
