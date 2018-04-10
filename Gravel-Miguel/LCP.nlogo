extensions [
  GIS
  profiler
  ]

globals [
  basemap                               ;; Takes on the imported elevation values – used with GIS extension
  goal                                  ;; Records the coordinates of the goal (house)
  hiker-n                               ;; Records the ID number of the walking hiker (useful in manual setup as the ID can change depending on the order of creation)
  coord-start                           ;; Identifies the x and y of the agent
  coord-end                             ;; Identifies the x and y of the goal
  crow-fly                              ;; Calculates the Euclidean distance between start and end points (km)
  dist-traveled                         ;; Used to keep track of the distance traveled by the agent
  min-elev                              ;; Minimum elevation of the DEM (m)
  max-elev                              ;; Maximum elevation of the DEM (m)
  elev-hiker                            ;; To use the viewshed analysis and see if some patches are obscured from view
  list-slope                            ;; List useful for sensitivity analyses
  switch                                ;; Linked to switchback switch. Takes on a different numerical value based on user's choice
  sites                                 ;; Records the coordinates of the imported sites to use as start and end points ("Import" mode only)
  sites2                      ;; If using two shapefiles
  origin                                ;; Records the patch ID of the starting point
  id-start                              ;; Import mode only: records the name of the origin site (if applicable)
  id-end                                ;; Import mode only: records the name of the goal site (if applicable)
  res-m                                 ;; Calculates the resolution in meters that is used in multiple computations
  time-wd                               ;; Takes on the time-walked value to export via BehaviorSpace
  hiker-status                          ;; Can be dead or alive (set at the end of each simulation) to sort through outputs
  file-1                                ;; To create the outputs
  date                                  ;; Records the date and time value for output analysis
]

patches-own [
  elevation                             ;; Elevation (m) above sea level. Imported as ASCII from DEM.
  effective-slope                       ;; Calculated effective-slope of the elevation gained when traveling on a patch from a certain angle
  abs-eslope                            ;; Calculated absolute effective slope that helps the hiker choose the easiest route
  inter-elevation                       ;; Elevation at a corner of a patch (interpolated from the nearest three patches)
  headed-to                             ;; Records the angle towards the hiker
  dist-to-goal                          ;; Distance from the goal. Calculated by the patch only once per run
  occupied-by                           ;; Records the ID of the hiker on it (if there is one)
  len                                   ;; Calculates the distance to the hiker
  time                                  ;; Calculated time it would take to reach the patch center
  speed                                 ;; Converted walking time to speed (km/h) based on distance to patch center
  water                                 ;; True or false. Distinguishes between land patches and ones covered in water or snow
  patch-counter                         ;; Records how many ticks since being walked on
  obstructed?                           ;; Determines if the patch is hidden from the agent’s point of view
  site?                                 ;; "Import" mode only: Identifies patches with sites on them
]

breed [ hikers hiker ]                  ;; Only hikers move
breed [ targets target ]                ;; The goal of the hiker. Does not move during the run

hikers-own [
  hiker-dist-to-goal                    ;; Distance between the hiker and its goal
  patch-vision                          ;; Patches on the way towards the goal
  winner-patch                          ;; The patch with lowest abs-eslope that is also the closest to the goal
  time-walked                           ;; Keeps track of the time walked to the goal
  ]

to setup
ca                                      ;; Clears all
reset-ticks

set list-slope []                       ;; This list records the effective slopes of all patches walked on by the hiker
set date date-and-time                  ;; To create outputs that can be distinguished from one another

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IMPORTING GIS RASTERS   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

set basemap gis:load-dataset "LCP_maps/DEM.asc"                        ;; Uploads the DEM map

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; This resizes the GIS maps to fit to the size of the given raster ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

let trans-res patch-size-km / map-resolution-km                        ;; Calculates the transformation in resolution if the user wants a resolution other than the DEM's setting
resize-world 0 (( gis:width-of basemap - 1 ) / trans-res ) 0 (( gis:height-of basemap - 1 ) / trans-res )
set-patch-size ( 2 / patch-size-km )                                   ;; This roughly keeps the size of the world window manageable
gis:set-world-envelope gis:envelope-of basemap                         ;; This formats the window to the right dimensions based on the DEM
gis:set-sampling-method basemap "BICUBIC_2"                            ;; Sets the resampling (if applicable) to cubic
gis:apply-raster basemap elevation                                     ;; Gives the DEM elevation values to each patch

set min-elev gis:minimum-of basemap                                    ;; This will update the colors based on the uploaded map
ifelse gis:maximum-of basemap < snow-line                              ;; If there is a snowline covering mountains, only the uncovered patches will be colored green
[ set max-elev gis:maximum-of basemap ]
[ set max-elev snow-line ]

set res-m 1000 * map-resolution-km                                     ;; Calculates the patch sizes in meters (simplifies some computations below)

ask patches                                                            ;; This segment gives neutral values to side patches that may be overlooked by the DEM import (removes be NA)
  [ ifelse ( elevation <= 0 ) or ( elevation > 0 )
    [ set elevation elevation ]
    [ set elevation 0 ]]

ask patches with [ elevation < snow-line ]
  [ update-colors                                                      ;; Patch procedure to keep colors clean
    set occupied-by "none"                                             ;; All patches start unoccupied by a hiker
    set obstructed? "no"                                               ;; All patches start unobscured so that it changes only if the patch gets obstructed
    ifelse elevation <= 0                                              ;; So that hikers do not walk on water
    [ set water true ]
    [ set water false ]]

ask patches with [ elevation >= ( snow-line )]                         ;; Snow-covered patches will be colored white and be considered similar to water (they cannot be walked on)
  [ update-colors
    set water true ]

let land patches with [ water = false ]                                ;; Creating a temporary variable to record the patches that can be walked on

ifelse switchbacks = true                                              ;; If wider switchbacks are allowed, the "switch" value is 0.5
  [ set switch .05 ]
  [ set switch 0 ]

;;;;;;;;;;;;;;;;;;;;;;
;; CREATING CONTEXT ;;
;;;;;;;;;;;;;;;;;;;;;;

if mode = "random"
  [ ask one-of land                                                    ;; When the context is set on "Random," two land patches are randomly chosen to be the hiker and its goal
    [ stp-hikers ]                                                     ;; Patch setup procedure to create one hiker
  let other-land-patches land with [ self != origin ]                  ;; The models looks for another patch to set as goal (cannot be the same as the start)
    ask one-of other-land-patches
    [ stp-goal ]]                                                      ;; Patch setup procedure to create one target

if mode = "repeat"                                                     ;; When the context is set on "Repeat," the start and goals coordinates are taken from the start/end-x/y boxes
  [ ask patch start-x start-y                                          ;; Patch setup procedure to create one hiker
    [ stp-hikers ]
    reset-ticks
  ask patch end-x end-y
    [ stp-goal ]]                                                      ;; Patch setup procedure to create one target

if mode = "start-radius"                                               ;; When mode "Start-radius," ...
  [ let dist-rad radius-km / patch-size-km                             ;; Calculates the radius distance in patches
    let patch-rad 0                                                    ;; Temp variable to populate
    ask patch start-x start-y                                          ;; ... the start is set to the xy coordinates entered in the start-x and start-y boxes...
    [ stp-hikers ]
  ask hiker hiker-n
  [ set patch-rad one-of patches with [ distance myself > dist-rad - 1 AND distance myself <= dist-rad ]] ;; Selects one patch at radius-km distance from the start
  ifelse patch-rad != nobody                                           ;; If that patch does not exist (outside the window), it outputs an error message.
    [ ask patch-rad                                                    ;; If the patch is there, the goal is set to that patch
      [ stp-goal ]]
    [ print "The radius is too wide. No goal found. Reduce radius and press 'Setup'." ]]

if mode = "import"                                                     ;; If the mode is "Import," the model imports the shapefile of site coordinates, which are identified in red
  [ set sites gis:load-dataset "LCP_maps/Sites.shp"
    gis:set-drawing-color red                                          ;; It creates a red point at the location of each site
    gis:draw sites 1
    let site-patches patches gis:intersecting sites                    ;; The patches below those points are labelled "sites"
    ask site-patches
    [ set site? "yes" ]

    if shp-var != ""                                                   ;; If the sites have labels/names the user wants to record
    [ set id-start gis:property-value (item iter-start gis:feature-list-of sites) shp-var
      set id-end gis:property-value (item iter-end gis:feature-list-of sites) shp-var ]

    ifelse iter-start = iter-end
    [ print "The start and end point are the same. Please choose different values"
      set list-slope [ 0 0 0 ]                                         ;; To avoid error messages when outputting slope values in BehaviorSpace
      stop ]

    [ let iter-start-patch item iter-start gis:feature-list-of sites
      ask patches gis:intersecting iter-start-patch
      [ stp-hikers ]

      let iter-end-patch item iter-end gis:feature-list-of sites
      ask patches gis:intersecting iter-end-patch
      [ stp-goal ]]]                                                    ;; Patch setup procedure to create one target

;if mode = "import"                                                     ;; If the mode is "Import," the model imports the shapefile of site coordinates, which are identified in red
;  [ set sites gis:load-dataset "LCP_maps/Sites.shp"
;    gis:set-drawing-color red
;    gis:draw sites 1
;
;    set sites2 gis:load-dataset "LCP_maps/Sites_2.shp"
;    gis:set-drawing-color blue
;    gis:draw sites2 1
;
;    set id-start gis:property-value (item iter-start gis:feature-list-of sites2) shp-var
;    set id-end gis:property-value (item iter-end gis:feature-list-of sites) shp-var
;
;    let iter-start-patch item iter-start gis:feature-list-of sites2
;    ask patches gis:intersecting iter-start-patch
;    [ stp-hikers ]
;
;    let iter-end-patch item iter-end gis:feature-list-of sites
;    ask patches gis:intersecting iter-end-patch
;    [ stp-goal ]]

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CREATING PATH OUTPUTS ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; This creates a csv file that records the path, as well as its effective-slope and time walked along the way, as well as its length (in km).

if outputs? = true
  [ set file-1 (word "Outputs_path_" optimization "_" switchbacks "_" viewshed-threshold "_" origin "_" goal "_" random-float 1 ".csv")
    if file-exists? file-1
    [ file-delete file-1 ]                                             ;; If the file already exists (which it shouldn't as it has a timestamp), this overwrites it
    file-open file-1 ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IF MODE IS SET TO "MANUAL" ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to draw

  ;; This allows the user to create its own start and end points interactively on the map.

  if mouse-inside?                                    ;; Helps identifies where the mouse is situated in the world
  [ ask patch mouse-xcor mouse-ycor
    [ sprout 1
      [ set shape "square"
        die ]]                                        ;; Square turtles are created and die automatically as the user is looking for the right patch to sprout hiker/target

    ifelse create = "hiker"                           ;; Creating one hiker
    [ if mouse-down?
      [ ask patch mouse-xcor mouse-ycor
        [ ask hikers [ die ]                          ;; Keeps only one hiker (prevents long click to create multiple hikers)
          stp-hikers ]]]                              ;; Patch setup procedure to create one hiker.

    ;; The alternative to creating an "hiker" is to create the hiker's "goal" represented as a house.

    [ if mouse-down?
      [ ask patch mouse-xcor mouse-ycor
        [ ask targets [ die ]                         ;; Keeps only one target
          stp-goal ]]]]                               ;; Patch setup procedure to create one target.

  if goal != 0                                        ;; As soon as the target has been positioned,
  [ ask patches
    [ set dist-to-goal distance goal ]]               ;; ...each patch calculates its distance from it.

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SETUP COMMANDS TO SAVE SPACE ;;
;; PATCH PROCEDURES             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to stp-hikers                                                        ;; Patch procedure that creates one hiker with specific attributes.

  sprout-hikers 1
  [ set color 14
    set size 5
    set shape "person"
    pen-down
    set hiker-n who                                                  ;; Records the hiker's ID number as a global variable
    set winner-patch patch-here                                      ;; Allows the hiker to start walking as soon as the run starts
    set origin patch-here
    set coord-start list ([xcor] of self) ([ycor] of self)

    if any? targets
    [ set crow-fly ( distance goal * patch-size-km )]]               ;; Automatically calculates the distance between the hiker and its target

end

to stp-goal                                                          ;; Patch procedure that creates one goal with specific attributes.

  sprout-targets 1
  [ set color blue
    set size 5
    set shape "house"
    set goal patch-here                                              ;; Records the goal's ID number as a global variable
    set coord-end list ([xcor] of self) ([ycor] of self)

    if any? hikers
    [ set crow-fly ( distance hiker hiker-n * patch-size-km )]]      ;; Automatically calculates the distance between the hiker and its target

end

;;;;;;;;;;;;;;;;;;;;;;;;
;; OBSERVER PROCEDURE ;;
;;;;;;;;;;;;;;;;;;;;;;;;

to go

  if iter-start = iter-end
  [ if outputs? = true
    [ if lost-outputs? = true                                        ;; If both outputs are set to "true" the path is exported even if the hiker dies while walking
      [ export-path ]]
    set hiker-status "dead"
    stop ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STOPS IF THE HIKER DIES ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  if not any? hikers                                                 ;; If the hiker gets lost, it dies, the output is created (if applicable), and the script stops
  [ ask patches [ update-colors ]                                    ;; When the script stops, the world window cleans the patches to keep only the used path
    if outputs? = true
    [ if lost-outputs? = true                                        ;; If both outputs are set to "true" the path is exported even if the hiker dies while walking
      [ export-path ]]
    set hiker-status "dead"
    stop ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STOPS IF REACHED THE TICK LIMIT ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if ticks = limit-ticks                                               ;; If the hiker has not found a path within that time limit, the run stops
  [ ask patches [ update-colors ]                                    ;; When the script stops, the world window cleans the patches to keep only the used path
    if outputs? = true
    [ if lost-outputs? = true                                        ;; If both outputs are set to "true" the path is exported even if the hiker got lost along the way
      [ export-path ]]
    set hiker-status "dead"
    stop ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH COUNTER update to prevent hikers from walking on them over and over ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ask patches with [ patch-counter != 0 ]                            ;; Identifies patches that have been walked on in the last 20 ticks
  [ set patch-counter patch-counter - 1 ]                            ;; Ask those patches to lower their counter so they become available after a while

;;;;;;;;;;;;;;;;;;;;;
;; VARIABLE UPDATE ;;
;;;;;;;;;;;;;;;;;;;;;

  ask hikers
  [ set hiker-dist-to-goal distance goal                             ;; Constantly updates the distance from the goal, so that the hiker knows where to go
    set elev-hiker [ elevation ] of patch-here + 1.75                ;; Constantly updates the elevation of the top of the hiker's head (1.75 is based on r.viewshed in GRASS), which is used in computations below
    ask patch-here
    [ set occupied-by myself                                         ;; Tells patch-here to set occupied-by to the hiker's ID (myself refers to the hiker)
      set patch-counter 20 ]]                                        ;; Sets the counter of the patch walked on so it becomes available again in 20 ticks

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STOPS WHEN THE HIKER REACHES THE TARGET ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  if [ hiker-dist-to-goal ] of hiker hiker-n = 0                     ;; If the hiker has reached the goal, the output is created (if applicable), and the script stops
  [ ask patches [ update-colors ]                                    ;; When the script stops, the world window cleans the patches to keep only the used path
    if outputs? = true
    [ export-path ]
    set hiker-status "alive"
    stop ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HIKER MOVES ONLY IF REACHED ITS TEMP TARGET ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ask hiker hiker-n
  [ if patch-here = winner-patch
    [ ifelse distance goal <= 1.42                                   ;; If the goal is less than 1.42 away, the hiker does not look around and moves to it

      ;; If the goal is nearby

      [ set winner-patch goal                                        ;; Identifies the goal patch as the one towards which the hiker will move
        let wp goal
        ask patch-here
        [ assign-values wp true ]                                    ;; Asks the hiker's patch to calculate the abs-eslope and speed required to walk to the goal
        move ]                                                       ;; Move to the goal

      ;; If the goal is still far

      [ find-least-cost-path ]]]                                     ;; If the goal is still far away, the hiker looks for an easy route

  tick-advance 1                                                     ;; Update the ticks

end

;;;;;;;;;;;;;;;;;;;;;
;; HIKER PROCEDURE ;;
;;;;;;;;;;;;;;;;;;;;;

to find-least-cost-path

;; Setup of a few temporary variables

  let patch-under-me patch-here                                                             ;; This is to avoid including the patch where the turtle stands from the vision cone
  let c 0                                                                                   ;; Sets up the counter that will kill the hiker if it gets lost
  let hiker-distance [ hiker-dist-to-goal ] of self                                         ;; Temporary variable to simplify formulaes
  let wp 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IDENTIFYING POTENTIAL GOOD PATCHES ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  face goal                                                                                 ;; The hiker faces the general direction in which it needs to go

;; Identifies which patches can be used for the walking path.
;; Focuses on patches that have not been walked on before,
;; patches that are within a defined visible cone (200 degrees),
;; patches that are moving the hiker relatively closer to the goal (not moving farther from it)
;; and patches that are not obstructed by nearby mountains

  set patch-vision patches in-cone 2.5 200                                                  ;; The hiker considers all patches within a 200 degree cone of 2.5 patches in front of them
  ask patch-vision
  [ set dist-to-goal distance goal ]                                                        ;; All potential patches calculate their distance from the goal
  set patch-vision patch-vision with [ water = false ]                                      ;; Eliminates patches that are covered in water or snow
  set patch-vision patch-vision with [(([ dist-to-goal ] of self ) <= hiker-distance + ( hiker-distance * switch ))]  ;; Eliminates patches that would lead the hiker too far from the goal (based on switchbacks)
  set patch-vision patch-vision with [ patch-counter = 0 ]                                  ;; Will consider patches that have not been traveled in a while (20 ticks), which eliminates the patch-here automatically
  ask patch-vision
  [ set obstructed? "no"                                                                    ;; This resets the visibility in case an obstructed patch becomes visible
    check-viewshed ]                                                                        ;; All patches check if they are obstructed from the hiker's view
  set patch-vision patch-vision with [ obstructed? = "no" ]                                 ;; Makes sure that the hiker only considers patches it can see as potential ones to walk to

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; If there are no potential patches ;;
;; The agent widens its search       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  while [ not any? patch-vision ]
  [ set patch-vision patches in-cone 2.5 360                                                ;; Widens the search by looking all around
    set patch-vision patch-vision with [ water = false ]                                    ;; Eliminates patches that are covered in water or snow
    set patch-vision patch-vision with [ patch-counter = 0 ]                                ;; Will consider patches that have not been traveled in a while (20 ticks), which eliminates the patch-here automatically

    ;; This gets repeated here to make sure the hiker considers only the patches it can see

    ask patch-vision
    [ set obstructed? "no"                                                                  ;; This resets the visibility incase an obstructed patch becomes visible
      check-viewshed ]                                                                      ;; Same as above. This is when the patch between itself and the hiker is actually lower. Then the patch considered is visible
    set patch-vision patch-vision with [ obstructed? = "no" ]                               ;; Makes sure that the hiker only considers patches it can see as potential ones to walk to

    set c c + 1                                                                             ;; This is so that the hiker dies after 5 ticks without a road
    if c = 5
    [ die ]]

  ask patch-vision
  [ set pcolor grey                                                                         ;; All potential patches change their color for visualization purposes
    set len distance hiker hiker-n * res-m ]                                                ;; Calculates the distance to the hiker in meters

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CALCULATING EFFECTIVE SLOPE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ask patch-vision
  [ ask patch-under-me                                                                      ;; The patch-vision asks the patch of the hiker to compute slope and speed to account for anisotropic differences of walking a path there or back
    [ set len distance myself * res-m                                                       ;; This represents the hiker's perspective better
      assign-values myself false ]

    set effective-slope [ effective-slope ] of patch-under-me                               ;; Then the patch-vision takes those values so that the hiker can choose the best within all patch-vision patches
    set abs-eslope [ abs-eslope ] of patch-under-me
    set speed [ speed ] of patch-under-me
    set time [ time ] of patch-under-me ]

  ;; While effective-slope can be negative, abs-eslope is an absolute number

  ;;;;;;;;;;;;;;;;;;;;;
  ;; CHOOSING A PATH ;;
  ;;;;;;;;;;;;;;;;;;;;;

  ;; Defining absolute slope categories (inspired by Naismith's rule)
  let flat patch-vision with [ abs-eslope < 5 ]
  let gentle patch-vision with [( abs-eslope >= 5 ) and ( abs-eslope < 12 )]

  ;; Optimization-Distance: If the user is looking for the fastest easiest route between two points

  if optimization = "Distance"
  [ ifelse any? flat                                                                          ;; If there are potential patches with effective slope lower than 5 degrees, the agent chooses one of those
    [ set winner-patch one-of flat with-min [ dist-to-goal ]]                                 ;; This picks the fastest easiest path
    [ ifelse any? gentle                                                                      ;; If there are no patches with slope lower than 5 degrees, the agent chooses one with slope < 12 degrees
      [ set winner-patch one-of gentle with-min [ dist-to-goal ]]
      [ set winner-patch one-of patch-vision with-min [ dist-to-goal ]]]]                     ;; If this is still not possible (all patches are ridiculously steep), the agent chooses the potential patch with the lowest slope

  ;; Optimization-Exploration: If the user is looking for some exploration (more random)

  if optimization = "Exploration"
  [ ifelse any? flat                                                                          ;; If there are potential patches with effective slope lower than 5 degrees, the agent chooses one of those as the new winner-patch
    [ set winner-patch one-of flat ]                                                          ;; Chooses at random within the set of low slope patches
    [ ifelse any? gentle                                                                      ;; If there are no patches with slope lower than 5 degrees, the agent chooses one with slope < 12 degrees.
      [ set winner-patch one-of gentle ]                                                      ;; Chooses at random within the set of medium slope patches
      [ set winner-patch one-of patch-vision with-min [ abs-eslope ]]]]                       ;; If this is still not possible (all patches are ridiculously steep), the agent chooses the potential patch with the lowest slope

  ;; Optimization-Speed: If the user is looking for the ultimate easiest route between two points

  if optimization = "Speed"
  [ let fast patch-vision with-max [ speed ]
    set winner-patch one-of fast with-min [ dist-to-goal ]]                                   ;; This always picks one of the patches that can be traveled to fastest (which is usually the gentler slope)

  ;; The patch-here then takes the abs-eslope and speed values of the winner-patch for further computation

  set wp winner-patch
  ask patch-here
    [ assign-values wp true ]

  ;;;;;;;;;;;;;;;;;
  ;; DIE OR MOVE ;;
  ;;;;;;;;;;;;;;;;;

  ifelse winner-patch = nobody                                                                ;; To avoid observer error, if the hiker is lost, it dies.
  [ die ]
  [ face winner-patch
    move ]                                                                                    ;; If there is a winner-patch, the hiker faces it...

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH PROCEDURE called by patch-vision ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to check-viewshed

set headed-to ( towards hiker hiker-n )                                                       ;; Identifies the angle at which the patch is from the hiker

if distance hiker hiker-n >= 2                                                                ;; Identifies the patches that are direct neighbors

    ;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; NON ADJACENT PATCHES ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;

    [ ifelse distance hiker hiker-n < 2.2                                                     ;; Narrows it down to the patches that are not direct neighbors but are on right angles from the agent
      [ let middle-elev [elevation] of patch-at-heading-and-distance headed-to 1              ;; Records the elevation of the patch in between the hiker and the asking patch
        ifelse middle-elev > viewshed                                                         ;; Identifies if the middle patch is higher than a certain value (viewshed)
        [ set obstructed? "yes" ]                                                             ;; ... then the patch considered is labeled as obstructed from the hiker's view and will be removed from the patch-vision set
        [ set obstructed? "no" ]]

        ;;;;;;;;;;;;;;;;;;;;
        ;; KNIGHT PATCHES ;;
        ;;;;;;;;;;;;;;;;;;;;

      [ let p1 patch-at-heading-and-distance headed-to 1.5                                    ;; Identifies the middle patch closest to the hiker
        let p2 patch-at-heading-and-distance headed-to 0.75                                   ;; Identifies the middle patch furthest from the hiker
        let middle-elev1 0                                                                    ;; Temporary global variable that the patch-vision can use
        let middle-elev2 0                                                                    ;; Temporary global variable that the patch-vision can use

        ask p1                                                                                ;; Asks the first middle patch to calculate its interpolated elevation
        [ let my-head triangle-knight1 [ headed-to ] of myself                                ;; Identifies the direction in which to look for a neighboring patch to use for interpolation
          let list-elev ( list                                                                ;; Creates a patchset of important nearby patches
            ([ elevation ] of self / 0.4714045207910388 )                                     ;; These next lines use the IDW interpolation method to calculate the height
            ([ elevation ] of [ patch-here ] of hiker hiker-n  / 0.7453559924999299 )
            ([ elevation ] of patch-at-heading-and-distance my-head 1 / 0.9428090415820563 )
            ([ elevation ] of p2 / 0.7453559924999299 ))
          set inter-elevation ( sum list-elev / (( 1 / 0.4714045207910388 ) + ( 1 / 0.7453559924999299 ) + ( 1 / 0.9428090415820563 ) + ( 1 / 0.7453559924999299 )))
          set middle-elev1 inter-elevation ]

        ask p2
        [ let my-head triangle-knight2 [ headed-to ] of myself
          let list-elev ( list
            ([ elevation ] of self / 0.4714045207910388 )
            ([ elevation ] of myself / 0.7453559924999299 )
            ([ elevation ] of patch-at-heading-and-distance my-head 1 / 0.9428090415820563 )
            ([ elevation ] of p1 / 0.7453559924999299 ))
          set inter-elevation ( sum list-elev / (( 1 / 0.4714045207910388 ) + ( 1 / 0.7453559924999299 ) + ( 1 / 0.9428090415820563 ) + ( 1 / 0.7453559924999299 )))
          set middle-elev2 inter-elevation ]

        ifelse middle-elev1 > viewshed-knight1
          [ set obstructed? "yes" set pcolor black ]                                          ;; ... then the patch considered is labeled as obstructed from the hiker's view and will be removed from the patch-vision set
          [ ifelse middle-elev2 > viewshed-knight2
            [ set obstructed? "yes" set pcolor black ]
            [ set obstructed? "no" ]]]]

end

;;;;;;;;;;;;;;;;;;;;
;; PATCH REPORTER ;;
;;;;;;;;;;;;;;;;;;;;

to-report triangle-knight1 [ x ]                        ;; x refers to the heading (degree angle 0-360) towards the potential knight patch
  if member? round x [ 27 243 ]                         ;; This reports the heading angle toward the neighboring patch between the hiker and p1, based on the direction of travel
  [ report 315 ]

  if member? round x [ 63 207 ]
  [ report 135 ]

  if member? round x [ 117 333 ]
  [ report 45 ]

  if member? round x [ 153 297 ]
  [ report 225 ]

end

to-report triangle-knight2 [ x ]                        ;; x refers to the heading (degree angle 0-360) towards the potential knight patch
  if member? round x [ 27 243 ]                         ;; This reports the heading angle toward the neighboring patch between p2 and the potential patch, based on the direction of travel
  [ report 135 ]

  if member? round x [ 63 207 ]
  [ report 315 ]

  if member? round x [ 117 333 ]
  [ report 225 ]

  if member? round x [ 153 297 ]
  [ report 45 ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH REPORTER called by CHECK-VIEWSHED ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report viewshed

  ;; Here the elev-change is divided in 2 as we calculate the the elevation that would cut through the real elevation change halfway
  ;; viewshed-threshold can be changed to allow seeing over small mountains

  let rel-elev-change [ elevation ] of self - elev-hiker                                      ;; The elevation difference between the asking patch and the eyes of the hiker (1.75m above the ground, same as ArcGIS)
  report elev-hiker + ( rel-elev-change / 2 ) + ( viewshed-threshold * res-m )                ;; Identifies the elevation at which the middle patch needs to be to obscure the view

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH REPORTER called by the patch-vision. Targets the middle patch closest to the patch-vision ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report viewshed-knight1

  ;; Here the elev-change is multiplied by 1/3 as we calculate the elevation that would cut the real elevation change at 1/3 of the way
  ;; viewshed-threshold can be changed to allow seeing over small mountains

  let rel-elev-change [ elevation ] of self - elev-hiker                                      ;; The elevation difference between the asking patch and the eyes of the hiker (1.75m above the ground, same as ArcGIS)
  report elev-hiker + ( rel-elev-change * ( 1 / 3 )) + ( viewshed-threshold * res-m )         ;; Identifies the elevation at which the first middle patch needs to be to obscure the view

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH REPORTER called by the patch-vision. Targets the middle patch closest to the HIKER ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report viewshed-knight2

  ;; Here the elev-change is multiplied by 2/3 as we calculate the elevation that would cut the real elevation change at 2/3 of the way
  ;; viewshed-threshold can be changed to allow seeing over small mountains

  let rel-elev-change [ elevation ] of self - elev-hiker                                      ;; The elevation difference between the asking patch and the eyes of the hiker (1.75m above the ground, same as ArcGIS)
  report elev-hiker + ( rel-elev-change * ( 2 / 3 )) + ( viewshed-threshold * res-m )         ;; Identifies the elevation at which the second middle patch needs to be to obscure the view

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH PROCEDURE called by the hiker's patch-here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to assign-values [ p boolean ]                                         ;; p = Patch towards which the hiker may move.

  let dp distance p                                                    ;; Temporary variable recording the distance from the hiker to the patch where it may move
  let ep ([ elevation ] of p - [ elevation ] of self )                 ;; Temporary variable recording the elevation change from the hiker to the patch where it may move
  let p1 0                                                             ;; Temporary variable that will record the middle patch closest to the hiker
  let p2 0                                                             ;; Temporary variable that will record the middle patch furthest from the hiker
  let dir 0                                                            ;; Temporary variable that will record the angle towards the patch where the hiker may move

  ifelse distance p < 1.5

  ;;;;;;;;;;;;;;;;;;;;;;
  ;; ADJACENT PATCHES ;;
  ;;;;;;;;;;;;;;;;;;;;;;

  [ calculate-speed p dp ep boolean ]                                  ;; Calculates the effective-slope and speed of walking to patch p

  [ ifelse distance p < 2.2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; NON ADJACENT PATCHES ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;

    [ set dir towards p
      set p1 patch-at-heading-and-distance dir 1                       ;; Identifies the patch between patch-here and patch p
      ask p1                                                           ;; The middle patch calculates effective slope and time to patch p
      [ set dp distance p
        set ep ([ elevation ] of p - [ elevation ] of self )
        calculate-speed p dp ep boolean ]
      set dp distance p1
      set ep ([ elevation ] of p1 - [ elevation ] of self )
      calculate-speed p1 dp ep boolean                                 ;; Whereas patch-here calculates effective slope and time to the middle patch

      ;; Consolidating effective-slope and time values of the whole path.

      set effective-slope [ effective-slope ] of worst-slope self p1   ;; This identifies the steeper effective slope (negative or positive) that would be walked on
      set time sum ( list [ time ] of self [ time ] of p1 )]           ;; The total time sums up the time from patch-here to middle, and from middle to patch p

    ;;;;;;;;;;;;;;;;;;;;
    ;; KNIGHT PATCHES ;;
    ;;;;;;;;;;;;;;;;;;;;

    [ set dir towards p
      set dp 0.7453559924999299                                       ;; This value represents the distance between the hiker and the knight patch divided by 3 (2.23606797749979 / 3)
      set p1 patch-at-heading-and-distance dir 0.75                   ;; This touches only the first of the two middle patches (closest to hiker)
      set p2 patch-at-heading-and-distance dir 1.5                    ;; This touches only the second of the two middle patches (closest to target patch)

      ask p1                                                          ;; P1 calculates effective slope and time to patch p2
      [ let my-head triangle-knight1 [ headed-to ] of p               ;; This identifies the nearby patch that will be used to interpolate the elevation at the patch's corner
        let included ( patch-set self myself patch-at-heading-and-distance my-head 1 p2 )
        let list-elev [ elevation ] of included
        set list-elev lput elevation list-elev
        set inter-elevation mean list-elev
        set ep ([ inter-elevation ] of p2 - [ inter-elevation ] of self )
        calculate-speed p2 dp ep boolean ]

      ask p2                                                          ;; P2 calculates effective slope and time to patch p
      [ let my-head triangle-knight2 [ headed-to ] of p
        let included ( patch-set self p patch-at-heading-and-distance my-head 1 p2 )
        let list-elev [ elevation ] of included
        set list-elev lput elevation list-elev
        set inter-elevation mean list-elev
        set ep ([ elevation ] of p - [ inter-elevation ] of self )
        calculate-speed p dp ep boolean ]
      set ep ([ inter-elevation ] of p1 - [ elevation ] of self )
      calculate-speed p1 dp ep boolean                                ;; Patch-here calculates effective slope and time to patch p1

      ;; Consolidating effective-slope and time values of the whole path

      set effective-slope [ effective-slope ] of worst-slope self p1
      set effective-slope [ effective-slope ] of worst-slope self p2
      set time sum ( list [ time ] of self [ time ] of p1 [ time ] of p2 )]]

    set abs-eslope abs ( effective-slope )                            ;; Converts the effective slope into an absolute value to choose from (see find-least-cost-path)
    set speed  ( len / res-m ) / ( time / 3600 )                      ;; Converts time value into speed based on the distance between patch-here and patch p

end

;;;;;;;;;;;;;;;;;;;;;
;; PATCH PROCEDURE ;;
;;;;;;;;;;;;;;;;;;;;;

to calculate-speed [ p dp ep boolean ]                                ;; p = the patch ID towards which speed is calculated. dp is the distance to p, and ep the elevation change to p

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Integrating Naismith's rule and Langmuir's correction for anisotropic travel              ;;
  ;;                                                                                           ;;
  ;; T = a*delta_S + b*delta_H_uphill + c*delta_H_moderate_downhill + d*delta_H_steep_downhill ;;
  ;; T is time of movement in seconds,                                                         ;;
  ;; delta S is the horizontal distance covered in meters,                                     ;;
  ;; delta H is the altitude difference in meters.                                             ;;
  ;;                                                                                           ;;
  ;; Effective slopes:                                                                         ;;
  ;; 0-5 degrees is gentle                                                                     ;;
  ;; 5-12 degrees is moderate                                                                  ;;
  ;; > 12 degrees is steep                                                                     ;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  let dS res-m * dp                                                              ;; The distance to travel in meters
  let dHu 0                                                                      ;; Temporary delta uphill variable
  let dHmd 0                                                                     ;; Temporary delta moderate downhill variable
  let dHsd 0                                                                     ;; Temporary delta steep downhill variable

  set effective-slope arctan ( ep / dS )                                         ;; Calculates the effective slope angle between the two patches, based on distance and elevation change

  if boolean = true                                                              ;; Identifies if this is the selected path or not
  [ let es effective-slope                                                       ;; Temporary variable used by the hiker to record those values
    ask hiker hiker-n                                                            ;; Patches cannot do this action, so we have to ask the hiker to do so
    [ set list-slope lput es list-slope ]]                                       ;; This list records all the effective slopes walked on (even the non-extreme ones shown in the graph

  ;;;;;;;;;;;;;;;;;;;
  ;; IF GOING DOWN ;;
  ;;;;;;;;;;;;;;;;;;;

  ;; This attributes the elevation change to the appropriate orientation variable
  ;; For example, if the slope is between -5 and -12 degrees, dHmd = elev-change, whereas dHsd and dHu remain at 0

  ifelse effective-slope < 0
    [ if effective-slope < -5
      [ ifelse effective-slope > -12
        [ set dHmd ep ]
        [ set dHsd ep ]]]

  ;;;;;;;;;;;;;;;;;
  ;; IF GOING UP ;;
  ;;;;;;;;;;;;;;;;;

    [ if effective-slope > 5
      [ set dHu ep ]]

  ;;;;;;;;;;;;;;;;;;;;;;
  ;; CALCULATING TIME ;;
  ;;;;;;;;;;;;;;;;;;;;;;

  ;; Calculates the time (seconds) taken to travel to a patch (from GRASS r.walk) based on distance walked and effective slope

  set time (0.72 * dS) + (6 * dHu) + (1.9998 * dHmd) + (-1.9998 * dHsd)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH REPORTER to calculate effective slope of walking to a neighboring patch ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report arctan [x]                                                                   ;; x refers to a value that represents ( elevation change / distance ) between two neighboring patches

report asin (x / sqrt(1 + x * x))                                                      ;; Reports the degree angle slope based on distance and elevation change of two patches

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH REPORTER called by patch-vision and patch-here through ASSIGN-VALUES ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report worst-slope [a b]                                                            ;; a and b should be the ID of two patches

  ;; Reports the effective-slope of the patch with worst effective-slope of a set of two (a and b)

  let a-slope [ effective-slope ] of a
  let b-slope [ effective-slope ] of b

  ifelse a-slope < 0
  [ ifelse b-slope < 0
    [ ifelse a-slope < b-slope
      [ report a ]
      [ report b ]]
    [ ifelse abs ( a-slope ) < b-slope
      [ report b ]
      [ report a ]]]

  [ ifelse b-slope > 0
    [ ifelse a-slope < b-slope
      [ report b ]
      [ report a ]]
    [ ifelse abs ( b-slope ) > a-slope
      [ report b ]
      [ report a ]]]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HIKER PROCEDURE to move to the winner-patch ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move

let dist-winner-patch distance winner-patch                                     ;; Temporary variable that records the distance between the hiker and its temporary target
let time-ph [ time ] of patch-here                                              ;; Temporary variable that records the time to walk to the temporary target

;; The slow movements and plot updates below make sure that all patches and their effective slope are logged in the outputs

ifelse dist-winner-patch > 2
[ fd 0.74
  update-plots
  fd 0.74
  update-plots
  move-to winner-patch
  update-plots ]

[ ifelse dist-winner-patch > 1
  [ fd 1
    update-plots
    move-to winner-patch
    update-plots ]
  [ move-to winner-patch
    update-plots ]]

set dist-traveled dist-traveled + ( dist-winner-patch * patch-size-km )         ;; The total distance traveled gets updated...
set time-walked time-walked + time-ph                                           ;; ... as well as the total time walked (for plots)
set time-wd time-walked

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PATCH PROCEDURE to keep a clean world ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-colors

ifelse (elevation <= 0) or (elevation >= 0)
  [ ifelse elevation <= 0
    [ set pcolor scale-color blue elevation min-elev 1000 ]
    [ ifelse elevation > ( snow-line )
      [ set pcolor white ]
      [ set pcolor scale-color green elevation max-elev -400 ]]]
  [ set water "true"
    set elevation 0
    set effective-slope 0 ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OBSERVER PROCEDURE to output the path coordinates and characteristics ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to export-path

  export-plot "path" file-1
  file-close

end
@#$#@#$#@
GRAPHICS-WINDOW
635
21
1291
474
-1
-1
2.0
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
323
0
221
0
0
1
Ticks
30.0

BUTTON
24
10
90
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
100
10
163
43
NIL
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

CHOOSER
388
136
615
181
create
create
"hiker" "goal"
0

CHOOSER
387
21
614
66
mode
mode
"import" "manual" "random" "repeat" "start-radius"
0

BUTTON
387
98
615
131
Create context
draw
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
288
496
417
541
Distance walked (km)
dist-traveled
1
1
11

SLIDER
24
112
151
145
patch-size-km
patch-size-km
0.1
2
1.0
0.1
1
NIL
HORIZONTAL

MONITOR
24
285
131
330
NIL
coord-start
17
1
11

MONITOR
136
285
244
330
coord-end
coord-end
17
1
11

MONITOR
288
444
417
489
NIL
crow-fly
2
1
11

INPUTBOX
389
217
441
277
start-x
221.0
1
0
Number

INPUTBOX
445
217
497
277
start-y
85.0
1
0
Number

INPUTBOX
509
217
561
277
end-x
41.0
1
0
Number

INPUTBOX
564
217
616
277
end-y
175.0
1
0
Number

SWITCH
159
175
328
208
outputs?
outputs?
0
1
-1000

PLOT
24
339
282
489
path
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"path-x" 1.0 0 -16777216 true "" "if any? hikers [ plot [ xcor ] of hiker hiker-n ]"
"path-y" 1.0 0 -7500403 true "" "if any? hikers [ plot [ ycor] of hiker hiker-n ]"
"slope" 1.0 0 -955883 true "" "if any? hikers [\nlet temp [ patch-here ] of hiker hiker-n\nplot [ effective-slope ] of temp ]"

INPUTBOX
24
48
150
108
map-resolution-km
1.0
1
0
Number

INPUTBOX
24
150
151
210
snow-line
2000.0
1
0
Number

MONITOR
289
549
417
594
Time passed (hours)
([ time-walked ] of hiker hiker-n) / 3600
2
1
11

SLIDER
159
136
328
169
viewshed-threshold
viewshed-threshold
0
0.2
0.001
0.01
1
NIL
HORIZONTAL

BUTTON
173
10
254
43
go once
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

CHOOSER
158
48
328
93
optimization
optimization
"Distance" "Exploration" "Speed"
2

PLOT
24
496
282
646
path slope
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"slope" 1.0 0 -2674135 true "" "if any? hikers [\nlet temp [ patch-here ] of hiker hiker-n\nplot [ effective-slope ] of temp ]"

MONITOR
289
601
418
646
Speed (km/h)
dist-traveled / (([ time-walked ] of hiker hiker-n) / 3600)
2
1
11

SWITCH
159
213
328
246
lost-outputs?
lost-outputs?
1
1
-1000

SWITCH
159
98
328
131
switchbacks
switchbacks
0
1
-1000

INPUTBOX
436
471
561
531
radius-km
15.0
1
0
Number

INPUTBOX
24
215
151
275
limit-ticks
1500.0
1
0
Number

INPUTBOX
435
375
562
435
shp-var
STR_3
1
0
String

INPUTBOX
435
311
497
371
iter-start
2.0
1
0
Number

INPUTBOX
500
311
562
371
iter-end
6.0
1
0
Number

TEXTBOX
451
76
601
94
Manual mode
14
0.0
1

TEXTBOX
453
288
603
306
Import mode
14
0.0
1

TEXTBOX
449
195
599
213
Repeat mode
14
0.0
1

TEXTBOX
438
447
588
465
Start-radius mode
14
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model aims to mimic human movement on a realistic topographical surface. It allows the user to explore three different ways in which an agent can choose an easy route to reach a certain goal, and explore two different types of scenarios. Other least-cost path models explore similar issues, but they work on the implication that the whole world is perfectly known. They find the easiest route among all possibilities, and direct the agent to follow it. This model is different in that the agent does not have a perfect knowledge of the whole surface, but rather evaluates the best path locally, at each step, thus mimicking imperfect human behavior more accurately. Moreover, it allows exploring five setup scenarios and three different optimization processes, with the simple change of parameter values.


## HOW IT WORKS

At every tick, the hiker evaluates the direction in which it needs to travel to reach its goal. At all times, the hiker has a temporary local target that allows it to move slowly in the right direction. If the goal is within sight (in the immediate neighbors), the agent chooses the goal as its temporary target. If the goal is still far, it looks at a certain number of patches in a vision cone, and identifies which ones can bring it closer to the main goal while allowing for a relatively flat walking surface. The chosen patch depends on the "mode" setting determined by the user.

Some patches change their status throughout the run. When the agent walks on a patch, that patch becomes used and cannot be chosen again as a potential path for the next 20 ticks. This is implemented so that the agent moves forward and does not get stuck circling around the goal. 

Patches that are considered as potential ones to walk on change their color to grey for visualization purposes. The path followed by the agent is represented as a red line. When the simulation ends, all patches regain their original color, which puts more emphasis onto the path taken.


## HOW TO USE IT

The model works with DEM from 0.1 to 2km resolution. It works best at 1km resolution, which avoids the noise created by higher resolution maps.

1 map is required for all simulations:
**DEM**

However, if using the "Import" mode, a shapefile of point coordinates need to be provided as well:
**Sites** (must be in the same projection as the DEM)

There are five possible setup modes.

**Import**: The hiker and its goal are placed randomly on sites imported from a shapefile.

**Random**: The hiker and its goal are placed randomly on the landscape.

**Manual**: The user determines where the agent and the goal are on the board. The user must click on "create" to activate, and then choose where to put each turtle. The user then needs to click again on "create" to disactivate it before clicking go.

**Repeat**: This uses the coordinates given by the user (xy of start and end) to set up the hiker and its target. **Those should be entered BEFORE pressing setup.** Make sure that the coordinates are not on water or on icesheets, as this would create an error.

**Start-radius**: This uses a starting point provided by the user, and position the end point randomly at a distance determined by the user, using the "radius-km" input box.

The user decides if the hiker is allowed to use switchbacks or if it should move as straight as possible towards the goal. The switchbacks are influenced by the distance to the goal. The hiker is allowed bigger switchbacks when it is far, but closes in on the goal when it is close. 

Moreover, there are 3 optimization processes:

**Speed**: Where the hiker always walks to the patch that is easiest to walk to (should also be the fastest), while moving towards the goal.

**Distance**: Where the hiker always walks to the nearby patch that brings it closer to the goal (while avoiding steep slopes).

**Exploration**: Where the hiker explores by walking on one of the patches with lowest slope, a choice that can vary based on the simulation.

## THINGS TO NOTICE

The hiker sometimes goes farther than it should and can even get lost. This is interesting as it reproduces possible human error (although humans would be able to go back on their previous trail, and thus, they would not die when getting lost).

## THINGS TO TRY

The user should try different combinations of agent-goal position with different switchback values to evaluate which switchback approach minimizes both time and average slope walked.

The user should also try different optimization settings on the same start and end point combinations to see how the resulting paths differ.

## EXTENDING THE MODEL

This model accomodates only one hiker and one goal. A more advanced model should allow for the creation of several hikers, each with its own goal.

Future models should also accomodate more refined resolution.

## RELATED MODELS

Astardemo1
CostaPath
Paths
Pathfinder

## CREDITS AND REFERENCES

Langmuir, E. 1984. Mountaincraft and leadership, British Mountaineering Council.
Aitken, R. 1977. Wilderness Areas in Scotland. Unpublished Ph.D. thesis, Aberdeen.

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
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment_random" repetitions="250" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>dist-traveled</metric>
    <metric>time-wd</metric>
    <metric>goal</metric>
    <metric>origin</metric>
    <metric>crow-fly</metric>
    <metric>hiker-status</metric>
    <metric>date</metric>
    <metric>mean list-slope</metric>
    <metric>max list-slope</metric>
    <metric>min list-slope</metric>
    <enumeratedValueSet variable="create">
      <value value="&quot;hiker&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="snow-line">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-y">
      <value value="56"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="map-resolution-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-y">
      <value value="175"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-x">
      <value value="159"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outputs?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mode">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-x">
      <value value="41"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switchbacks">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="viewshed-threshold">
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="optimization">
      <value value="&quot;Distance&quot;"/>
      <value value="&quot;Speed&quot;"/>
      <value value="&quot;Exploration&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lost-outputs?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-ticks">
      <value value="1500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="El_Castillo_15km_radius" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>dist-traveled</metric>
    <metric>time-wd</metric>
    <metric>goal</metric>
    <metric>origin</metric>
    <metric>crow-fly</metric>
    <metric>hiker-status</metric>
    <metric>date</metric>
    <metric>mean list-slope</metric>
    <metric>max list-slope</metric>
    <metric>min list-slope</metric>
    <enumeratedValueSet variable="create">
      <value value="&quot;hiker&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="snow-line">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="map-resolution-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="iter-end">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="iter-start">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-y">
      <value value="175"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shp-var">
      <value value="&quot;STR_3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-x">
      <value value="221"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lost-outputs?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="radius-km">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="optimization">
      <value value="&quot;Speed&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-ticks">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="viewshed-threshold">
      <value value="0.001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-y">
      <value value="85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outputs?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mode">
      <value value="&quot;start-radius&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-x">
      <value value="41"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switchbacks">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Sites_speed" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>dist-traveled</metric>
    <metric>time-wd</metric>
    <metric>goal</metric>
    <metric>origin</metric>
    <metric>crow-fly</metric>
    <metric>hiker-status</metric>
    <metric>date</metric>
    <metric>mean list-slope</metric>
    <metric>max list-slope</metric>
    <metric>min list-slope</metric>
    <metric>id-start</metric>
    <metric>id-end</metric>
    <enumeratedValueSet variable="create">
      <value value="&quot;hiker&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="snow-line">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="map-resolution-km">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="iter-end" first="0" step="1" last="6"/>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="iter-start" first="0" step="1" last="6"/>
    <enumeratedValueSet variable="end-y">
      <value value="175"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shp-var">
      <value value="&quot;STR_3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-x">
      <value value="221"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lost-outputs?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="radius-km">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="optimization">
      <value value="&quot;Speed&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-ticks">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="viewshed-threshold">
      <value value="0.001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-y">
      <value value="85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="outputs?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mode">
      <value value="&quot;import&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="end-x">
      <value value="41"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switchbacks">
      <value value="true"/>
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
