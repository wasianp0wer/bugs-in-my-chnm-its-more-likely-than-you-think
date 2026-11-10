# RRCHNM main room: estimated dimensions

These are estimated from `Research-Fourth-Floor-Plan.pdf`, the GMU "Architectural Rooms" plan of Research Hall, floor 4. The blue outline on that plan marks the main room.

## Scale

The plan has no scale bar, so the scale comes from the building outline in OpenStreetMap (way 119503843):

- **Building length:** about 96.6 m. On the plan it measures about 735 px, so 1 px ≈ 0.131 m.
- **Cross-check on depth:** the main bar is about 163 px deep on the plan, which gives about 21.4 m. OpenStreetMap gives about 21–24 m for the ends, so the scale agrees.

Expect an error of about ±10–15%.

## Outlined area

The outline covers rooms 461, 462, 472, 479, 470 and 478. It is L/T-shaped, with the long axis running east–west along the north side of the building.

| Section | Rooms | Approx. size (E–W × N–S) |
|---|---|---|
| North-west block | 462, 472 | 10.2 m × 10.7 m |
| West notch | 461 (beside Pantry 1) | 2.9 m × 4.8 m |
| East band | 479, 470, 478 (upper part) | 18.3 m × 6.8 m |
| South-east extension | 470, 478 (lower part, toward CORR1) | 11.1 m × 4.1 m |

- **Overall bounding box:** about 32 m (E–W) × 15 m (N–S).
- **Floor area:** about 290 m² (about 3,150 sq ft).
- **Ceiling height:** assumed to be 2.9 m (9.5 ft), a typical value for an office building of this period. It is not measured.

## Back wall flattened (the user's correction, Task 15)

The plan shows the east band's north wall about 3.9 m south of the 462/472 block's. The user says the real back wall is flat, with no alcove, so the sim pushes the band north to meet it. The whole north wall, from x = 2.9 to x = 31.5, is now one straight wall at z = 0. The table above is the PDF estimate; the sim uses:

- **East band rect (x, z, w, d):** (13.1, 0.0, 18.4, 10.7), was (13.1, 3.9, 18.4, 6.8).
- **Outline:** (0, 5.9), (2.9, 5.9), (2.9, 0), (31.5, 0), (31.5, 14.8), (20.3, 14.8), (20.3, 10.7), (0, 10.7).
- **Floor area:** 365.9 m² (was 294.1 m²). The bounding box is unchanged at 31.5 × 14.8 m.

## Sources

- The floor plan PDF in this directory.
- OpenStreetMap building footprint: https://www.openstreetmap.org/way/119503843
- GMU Construction project archive (four-story, 100,000 sq ft): https://construction.gmu.edu/project-archive
