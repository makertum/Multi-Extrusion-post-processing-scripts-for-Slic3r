# Slic3r-Postprocessing-Scripts
useful postprocessing scripts for Slic3r, mostly adding dual extrusion features

# Project Status and compatibility
- [x] scripts are tested and working
- [x] compatible to absolute coordinate mode
- [x] compatible to relative extrusion mode
- [ ] not compatible to relative coordinate mode
- [ ] not compatible to absolute extrusion mode
- [ ] Slic3r environment variables cannot be read, therefore settings and parameters have to be manually declared within the custom "Start G-code"

## How to use
In order to get the scripts working properly, I suggest creating print and printer settings in slic3r exclusively for use with those scripts:

### In the print settings:
Add the full path to the script in the _Print Settings -> Output options -> Post-processing scripts_ field
I suggest only using one post-processing Script at a time.

### In the printer settings:
1. Tick "Use relative E distances" in Printer Settings -> General

2. In _Printer Settings -> Custom G-Code_, add the following to the very beginning of your "Start G-code", your own custom Start G-code can follow after that:
```
; WIPE TOWER PARAMS
; nozzleDiameter=[nozzle_diameter]
; filamentDiameter=[filament_diameter]
; extrusionWidth=[extrusion_width]
; layerHeight=[layer_height]
; firstLayerHeight=[first_layer_height]
; extrusionMultiplier=[extrusion_multiplier]
; firstLayerExtrusionMultiplier=4
; retractionLength=[retract_length]
; toolChangeRetractionLength=[retract_length_toolchange]
; bedWidth=[bed_size_X]
; bedDepth=[bed_size_Y]
; extruders=2
; wipeTowerX=80
; wipeTowerY=155
; wipeTowerW=10
; wipeTowerH=10
; wipeTowerSpacing=20
; wipeTowerLoops=5
; wipeTowerBrimLoops=7
; wipeOffset=2
; purgeOffset=1.33
; wipeLift=5
; travelLift=1
; purgeAmount=0.5
; retractionFeedrate=[retract_speed]
; travelFeedrate=[travel_speed]
; printFeedrate=[perimeter_speed]
; extrusionFeedrate=25
```

3. Also, add the following line to the very beginning of your "End G-Code", your own custom End G-Code can follow
```
; end of g-code
```

4. The "After layer change G-code" should consist of exactly that line:
```
; next layer
```

5. The "Tool change G-code" should consist of exactly that line:
```
; tool change
```
