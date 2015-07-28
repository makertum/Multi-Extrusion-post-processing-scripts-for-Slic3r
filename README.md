# Multi-Extrusion post-processing scripts for Slic3r
useful postprocessing scripts for Slic3r for adding wipe towers and other multi-extrusion features. Written in Perl.
![example g-code](http://i.imgur.com/lOzlO5L.png)
## Available scripts
### wipe_towers_tc.pl
- adding wipe towers
- resorting print order to a sequential build for finest results
- highly configurable

## Changelog
### to do
- [ ] not compatible to relative coordinate mode
- [ ] not compatible to absolute extrusion mode
- [ ] Slic3r environment variables cannot be read, therefore settings and parameters have to be manually declared within the custom "Start G-code"
- [ ] clean up the code and find a readable structure
- [ ] add workaround for Slic3rs lack of retraction on print start for inactive extruders

### v1
- [x] scripts are tested and working
- [x] printing results are spotless and really awesome
- [x] compatible to absolute coordinate mode
- [x] compatible to relative extrusion mode

### v2
- [x] some bugfixes, including support for >2 extruders, suggested by PxT (thx!!)
- [x] added optional parameter "forceToolChanges", defaults to true
- [x] travelLifts now happen in both directions

## How to use
In order to get the scripts working properly, I suggest creating print and printer settings in slic3r exclusively for use with those scripts, and modifying these settings as described below.

### Installation
Copy the scripts to a directory of your choice, note that directory.

### In the print settings:
Add the full path to the script as noted above in the _Print Settings -> Output options -> Post-processing scripts_ field
I suggest only using one post-processing Script at a time.

### In the printer settings:
1. Tick "Use relative E distances" in Printer Settings -> General

2. In _Printer Settings -> Custom G-Code_, add the following to the very beginning of your "Start G-code", your own custom Start G-code can follow after that:
```
; WIPE TOWER PARAMS
; forceToolChanges=true
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

## Disclaimer / License
I've never written a line of Perl before this project. I'm still learning, but also had to make this work. Any suggestions are heavily welcome.
All scripts in this repository are licensed under the GPLv3 with me, Moritz Walter, as the author.
