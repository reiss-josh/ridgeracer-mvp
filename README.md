# ridgeracer-mvp

A simple racecar character controller, built from scratch using Godot's CharacterBody3D.

- DONE:
  - Acceleration / Gearing
    - Each gear has a top speed
    - The number of gears and their speeds are defined from a simple array export, and can be updated from the editor
    - The acceleration curve is defined by an editor-configured 2D Curve
    - Engine sound plays at pitch proportional to current RPM
  - Multiple cameras
    - Bumper, Hood, Chase, Top-down, and Rear-Chase cameras
    - Each camera has its own animations for juice. These animations are affected by the car's acceleration/turning.
  - Steering
    - Configurable maximum wheel angle (default 45 degrees)
    - Configurable maximum per-second turn angle (default 5 degrees)
  - Floor alignment
    - Four raycasts (one per wheel) used to draw 2D floor plane beneath the car
    - Car aligns its y-basis with floor plane at configurable rate
  - Collisions
    - Car aligns itself with vector perpendicular to collision normal of walls
    - (This results in the car always trying to turn away from points of impact, so you can keep racing!)
- TODO:
  - Drifting
  - Feel-tuning
  - Jitter management
  - Hills (roll down them, decrease acceleration going up them)
  - Reverse gear
  - Other cars / multiplayer
  - Actual race courses
  - Speed impact when crashing
 
Currently unsure how to get a nice-feeling drift, or remove the collision jitter, without completely reworking all of the acceleration/gearing/steering code. :(
