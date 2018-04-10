extensions [gis matrix rnd r]
breed [fires fire]
breed [cores core]


globals [
  minimum                                      ;; Mimimum elevation value within the GIS map. This value will be used to display the an elevation map in multiple processes
  maximum                                      ;; Maximum elevation value within the GIS map. This value will be used to display the an elevation map in multiple processes
  count-fires                                  ;; Global to count the number of fires burning on the landscape
  ignition-prob-map                            ;; Map of land-use probability estimates derrived from archaeological survey data or map of lightning strike ignition probability derrived from lghtning caused fire data form the European Union (1990-2010)
  ignition-prob-mean                           ;; Mean of the current ignition probability map - used to evaluate probability cut-offs
  ignition-prob-sd                             ;; Standard deviation of the current ignition probability map - used to evaluate probability cut-offs
  base-map                                     ;; GIS base map for setting up world
  wind-vel-map                                 ;; GIS base map for wind velocity
  wind-ang-map                                 ;; GIS base map for wind angle
  target-patches                               ;; Patches targeted for deposition
  fuels-1h-biomass                             ;; Available live and dead biomass for 1-hour fuel size classes
  fuels-10h-biomass                            ;; Available live and dead biomass for 10-hour fuel size classes
  fuels-1h-plume                               ;; Resulting maximum plume from combustion of for 1-hour fuel size classes, wind is set at 0 meters per sec
  fuels-10h-plume                              ;; Resulting maximum plume from combustion of for 10-hour fuel size classes, wind is set at 0 meters per sec
  ignition-counter                             ;; Global variable for tracking the number of ignitions on the landscape per year
  spread-counter                               ;; Global variable for tracking the number of patches bruning created through spread on the landscape per year
  ]

fires-own [
  biomass                                      ;; Biomass used for combustion, based on 1-hour or 10-hour biomasses in each patch
  fire-wind-vel                                ;; wind velocity at a burning patch
  plume                                        ;; Initial plume, based on elevation and fuels
  biomass-charcoal-particles-conversion-25     ;; Conversion of biomass to charcoal mass (based on Gavin, 2001) and then subsequent division into particles per 25µm size gradient (based on Pitkänen 1999)
  biomass-charcoal-particles-conversion-150    ;; Conversion of biomass to charcoal mass (based on Gavin, 2001) and then subsequent division into particles per 150µm size gradient (based on Pitkänen 1999)
  plume-mod                                    ;; Modified plume due to wind velocity (Clark 1988: equation 5)
]

cores-own [
  charcoal-25                                  ;; Raw count of 25µm charcoal
  charcoal-25-interim                          ;; Interim count of 25µm charcoal -- used for aggregation
  deposit-25                                   ;; Final, deposited count of 25µm charcoal
  charcoal-150                                 ;; Raw count of 150µm charcoal
  charcoal-150-interim                         ;; Interim count of 150µm charcoal -- used for aggregation
  deposit-150                                  ;; Final, deposited count of 150µm charcoal
  dist-from-fire                               ;; Euclidean istance between any given fire and the sample location
  x-fire                                       ;; X distance between any given fire and the sample location
  y-fire                                       ;; Y distance between any given fire and the sample location
  theta                                        ;; inverse wind driection
]
patches-own [
  ignition-prob                                ;; numerical value that represents the porbability of ignition for a given patch based on the itsmlikelyhood to be burned via anthropogenic or natural processes
  elevation                                    ;; elevation paramter from DEM
  wind-vel                                     ;; Wind data created by WindNinja using average wind conditions in the Canal de Navarres as modified by topography
  wind-ang                                     ;; Wind data created by WindNinja using average wind conditions in the Canal de Navarres as modified by topography
  burn-counter                                 ;; records the location of each fire on landscape for raster output
]

to setup-world
clear-all
    set base-map "DATA/rasters/navarres_elevation.asc"          ;; lets raster base-map file be loaded from behavior space or command line
    set wind-vel-map "DATA/rasters/navarres_wind_30m_vel.asc"   ;; lets raster wind veleocity map file be loaded from behavior space or command line
    set wind-ang-map "DATA/rasters/navarres_wind_30m_ang.asc"   ;; lets raster wind angle map file be loaded from behavior space or command line
  let world-wd 0
  let world-ht 0
  set base-map gis:load-dataset base-map
  set wind-vel-map gis:load-dataset wind-vel-map  ;; load GIS maps of wind velocity and angle
  set wind-ang-map gis:load-dataset wind-ang-map
  let gis-wd gis:width-of base-map
  let gis-ht gis:height-of base-map
  set world-wd (gis-wd / world-size-adjustment)
  set world-ht (gis-ht /  world-size-adjustment)
  resize-world 0 (world-wd - 1) 0 (world-ht - 1) ;
  gis:set-world-envelope (gis:envelope-of base-map)
  gis:apply-raster base-map elevation
  set minimum gis:minimum-of base-map
  set maximum gis:maximum-of base-map
  gis:apply-raster wind-vel-map wind-vel          ;; Set patch attributes for wind data from GIS maps of wind velocity and angle
  gis:apply-raster wind-ang-map wind-ang
  ask patches [set burn-counter 0]
end

to setup-ignition-probability-maps   ;; Set up ignition probability maps based on user selected ignition scenarios
  if (Ignition-Distribution = "Land-use") [set ignition-prob-map "DATA/rasters/Land_use_intensity_navarres.asc"]
  if (Ignition-Distribution = "Natural-lightning") [set ignition-prob-map "DATA/rasters/lightning_elevation_ridges_probability.asc"]
  set ignition-prob-map gis:load-dataset ignition-prob-map
  gis:apply-raster ignition-prob-map ignition-prob
  set ignition-prob-mean mean [ignition-prob] of patches
  set ignition-prob-sd standard-deviation [ignition-prob] of patches
end

to setup-fuels
  file-open "DATA/fuel-parameters.txt" ; biomass of 1-hour fuels and 10-fuels based on observations from Anderson 1982 - units g/cell (30x30m); plume hieghts calculated from HHR from Mobley, H.E., 1976 - units meters
  let fuel-parameters-list file-read ;; Reads, parses, stores entire literal list
  let fuel-parameters-matrix matrix:from-row-list fuel-parameters-list
  file-close
  set fuels-1h-biomass matrix:get fuel-parameters-matrix (Fuel-Model - 1) 0 ;; Map the correct biomass values to the correct fuels in the parameters matrix
  set fuels-1h-plume matrix:get fuel-parameters-matrix (Fuel-Model - 1) 1
  set fuels-10h-biomass matrix:get fuel-parameters-matrix (Fuel-Model - 1) 2
  set fuels-10h-plume matrix:get fuel-parameters-matrix (Fuel-Model - 1) 3
end


to display-world
  if (Map-Display = "Topography") [  ;; Create color display for model world
    ask patches [if (elevation >= 0) [ set pcolor scale-color 35 elevation minimum maximum ] ]]
  if (Map-Display = "Fuels") [ask patches [set pcolor 55 ]]
  if (Map-Display = "None") [no-display]
end

to setup-cores  ;; set up sample core location and all of its attributes
  let sample-num []
  if (sample-loc = "Location-1") [set sample-num 0]
  if (sample-loc = "Location-2") [set sample-num 1]
  if (sample-loc = "Location-3") [set sample-num 2]
  let sample-loc-dataset gis:load-dataset "data/navarres_sample_locations/navarres_core_locations.shp"
  let feature-list gis:feature-list-of sample-loc-dataset
  let vertex-list gis:centroid-of item sample-num feature-list
  let xy-list gis:location-of vertex-list
  create-cores 1 [
    setxy (item 0 xy-list) (item 1 xy-list) ;; set up core location
      set size 4
      set label "Sample Location     " ;; set up core label
      set color 45
      set shape "square"
    ask cores[set charcoal-25 (list 0 ) set charcoal-150 (list 0 )]
    ask cores[set charcoal-25-interim (list 0 ) set charcoal-150-interim (list 0 )]
    ask cores[set deposit-25 0 set deposit-150 0]
  ]
end


to setup-fires ;; sets up fire agents on the landscape based on user inputs
  set target-patches patches with [ignition-prob >= Probability-Cutoff ]
  if Display-Prob? [ask target-patches [set pcolor scale-color 125 elevation minimum maximum]]
  if (Ignition-Scenario = "Swidden") [
    ask rnd:weighted-n-of random-poisson Mean-anth-fire-freq target-patches [ignition-prob ] [
    sprout-fires 1 [
      set size 5
      set color 15
      set shape "fire"
      set heading [wind-ang] of patch-here
      set biomass fuels-10h-biomass
      set plume-mod fuels-10h-plume]]]
  if (Ignition-Scenario = "Pastoral") [
    ask rnd:weighted-n-of random-poisson Mean-anth-fire-freq target-patches [ignition-prob ] [
    sprout-fires 1 [
      set size 5
      set color 15
      set shape "fire"
      set heading [wind-ang] of patch-here
      set biomass fuels-1h-biomass
        set plume-mod fuels-1h-plume]]]
  if (Ignition-Scenario = "Natural") [
    ask rnd:weighted-n-of random-poisson Mean-natural-fire-freq target-patches [ignition-prob ] [
    sprout-fires 1 [
      set size 5
      set color 15
      set shape "fire"
      set heading [wind-ang] of patch-here
      let wildcard-biomass []
      let wildcard-plume []
      ifelse random-float 1 < 0.5 [
                 set wildcard-biomass fuels-1h-biomass
                 set wildcard-plume fuels-1h-plume]
                [set wildcard-biomass fuels-10h-biomass
                 set wildcard-plume fuels-10h-plume]
      set biomass wildcard-biomass
        set plume-mod wildcard-plume]]]
  if (Ignition-Scenario = "None")[]
end


to load-deposition-function
  let wd user-file
  r:eval (word "source('" wd "')") ; must change this full file path to the location of r script
end


to remove-NaNs ;; removes all NaN values from map edges
  ask patches[
    ifelse (elevation <= 0) or (elevation >= 0)
    [ set elevation elevation ]
    [ set elevation 0
      set ignition-prob 0
      set wind-vel 0
      set wind-ang 0
]]
end


to setup-parameters ;;set up all parameters
  setup-world
  setup-ignition-probability-maps
  setup-fuels
  setup-cores
  display-world
  setup-fires
  remove-NaNs
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
 tick
 ask fires [die]
 setup-fires
  set ignition-counter count fires
  if (Ignition-Scenario = "Pastoral" or Ignition-Scenario = "Natural") [spread-fires]
  set spread-counter count fires
 disperse-plume
 deposit
  ask cores[set charcoal-25 (list 0 ) set charcoal-150 (list 0 )]
 if (ticks / deposit-interval) >= deposition-events [
    let burn-locations gis:patch-dataset burn-counter
      ;; Export fire locations as raster map once run is done
    let filename (word "output/Fire_Map_" Probability-Cutoff "_" Mean-natural-fire-freq "_" Mean-anth-fire-freq "_" Fuel-Model "_" deposit-interval "_" deposition-events "natural.asc") ; files names with the following convention: Probability-Cutoff_Mean-natural-fire-freq_Mean-anth-fire-freq_deposit-interval_deposition-events
    gis:store-dataset burn-locations filename
    stop]
end

to spread-fires ;; procedure for fire agents to spread fire to neighboring patches
  ask fires
        [let current-fire self
          let spread-patches neighbors
          let spread-prob one-of [0 1 2 3 4 5 6 7 8]
          if count spread-patches > spread-prob
          [ask n-of spread-prob spread-patches[
          sprout-fires 1 [
            set size 5
            set color 15
            set shape "fire"
            set heading [wind-ang] of patch-here
              set biomass [biomass] of current-fire
            set plume-mod [plume-mod] of current-fire]]]
  ]
end

to disperse-plume
; Create plume and area of charcoal disperal
ask fires
        [let current-fire self
         let fire-x xcor
         let fire-y ycor
         let theta-fire heading
         set fire-wind-vel [wind-vel] of patch-here
         set plume plume-mod / fire-wind-vel
            let fallout-patches patches in-cone 100 89 with [distance current-fire > 0]

;Convert available biomass to number of particles produced through combustion
set biomass-charcoal-particles-conversion-25 ((((biomass * 0.02) * 0.4633) / 0.5)  / ((((25 / 2)^ 3) * 3.14) * ( 4 / 3) * (10)^ -12))
set biomass-charcoal-particles-conversion-150 ((((biomass * 0.02) * 0.3067) / 0.5)  / ((((150 / 2)^ 3) * 3.14) * ( 4 / 3) * (10)^ -12))

;Record burn on each cell
ask patch-here [set burn-counter  (burn-counter + 1)]

;Create all inputs for R code of 3d guassian plume model
if count cores-on fallout-patches > 0 [
             ask cores[
             set dist-from-fire distance current-fire
             let theta-raw (towardsxy fire-x fire-y) + 180
             if  theta-raw > 360 [set theta-raw theta-raw - 360]
             set theta abs subtract-headings theta-raw theta-fire
             set x-fire precision ((cos theta) * dist-from-fire * 30) -1 ; accomodates for the size of the cells in meters
                set y-fire precision ((sin theta) * dist-from-fire * 30) -1] ; accomodates for the size of the cells in meters

;Apply R code of 3d guassian plume model to core (must use <- in r:eval of disperse.x.y.u.h.d)
r:put "x" [x-fire] of core 0
r:put "y" [y-fire] of core 0
r:put "u" fire-wind-vel
r:put "h" plume
r:put "d" 25
r:eval "conc <-disperse.x.y.u.h.d(x,y,u,h,d)"
ask cores [set charcoal-25 (lput ((r:get "conc") * [biomass-charcoal-particles-conversion-25] of current-fire) charcoal-25)] ;difussion equation via r and then multiply it by the amount of charcoal particles produced. Then convert to particles/cm3
r:put "d" 150
r:eval "conc <-disperse.x.y.u.h.d(x,y,u,h,d)"
ask cores [set charcoal-150 (lput ((r:get "conc") * [biomass-charcoal-particles-conversion-150] of current-fire) charcoal-150 )]]] ;difussion equation via r and then multiply it by the amount of charcoal particles produced. Then convert to particles/cm3
   end

to deposit
  ; deposit charcaol at sample location, aggregate results
  ask cores [
    set charcoal-25-interim lput (reduce + charcoal-25) charcoal-25-interim
    set charcoal-150-interim lput (reduce + charcoal-150) charcoal-150-interim
   if length charcoal-25-interim = deposit-interval [
         set deposit-25 (reduce + charcoal-25-interim)
         set charcoal-25-interim (list 0)]
    if length charcoal-150-interim = deposit-interval [
         set deposit-150 (reduce + charcoal-150-interim)
         set charcoal-150-interim (list 0)]
      ]
end
@#$#@#$#@
GRAPHICS-WINDOW
179
16
970
553
-1
-1
3.0
1
10
1
1
1
0
0
0
1
0
260
0
175
0
0
1
Ticks
30.0

BUTTON
85
663
163
696
3. Run
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
182
580
494
613
Mean-natural-fire-freq
Mean-natural-fire-freq
0
3
0.01
.01
1
per year
HORIZONTAL

BUTTON
6
663
83
696
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
975
466
1573
699
Total Charcoal Frequency at Sample Location
NIL
NIL
0.0
5.0
0.0
500.0
true
true
"" ""
PENS
"  Total            " 1.0 0 -16777216 true "" "plot (([deposit-25] of core 0) + ([deposit-150] of core 0))"

SLIDER
501
629
964
662
deposit-interval
deposit-interval
0
500
85.0
1
1
years represented in 1 cm of deposition
HORIZONTAL

SLIDER
501
666
964
699
deposition-events
deposition-events
101
5001
101.0
100
1
obs.
HORIZONTAL

INPUTBOX
8
86
160
162
world-size-adjustment
2.6
1
0
Number

BUTTON
68
622
162
659
2. Setup All
setup-parameters
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
615
580
963
625
sample-loc
sample-loc
"Location-1" "Location-2" "Location-3"
0

PLOT
975
242
1573
461
Charcoal Frequency at Sample Location ( 150μm )
NIL
NIL
0.0
5.0
0.0
0.1
true
true
"" ""
PENS
"150μm           " 1.0 0 -16777216 true "" "plot ([deposit-150] of core 0)"

PLOT
972
15
1572
235
Charcaol Frequency at Sample Location ( 25μm )
NIL
NIL
0.0
5.0
0.0
0.1
true
true
"" ""
PENS
"25μm            " 1.0 0 -16777216 true "" "plot ([deposit-25] of core 0)"

MONITOR
182
655
315
700
Number of ignitions
ignition-counter
17
1
11

CHOOSER
8
36
159
81
Map-Display
Map-Display
"Topography" "Fuels" "None"
0

CHOOSER
12
552
165
597
Fuel-Model
Fuel-Model
1 4 6
0

SWITCH
8
169
160
202
Display-Prob?
Display-Prob?
0
1
-1000

CHOOSER
8
231
161
276
Ignition-Scenario
Ignition-Scenario
"Swidden" "Pastoral" "Natural" "None"
0

CHOOSER
8
276
164
321
Ignition-Distribution
Ignition-Distribution
"Land-use" "Natural-lightning"
0

TEXTBOX
183
556
398
582
Fire Frequency
12
0.0
1

TEXTBOX
501
558
716
584
Deposition Parameters
12
0.0
1

SLIDER
182
618
494
651
Mean-anth-fire-freq
Mean-anth-fire-freq
0
3
3.0
.01
1
per year
HORIZONTAL

TEXTBOX
18
602
233
628
Setup and Run Model
12
0.0
1

TEXTBOX
8
19
223
45
Landscape Parameters
12
0.0
1

TEXTBOX
15
209
230
235
Ignition Parameters
12
0.0
1

TEXTBOX
16
530
231
556
Fuel Parameters
12
0.0
1

SLIDER
8
325
164
358
Probability-Cutoff
Probability-Cutoff
0
1
0.32
0.01
1
NIL
HORIZONTAL

MONITOR
10
420
168
465
Ignition Map Mean
ignition-prob-mean
3
1
11

MONITOR
10
472
166
517
Ignition Map SD
ignition-prob-sd
3
1
11

TEXTBOX
10
370
173
443
Mean and SD of ignition map for reference when setting the ignition probability cutoff
11
0.0
1

MONITOR
318
655
493
700
Number of fires after spread
spread-counter
17
1
11

BUTTON
6
622
65
658
1. R code
load-deposition-function
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
8
703
492
814
Running this model:\n\n1. Select the file location of the R code used to evaluate the charcaol dispersion function. It is labeled \"guassian_plume_function.R\" in the model folder.\n\n2. Set up all other parameters\n\n3. Run the model\n
11
0.0
1

MONITOR
501
580
606
625
Number of obs
round(ticks / deposit-interval)
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fire
false
0
Polygon -7500403 true true 151 286 134 282 103 282 59 248 40 210 32 157 37 108 68 146 71 109 83 72 111 27 127 55 148 11 167 41 180 112 195 57 217 91 226 126 227 203 256 156 256 201 238 263 213 278 183 281
Polygon -955883 true false 126 284 91 251 85 212 91 168 103 132 118 153 125 181 135 141 151 96 185 161 195 203 193 253 164 286
Polygon -2674135 true false 155 284 172 268 172 243 162 224 148 201 130 233 131 260 135 282

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -7500403 true true 135 285 195 285 270 90 30 90 105 285
Polygon -7500403 true true 270 90 225 15 180 90
Polygon -7500403 true true 30 90 75 15 120 90
Circle -1 true false 183 138 24
Circle -1 true false 93 138 24

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Number of Runs - Natural" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-parameters</setup>
    <go>go</go>
    <metric>[deposit-25] of core 0</metric>
    <metric>[deposit-150] of core 0</metric>
    <metric>ignition-counter</metric>
    <metric>spread-counter</metric>
    <metric>[plume] of fires</metric>
    <metric>[biomass] of fires</metric>
    <steppedValueSet variable="Probability-Cutoff" first="0" step="0.1" last="0.9"/>
    <enumeratedValueSet variable="Ignition-Scenario">
      <value value="&quot;Natural&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ignition-Distribution">
      <value value="&quot;Natural-lightning&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Mean-natural-fire-freq" first="0.1" step="0.1" last="3"/>
    <enumeratedValueSet variable="Fuel-Model">
      <value value="1"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deposit-interval">
      <value value="85"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Number of Runs - Pastoral" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-parameters</setup>
    <go>go</go>
    <metric>[deposit-25] of core 0</metric>
    <metric>[deposit-150] of core 0</metric>
    <metric>ignition-counter</metric>
    <metric>spread-counter</metric>
    <metric>[plume] of fires</metric>
    <metric>[biomass] of fires</metric>
    <steppedValueSet variable="Probability-Cutoff" first="0" step="0.1" last="0.9"/>
    <enumeratedValueSet variable="Ignition-Scenario">
      <value value="&quot;Pastoral&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ignition-Distribution">
      <value value="&quot;Land-use&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Mean-anth-fire-freq" first="0.1" step="0.1" last="3"/>
    <enumeratedValueSet variable="Fuel-Model">
      <value value="1"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deposit-interval">
      <value value="85"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Number of Runs - Swidden" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-parameters</setup>
    <go>go</go>
    <metric>[deposit-25] of core 0</metric>
    <metric>[deposit-150] of core 0</metric>
    <metric>ignition-counter</metric>
    <metric>spread-counter</metric>
    <metric>[plume] of fires</metric>
    <metric>[biomass] of fires</metric>
    <steppedValueSet variable="Probability-Cutoff" first="0" step="0.1" last="0.9"/>
    <enumeratedValueSet variable="Ignition-Scenario">
      <value value="&quot;Swidden&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Ignition-Distribution">
      <value value="&quot;Land-use&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Mean-anth-fire-freq" first="0.1" step="0.1" last="3"/>
    <enumeratedValueSet variable="Fuel-Model">
      <value value="1"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deposit-interval">
      <value value="85"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
