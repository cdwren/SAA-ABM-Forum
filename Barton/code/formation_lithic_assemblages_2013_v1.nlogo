globals [lithicSources camps basecamps runNumber landUse homebase-color camp-color territory-color cells plot-on
  camp-tool-freq basecamp-tool-freq source-tool-freq active-tool-freq total-tool-freq
  camp-cores camp-debitage camp-tools basecamp-cores basecamp-debitage basecamp-tools 
  basecamp-lithics basecamp-flakes basecamp-retouched basecamp-used basecamp-exhausted
  camp-lithics camp-flakes camp-retouched camp-used camp-exhausted
  source-cores source-debitage source-tools active-cores active-debitage active-tools
  total-cores total-debitage total-tools
  camp-tools-byfBand camp-debitage-byfBand base-tools-byfBand base-debitage-byfBand
  camp-density basecamp-density
  provision-trips counter task-counter mean-useRate totalUse]
breed [fBands fBand]
fBands-own [territory homeBase camp trip useRate need-provision f-ID
  f-cores f-flakes f-used f-retouched f-exhausted f-provision f-trips]
patches-own [p-cores p-flakes p-used p-retouched p-exhausted p-ID sitetype]

to setup
  clear-all
  set homebase-color black
  set camp-color white
  set territory-color 7
  set task-counter 0
  set mean-useRate 0
  ifelse LMS-pct > random 100 
    [set landUse "LMS"]
    [set landUse "RMS"]
  set basecamps no-patches
  set camps no-patches
  set lithicSources no-patches
  setup-bands
  if runs = 0 [set runs 1]
  set runNumber 1
  set cells world-width * world-height
  set camp-tool-freq 0
  set basecamp-tool-freq 0
  set total-tool-freq 0
  set source-tool-freq 0
  ; set provision-trips 0
  set counter 0
  reset-ticks
end

to setup-bands
  let idx 0
  create-fBands bands [
    set color magenta
    set size 3
    set idx who
    set trip "outbound" 
    set need-provision false
    set f-cores 0
    set f-flakes lithic-stock
    set f-used 0
    set f-retouched 0
    set f-exhausted 0
    set f-trips 0
    ifelse bands > 1 [
      setxy random-xcor random-ycor
    ][
      setxy 0 0
    ] 

    ;; establish territory
    set territory patches in-radius territory-radius
    ask territory [
      set p-ID idx
      set pcolor territory-color
      set sitetype "territory"
      ]
    
    ;; identify lithic sources in each territory
    let nsources sources * pi * (territory-radius ^ 2) / 100
    set lithicSources (patch-set n-of nsources territory lithicSources)
    ask lithicSources [
      set p-ID idx
      set pcolor brown
      set sitetype "source"
      ]
        
    ;; establish a base camps in each territory for LMS (also used as camp by RMS)
    set homeBase patch-here
    ask homeBase [set p-ID idx]
    set basecamps (patch-set patch-here basecamps)
    ask patch-here [
      set pcolor homebase-color
      set sitetype "basecamp"]
    
    ;; identify first camp
    set camp select-new-camp
    set useRate random max-use-intensity + 1 ;; initial lithic use rate for camp > 0
    set task-counter task-counter + 1
    set mean-useRate (mean-useRate + useRate) / task-counter
  ]
end

to go
  ask fBands [
    ifelse tracks = true 
      [pen-down]
      [pen-up]
      
    ;; check whether new lithics are needed to replentish carried stock
    if f-flakes < lithic-stock [set need-provision true]
    
    ;; check whether arrived at camp or base camp
    ifelse ((trip = "outbound" and patch-here = camp) or (trip = "inbound" and patch-here = homeBase)) [
      set f-trips f-trips + 1
      set useRate random max-use-intensity + 1 ;; lithic use rate intensity (=tasks performed) for camps and basecamps
      set task-counter task-counter + 1 ;; count each occupation of a camp/basecamp
      set totalUse (totalUse + useRate)
      set mean-useRate totalUse / task-counter ;; mean useRate per occupation
      lithic-use
      camp-routine
    ][  
      if need-provision = true [
        ;; embedded procurement from prior camps 
        ;; if on an old camp, replenish stock from any available lithics
        if [sitetype] of patch-here = "camp" and [p-flakes + p-used + p-retouched] of patch-here > 0 and prov-from-site = true [
          restock-from-site
        ] 
        
        ;; embedded or specialized procurement (depending on visibility radius) from raw material sources
        ;; if lithics still needed, go to lithic source in visibility radius and replenish stock
        if any? lithicSources in-radius source-visibility [
          move-to one-of lithicSources in-radius source-visibility
          restock-from-source
          ;set provision-trips provision-trips + 1
        ]
        
      ]
    ]
        
    move
  ]
 
  ;; create output variables     
  set active-cores sum [f-cores] of fbands
  set active-debitage sum [f-flakes] of fbands + sum [f-used] of fbands
  set active-tools sum [f-retouched] of fbands + sum [f-exhausted] of fbands

  set source-tools sum [p-exhausted] of lithicSources + sum [p-retouched] of lithicSources
  set source-debitage sum [p-flakes] of lithicSources + sum [p-used] of lithicSources

  set basecamp-flakes sum [p-flakes] of basecamps
  set basecamp-used sum [p-used] of basecamps
  set basecamp-retouched sum [p-retouched] of basecamps
  set basecamp-exhausted sum [p-exhausted] of basecamps
  set basecamp-lithics basecamp-tools + basecamp-debitage
  set basecamp-tools sum [p-exhausted] of basecamps + sum [p-retouched] of basecamps
  set basecamp-debitage sum [p-flakes] of basecamps + sum [p-used] of basecamps

  set camp-flakes sum [p-flakes] of camps
  set camp-used sum [p-used] of camps
  set camp-retouched sum [p-retouched] of camps
  set camp-exhausted sum [p-exhausted] of camps
  set camp-lithics camp-tools + camp-debitage
  set camp-tools sum [p-exhausted] of camps + sum [p-retouched] of camps
  set camp-debitage sum [p-flakes] of camps + sum [p-used] of camps

  set total-tools sum [p-exhausted] of patches + sum [p-retouched] of patches - source-tools
  set total-debitage sum [p-flakes] of patches + sum [p-used] of patches - source-debitage
  
  if count camps > 0 [set camp-density (camp-tools + camp-debitage) / count camps] 
  if count basecamps > 0 [set basecamp-density (basecamp-tools + basecamp-debitage) / count basecamps] 
    
  ifelse camp-debitage > 0 or camp-tools > 0 
    [set camp-tool-freq camp-tools / (camp-debitage + camp-tools)]
    [set camp-tool-freq 0]
  ifelse basecamp-debitage > 0 or basecamp-tools > 0 
    [set basecamp-tool-freq basecamp-tools / (basecamp-debitage + basecamp-tools)]
    [set basecamp-tool-freq 0]
  ifelse source-debitage > 0 or source-tools > 0 
    [set source-tool-freq source-tools / (source-debitage + source-tools)]
    [set source-tool-freq 0]
  ifelse total-debitage > 0 or total-tools > 0
    [set total-tool-freq total-tools / (total-debitage + total-tools)]
    [set total-tool-freq 0]
  ifelse active-tools > 0 or active-debitage > 0 
    [set active-tool-freq active-tools / (active-tools + active-debitage)]
    [set active-tool-freq 0]

  set camp-tools-byfBand [] 
  set camp-debitage-byfBand []
  set base-tools-byfBand []
  set base-debitage-byfBand []

  foreach sort [who] of fBands [
    set camp-tools-byfBand lput (sum [p-retouched] of camps with [p-ID = ?] + sum [p-exhausted] of camps with [p-ID = ?]) camp-tools-byfBand
    set camp-debitage-byfBand lput (sum [p-flakes] of camps with [p-ID = ?] + sum [p-used] of camps with [p-ID = ?]) camp-debitage-byfBand
    set base-tools-byfBand lput (sum [p-retouched] of camps with [p-ID = ?] + sum [p-exhausted] of basecamps with [p-ID = ?]) base-tools-byfBand
    set base-debitage-byfBand lput (sum [p-flakes] of camps with [p-ID = ?] + sum [p-used] of basecamps with [p-ID = ?]) base-debitage-byfBand
    ]

;; various probes
;  print "*****" 
;  type "count patches: " print count patches
;  type "count sources: " print count lithicSources
;  type "count bases: " print count basecamps
;  type "all tools: " type sum [p-exhausted + p-retouched] of patches type ", source tools: " type source-tools type ", base tools: " type basecamp-tools type ", camp tools: " print camp-tools
;  type "all flakes: " type sum [p-flakes] of patches type ", source flakes: " type sum [p-flakes] of lithicSources type ", base flakes: " type sum [p-flakes] of basecamps type ", camp flakes: " print sum [p-flakes] of camps
;  type "all used: " type sum [p-used] of patches type ", source used: " type sum [p-used] of lithicSources type ", base used: " type sum [p-used] of basecamps type ", camp used: " print sum [p-used] of camps

  ;; if 0% < LMS < 100% each cycle (when cycles > 0) will randomly select land-use strategy within range specified by LMS. 
  ;; Can specify length of run by model ticks or foraging trips
  ifelse cycle-type = "foraging trips" 
    [set counter min [f-trips] of fBands]
    [set counter ticks]
  if cycles > 0 and counter >= cycles [
    ifelse runNumber >= runs 
       [stop]
       [ reset-ticks
;         type "basecamp retouched frequency = " print basecamp-tool-freq
;         type "basecamp lithics = " print basecamp-lithics
;         type "camp retouched frequency = " print camp-tool-freq
;         type "camp lithics = " print camp-lithics         
         ask fBands [set f-trips 0]
         set runNumber runNumber + 1
         ifelse LMS-pct > random 100 
           [set landUse "LMS"]
           [set landUse "RMS"]
       ]
     ]
  
  tick 
end

to move
  ;; pick a destination to move to

  ifelse trip = "inbound" [
    ;; return to home base
    if patch-here != homeBase [
      set heading towardsxy [pxcor] of homeBase [pycor] of homeBase
      fd 1
      ] 
  ] 
  [
    ;; move to next camp
    if patch-here != camp [
      set heading towardsxy [pxcor] of camp [pycor] of camp
      fd 1
    ]
  ]
  
end

To camp-routine
  ;; what to do when foragers arrive at a camp or basecamp
  if landUse = "RMS" [ 
    ;; trips are always outbound with RMS
    set trip "outbound"
    
    ;; next foraging camp
    ifelse 1 > random 5 [
      ;; return to basecamp sometimes even if RMS
      set camp homeBase
    ][
      ;; otherwise pick a camp from somewhere else in the territory
      set camp select-new-camp
    ]
  ]
  
  if landUse = "LMS" [
    if camp = patch-here [ ;; arrived at camp
      set trip "inbound" ;; return to basecamp
;      ask patch-here [set pcolor territory-color] ;; change color back to non-camp when leaving
    ]
    if homeBase = patch-here [ ;; arrived at home base
      ask patch-here [set pcolor homebase-color] ;; recolor home base
      set trip "outbound" ;; select next resource extraction camp
      set camp select-new-camp
    ]
  ]
  
  ;; set up for labeling patches with lithic counts and for coloring them to show relative frequencies of flakes, utilized, and retouched/exhausted artifacts
  if [sitetype] of patch-here = "camp" [
    ask patch-here [
      if show-lithics = "nothing" [set plabel ""] 
      if show-lithics = "flakes" [set plabel p-flakes]
      if show-lithics = "utilized" [set plabel p-used]
      if show-lithics = "retouched" [set plabel p-retouched]
      if show-lithics = "exhausted" [set plabel p-exhausted]
      let ptotal p-flakes + p-used + p-retouched + p-exhausted
      if ptotal > 0 [
        let g 256 * p-flakes / ptotal
        let b 256 * p-used / ptotal
        let r 256 * (p-retouched + p-exhausted) / ptotal
        set pcolor approximate-rgb r g b
      ]
    ]     
  ] 
end

to-report select-new-camp
  set camp one-of territory 
  let selectcamp true
  while [selectcamp = true] [ ;; differentiate camps from sources
    ifelse member? camp lithicSources or camp = homeBase
      [set camp one-of territory]
      [set selectcamp false]
  ]
  let idx who
  ask camp [
    set p-ID idx
    set sitetype "camp"
    set pcolor camp-color
    ]
  set camps (patch-set camp camps) ;; add patch to camps patchset

  report camp
end

to lithic-use
  ;; use up lithic utility, starting with flakes
  ;; flakes become used, used become retouched, and 
  ;; retouched become exhausted. Exhausted are discarded
  let use useRate
  let provision f-provision
  
  ;; probes
;  type "provision before = " print f-provision
;  type "flakes before = " print f-flakes
;  type "used before = " print f-used
;  type "retouched before = " print f-retouched
;  type "exhausted before = " print f-exhausted
;  print "  "
;  type "use = " print use
;  print "  "
    
  ;; deposit any place-provision lithics at site
  ask patch-here [set p-flakes p-flakes + provision]
  
  set f-flakes f-flakes - f-provision
  set f-provision 0
  set provision 0
      
  ;; first use up flakes
  while [f-flakes > 0 and use > 0] [
    set use use - 1
    set f-flakes f-flakes - 1
    set f-used f-used + 1
    
    ;; use any prevously stockpiled flakes if needed
    if f-flakes = 0 and [p-flakes] of patch-here > 0 and use > 0 [
      set f-flakes f-flakes + 1
      ask patch-here [set p-flakes p-flakes - 1]
    ]

    if use = 0 [
      ;; deposit any unused flakes
      let extra f-flakes - lithic-stock
      if extra > 0 [
        ask patch-here [set p-flakes p-flakes + extra]
        set f-flakes f-flakes - extra
      ]
    ]
  ]

  ;; next use up utlized flakes
  while [f-used > 0 and use > 0] [
    set use use - 1
    set f-used f-used - 1
    set f-retouched f-retouched + 1

    ;; use any stockpiled utilized flakes if needed
    if f-used = 0 and [p-used] of patch-here > 0 and use > 0 [
      set f-used f-used + 1
      ask patch-here [set p-used p-used - 1]
    ]
    if use = 0 [
      ;; deposit any extra used flakes
      let extra f-used + f-flakes - lithic-stock
      if extra > 0 [
        ask patch-here [set p-used p-used + extra]
        set f-used f-used - extra
      ]
    ]
  ]

  ;; finally, use up retouched flakes
  while [f-retouched > 0 and use > 0] [
    set f-retouched f-retouched - 1
    set f-exhausted f-exhausted + 1

    ;; use any stockpiled retouched flakes
    if f-retouched = 0 and [p-retouched] of patch-here > 0 and use > 0 [
      set f-retouched f-retouched + 1
      ask patch-here [set p-retouched p-retouched - 1]
    ]
    if use = 0 [
      ;; deposit any extra retouched flakes and all exhausted flakes
      let extra f-retouched + f-used + f-flakes - lithic-stock
      if extra > 0 [
        ask patch-here [set p-retouched p-retouched + extra]
        set f-retouched f-retouched - extra
      ]
    ]
  ]
  
  ;; deposit any exhausted flakes
  let exhausted f-exhausted
  ask patch-here [set p-exhausted p-exhausted + exhausted]

  ;; more probes
;  type "provision after = " print f-provision
;  type "flakes after = " print f-flakes
;  type "used after = " print f-used
;  type "retouched after = " print f-retouched
;  type "exhausted after = " print f-exhausted
;  
;  type "p flakes after = " print p-flakes
;  type "p used after = " print p-used
;  type "p retouched after = " print p-retouched
;  type "p exhausted after = " print p-exhausted
;  
;  print "**********"
;  print " "

  set f-exhausted 0
      
end

to restock-from-source
  ;; provision individuals and places
  let used f-used
  let retouched f-retouched
  let exhausted f-exhausted

  ;; For lithic sources: 
  ;; discard utilized, retouched, and exhausted pieces
  ;; reprovision foragers with fresh flakes

  ask patch-here [
    set p-used p-used + used
    set p-retouched p-retouched + retouched
    set p-exhausted p-exhausted + exhausted]
  ;;set source-tools source-tools + f-retouched + f-exhausted
  ;;set source-debitage source-debitage + f-used
  set f-used 0
  set f-retouched 0
  set f-exhausted 0
  set f-flakes lithic-stock
  
  ;; pick up extra lithics to provision next camp or base camp
  ifelse trip = "outbound" [
;    show "source provisioning for camp"
    set f-provision round((camp-provision - 1) * lithic-stock)
  ]
  [
;    show "source provisioning for base camp"
    set f-provision round((basecamp-provision - 1) * lithic-stock)
  ]
  set need-provision false
end
  
to restock-from-site
  ;; provision foragers from lithic stockpile at camp
  ;; if camp at source, provision as source

  let used f-used
  let retouched f-retouched
  let exhausted f-exhausted

  let extra-flakes 0
  let extra-used 0
  let extra-retouched 0
  ; set need-provision true
;  show "in site provision"
  
  ;; combine carried and stockpiled lithics
  set f-flakes f-flakes + [p-flakes] of patch-here
  set f-used f-used + [p-used] of patch-here
  set f-retouched f-retouched + [p-retouched] of patch-here
  
  if f-flakes >= lithic-stock [
    ;; replenish individuals' stocks with stockpiled flakes
    ;; and discard any extra
    set extra-flakes  f-flakes - lithic-stock
    ask patch-here [
      ;; discard any unneeded flakes along with all utilized, retouched, and exhausted pieces
      set p-flakes extra-flakes
      set p-used p-used + used
      set p-retouched p-retouched + retouched
      set p-exhausted p-exhausted + exhausted
    ]
;    print "**********"
;    type "extra flakes: " print extra-flakes
;    type "p used: " print [p-used] of patch-here
;    print "**********"
    set f-flakes lithic-stock
    set f-used 0
    set f-retouched 0
    set f-exhausted 0
    set need-provision false ;; enough from stockpile at site
;    show "no need for provision after site provision"
    stop
  ]
  if f-flakes + f-used >= lithic-stock [
    ;; replenish individuals' stocks with stockpiled flakes and utilized flakes
    set extra-used f-flakes + f-used - lithic-stock
    ask patch-here [
      set p-flakes 0
      set p-used extra-used
      set p-retouched p-retouched + retouched
      set p-exhausted p-exhausted + exhausted
    ]        
    set f-used f-used - extra-used
    set f-retouched 0
    set f-exhausted 0
    stop
  ]
  if f-flakes + f-used + f-retouched >= lithic-stock [
    ;; replenish individuals' stocks with stockpiled flakes, utilized flakes, and retouched flakes
    set extra-retouched f-flakes + f-used + f-retouched - lithic-stock
    ask patch-here [
      set p-flakes 0
      set p-used 0
      set p-retouched extra-retouched
      set p-exhausted p-exhausted + exhausted
    ]        
    set f-retouched f-retouched - extra-retouched
    set f-exhausted 0
    stop
  ]
  if f-flakes + f-used + f-retouched < lithic-stock [
    ;; not enough stockpiled to replenish individuals' stocks
    ;; just discard exhausted pieces
    ask patch-here [
      set p-flakes 0
      set p-used 0
      set p-retouched 0
      set p-exhausted p-exhausted + exhausted
    ]
    set f-exhausted 0
  ]  
end
@#$#@#$#@
GRAPHICS-WINDOW
455
10
1269
605
100
70
4.0
1
10
1
1
1
0
1
1
1
-100
100
-70
70
1
1
1
ticks
30.0

SLIDER
10
55
150
88
bands
bands
1
50
1
1
1
NIL
HORIZONTAL

SLIDER
10
135
150
168
sources
sources
0
3
0.5
.1
1
per 100 cells
HORIZONTAL

SLIDER
10
95
150
128
territory-radius
territory-radius
1
100
30
1
1
NIL
HORIZONTAL

BUTTON
10
10
150
43
NIL
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
160
10
300
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

SLIDER
160
55
300
88
max-use-intensity
max-use-intensity
1
100
30
1
1
NIL
HORIZONTAL

SLIDER
160
95
300
128
lithic-stock
lithic-stock
1
100
20
1
1
NIL
HORIZONTAL

SWITCH
10
605
140
638
tracks
tracks
0
1
-1000

MONITOR
310
205
440
250
base camp tool freq
basecamp-tool-freq
2
1
11

MONITOR
310
105
440
150
camp tool freq
camp-tool-freq
2
1
11

PLOT
10
360
440
545
Discarded Tool Frequency
time
frequency
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"camps" 1.0 0 -13791810 true "" "plot camp-tool-freq"
"base camps" 1.0 0 -2674135 true "" "plot basecamp-tool-freq"
"all sites" 1.0 0 -16777216 true "" "plot total-tool-freq"

SLIDER
10
250
150
283
LMS-pct
LMS-pct
0
100
48
1
1
%
HORIZONTAL

INPUTBOX
85
290
150
350
runs
5
1
0
Number

INPUTBOX
10
290
80
350
cycles
500
1
0
Number

MONITOR
310
305
365
350
run #
runNumber
0
1
11

MONITOR
375
305
440
350
land use
landUse
17
1
11

MONITOR
310
10
440
55
in use tool freq
active-tool-freq
2
1
11

SLIDER
10
210
300
243
camp-provision
camp-provision
1.0
4
1.1
.05
1
X lithic stock
HORIZONTAL

SLIDER
10
175
300
208
basecamp-provision
basecamp-provision
1.0
4
1.5
.05
1
X lithic stock
HORIZONTAL

SLIDER
160
135
300
168
source-visibility
source-visibility
0
50
4
1
1
NIL
HORIZONTAL

CHOOSER
10
555
140
600
show-lithics
show-lithics
"nothing" "flakes" "utilized" "retouched" "exhausted"
2

TEXTBOX
155
555
375
665
Color key:\n  basecamps = black\n  lithic sources = brown\n  camps = white unless provisioned\n  provisioned camps colored as RGB with\n    % retouched + exhausted as RED channel\n    % utilized as BLUE channel\n    % flakes as GREEN channel
10
0.0
1

CHOOSER
155
290
300
335
cycle-type
cycle-type
"model cycles" "foraging trips"
0

MONITOR
310
60
440
105
total camp lithics
camp-lithics
0
1
11

MONITOR
310
160
440
205
total basecamp lithics
basecamp-lithics
0
1
11

SWITCH
160
250
300
283
prov-from-site
prov-from-site
1
1
-1000

MONITOR
310
255
440
300
mean use rate
mean-useRate
1
1
11

@#$#@#$#@
## WHAT IS IT?

This model was developed in order to carry out systematic experiments in the effects of social and environmental parameters on the formation of lithic (chipped stone artifact) assemblages in archaeological sites.

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)
Agents represent forager (or hunter-gather) bands who move, collect, and use resources within a territory. The only resources explicitly modeled here are stone. 

Two different land-use strategies can be modeled, representing different ways of using the territory and acquiring resources. Logistical mobility (also known as central-place foraging) involves foragers having a base camp from which they make forays to targeted resource camps to collect resources and return them to the base camp for consumption. With residential mobility, foragers move their camp to various locals within the territory, and collect and use resources at the the camp. The model is designed so that a single land-use strategy can be used for an entire simulation run or land-use strategy can alternate during a simulation run. When land-use can alternate between strategies, <LMS-pct> determines what fraction of the time logistical mobility is used and (by default) the fraction of time residential mobility is used.

Foragers can carry a number of lithic artifacts with them. The maximum a forager agent can carry normally is determined by the <lithic-stock> variable. Whenever a forager band stops at a new camp, it uses lithic artifacts at a rate determined by a random number within the range of the <maximum-use-intensity> variable. As an artifact is used, it is transformed through four states: from unused to used to retouched to exhausted. When an artifact is exhausted, it is discarded. When an agent leaves a camp, it carries with it all non-exhausted lithic artifacts.

As forager agents move from camp to camp (including from base camp to targeted resource extraction camp and back), they may encounter raw material sources (naturally occuring stone outcrops) on the landscape. The density of lithic sources is determined at the beginning of a simulation run by the <sources> variable. An agent's ability to perceive a raw material source is determined by the <source-visibility> variable. If an agent has less than the <lithic-stock> number of unused lithic artifacts and perceives a raw material source, it will move to the source to replenish its stock of lithic artifacts. It replaces all used, retouched, and exhausted artifacts with fresh, unused ones (discarding the artifacts replaced). It collects enough additional artifacts to ensure that it leaves the raw material source site with unused artifacts equal to <lithic-stock>, continuing enroute to the next camp. 

A forager agent temporarily can carry lithic material above what it normally carries (i.e., deterimined by <lithic-stock>) to provision the next camp it reaches after visiting a lithic source. The amount extra that can be carried from a source to a basecamp is determined by the <basecamp-provision> variable; the amount extra that can be carried to all other types of camps is deterimined by the <camp-provision> variable. Before leaving a camp, a forager agent will discard all extra lithic artifacts so that it leaves with a set of the "best" (i.e., most unused) artifacts possible to carry to the next camp, the size of this artifact set being determined by the <lithic-stock> variable. Optionally, and determined by the <prov-from-site variable>, if there are artifacts deposited at a camp from a previous visit, a forager agent can replace its most used artifacts (e.g., retouched) with less used or unused artifacts from the artifacts accumulated in a camp before leaving to ensure that it leaves with the "best" artifact set possible.

The number of artifacts in use and their condition is constantly tracked and can be viewed in monitors. The number of artifacts deposited in each patch and their condition is also tracked and can be collected and analyzed at the end of a simulation. These artifacts in a patch simulate the lithic assemblages that accumulate in archaeological sites over the course of time, as mobile foragers move from camp to camp and acquire, use, and discard lithic artifacts. 


## HOW TO USE IT

Each of the variables described above can be set by sliders or, in the case of <prov-from-site> a switch. The count of artifacts of in different conditions can be displayed in each patch via selections in the <show-lithics> chooser, and the paths that forager agents travel can be displayed as tracks wiht the <tracks> switch.

Entry fields allow the user to control the behavior of the simulation with respect to "cycles" and "runs". A cycle can simply be a timer tick (= the movement of each agent 1 patch), or it can represent a "trip"--from basecamp to targeted resource extaction camp for logistical mobility or from camp to camp for residential mobility--set with the <cycle-type> variable chooser. 

A "run" is the completion of the preset number of cycles. Before each run, the land-use strategy can change stochastically, with the probability of logistical mobility deterimined by <LMS-pct> variable. (The probability of residential mobility is simply 100% - <LMS-pct>). A single simulation can consist of multiple runs, which can vary with repect to land-use strategy, of multiple cycles.   

## THINGS TO NOTICE

Look at the spatial distribution patterns of sites and assemblages within a territory, or across the territories of multiple forager agents, that accumulates over time.

## THINGS TO TRY

Setting land-use to 100% LMS and using BehaviorSpace to vary the cycles in a run and collect information on the lithic assemblages accumulated in a basecamp during each run can simulate variable occupation time of a deeply stratified site. 

## EXTENDING THE MODEL

Currently, forager agents do not need food to live and do not expend energy to move. These could be added to the model to make it more realistic. some users might also want to add different core and blank types. 

## NETLOGO FEATURES

A number of probes (including type, print, and show statements) are built into the code to help debug and collect additional information during model operation. These can be activated by uncommenting the lines.

## RELATED MODELS

None

## CREDITS AND REFERENCES

Copyright C. Michael Barton (Arizona State University) & Julien Riel-Salvatore (University of Colorado, Denver)

![CC BY-NC-SA 3.0](http://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="vary intensity" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <steppedValueSet variable="max-use-intensity" first="10" step="5" last="40"/>
    <enumeratedValueSet variable="lithic-stock">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary abundance" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="50"/>
    </enumeratedValueSet>
    <steppedValueSet variable="sources" first="5" step="5" last="50"/>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary provisioning 1" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="basecamp-provision" first="2" step="0.2" last="4"/>
  </experiment>
  <experiment name="vary landuse 1" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <steppedValueSet variable="LMS-pct" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="sources">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary landuse 2" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <steppedValueSet variable="LMS-pct" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="sources">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary provisioning 2" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="basecamp-provision" first="1" step="0.5" last="4"/>
  </experiment>
  <experiment name="vary landuse 3" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <steppedValueSet variable="LMS-pct" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="sources">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary provisioning 3" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="camp-provision" first="1" step="0.5" last="4"/>
  </experiment>
  <experiment name="vary distance &amp; landuse" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <metric>camp-tools-byfBand</metric>
    <metric>camp-debitage-byfBand</metric>
    <metric>base-tools-byfBand</metric>
    <metric>base-debitage-byfBand</metric>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="0"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="10"/>
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>camp-tool-freq</metric>
    <metric>basecamp-tool-freq</metric>
    <metric>total-tool-freq</metric>
    <metric>active-tool-freq</metric>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tracks">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="source-visibility">
      <value value="5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="sources" first="0.1" step="0.1" last="0.5"/>
  </experiment>
  <experiment name="vary provisioning" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>basecamp-provisioning</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tool-freq</metric>
    <enumeratedValueSet variable="lithic-stock">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="from-site">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="source-visibility">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-lithics">
      <value value="&quot;nothing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prov-pct">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="75"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-mobility-no-provisioning" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="0"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prov-from-site">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-mobility&amp;provisioning" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="0"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prov-from-site">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.1"/>
      <value value="1.3"/>
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-mobility with provisioning" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="LMS-pct" first="0" step="20" last="100"/>
    <enumeratedValueSet variable="prov-from-site">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-mobility&amp;abundance" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <steppedValueSet variable="sources" first="0.2" step="0.4" last="2"/>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="0"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prov-from-site">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-occupationduration" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="1"/>
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prov-from-site">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-palimpsests" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="1"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="LMS-pct" first="0" step="20" last="100"/>
    <enumeratedValueSet variable="prov-from-site">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-activities" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="LMS-pct">
      <value value="0"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prov-from-site">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ex2-mobility with provisioning and site provisioning" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>landUse</metric>
    <metric>count camps</metric>
    <metric>basecamp-flakes</metric>
    <metric>basecamp-used</metric>
    <metric>basecamp-retouched</metric>
    <metric>basecamp-exhausted</metric>
    <metric>basecamp-lithics</metric>
    <metric>basecamp-tools</metric>
    <metric>basecamp-debitage</metric>
    <metric>camp-flakes</metric>
    <metric>camp-used</metric>
    <metric>camp-retouched</metric>
    <metric>camp-exhausted</metric>
    <metric>camp-lithics</metric>
    <metric>camp-tools</metric>
    <metric>camp-debitage</metric>
    <enumeratedValueSet variable="source-visibility">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-use-intensity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sources">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lithic-stock">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="runs">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cycle-type">
      <value value="&quot;foraging trips&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="LMS-pct" first="0" step="20" last="100"/>
    <enumeratedValueSet variable="prov-from-site">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="basecamp-provision">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="camp-provision">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="territory-radius">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bands">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
