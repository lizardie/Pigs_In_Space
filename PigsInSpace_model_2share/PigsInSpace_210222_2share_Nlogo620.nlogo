extensions  [gis table array]

breed       [pigs pig]
breed       [snacks snack]

globals
[
  model-time
  mean-penetration
  mean-depth
  front
  food-facto
  food-plan
  snacks-num-start
  each-pig-sallies
  each-pig-route-lengths
  ;each-pig-visits
  Lcosts                ; list of costs available [0.001 0.1 0.25 0.5 0.75 999999]
  Lmean-visits
  ratio                 ;amount of food per pig num-of-snacks-to-start / (count pigs)
  list-of-pig-x
  list-of-pig-y
  snack-patch-list-h
]

patches-own
[
  cost
  pahim
  parent-patch  ; patch's predecessor
  f             ; the value of knowledge plus heuristic cost function f()
  g             ; the value of knowledge cost function g()
  h             ; the value of heuristic cost function h()
  pigvisits        ; counter of pig visits
  pigforagevisits  ; counter of pig visits when foraging
]

pigs-own
[
  pig-state            ;; either "foraging" or "feeding" or "passive"
  pig-satiety          ;; amount of food-units eaten till now
  pig-energy           ;; energy lost on walking, distance*cost
  pig-target           ;; current pig's target snack position
  pig-optimal-path     ;; the optimal path from source to destination
  pig-opt-path-cost    ;; cost of the last optimal path checked
  pig-opt-path-dist    ;; length of the last optimal path checked
  this-path-cost       ;; costdistance of this path
  this-path-distance   ;; length of this path in patches
  pig-current-path     ;; part of the path that is left to be traversed
  pig-home             ;; patch where pig was born
  pig-time-feeding     ;; time since the pig started deeding in ticks
  pig-penetration      ;; distance from the os boundary, here distance to pig-home
  pig-depth            ;; pig penetration distance
  pig-snacks-eaten     ;; list of snacks the pig has eaten
  pig-current-sally    ;; list of patches the pig walks through between two snacks
  ;;                      (de facto, as opposed to current-path which is intended path of a sally)
  pig-sallies          ;; list of sallies the pig walked
  pig-patches-visited  ;; count of patches visited by the pig
  traveled             ;; distance traveled by the pig
  Tpig-ptypes          ;; table of patch types the pig traveled through
  Lpig-ptypes2         ;; list of patch types the pig traveled through
  pig-max-xcor-ever    ;; max easting
  my-snacks            ;; snacks the pig is checking out now
  start-time           ;; time to start moving in ticks (random 0-599)
]

snacks-own
[
  snack-food-left
  dibs
  snack-attractiveness
]

;;; 1 tick = 1 min
;;; max-ticks = 600 is one night = 10 h = 600 min
;;; pigs move 5 m/min which is 1 cell each tick





;;██████ go ███████████████████████████████████████████████████████████████
;;██████ go ███████████████████████████████████████████████████████████████
;;██████ go ███████████████████████████████████████████████████████████████
;;
to go
  set model-time (word (floor ((floor (ticks / 60)) / 60)) " : " ((floor (ticks / 60)) mod 60) )
  if (ticks >= max-ticks)
  [
    export-data-to-list
    ;user-message
    show "night is over"
    repeat 3 [ beep ]
    stop
  ]
  if (not any? pigs with [pig-state != "passive"])
  [
    export-data-to-list
    show "all pigs are blue"
    repeat 5 [ beep ]
    stop
  ]
  ask pigs
  [
    set label pig-state
    ;set list-of-pig-x lput (xcor * 5) list-of-pig-x
    ;set list-of-pig-y lput (ycor * 5) list-of-pig-y
    if pig-state != "waiting"
    [
      ask patch-here [
        set pigvisits pigvisits + 1
      ]
    ]
    ifelse pig-state = "foraging"
    [
      ;;if foraging
      forage
      set pigforagevisits pigforagevisits + 1
      set list-of-pig-x lput (xcor * 5) list-of-pig-x
      set list-of-pig-y lput (ycor * 5) list-of-pig-y
    ]
    [
      ;;if not foraging
      ifelse pig-state = "feeding"
      [
        ;;if feeding
        feed
      ]
      [
        ifelse pig-state = "waiting"
        [
          ;;if waiting
          waitStart
        ]
        [
          ;;if not foraging and not feeding and not waiting
          if (pig-state != "passive")
          [
            user-message (word "Error: a pig with weird pig-state=" pig-state)
          ]
        ]
      ]
    ]
  ]
  set mean-penetration mean [pig-penetration] of pigs
  set mean-depth mean [pig-depth] of pigs
  set front max (list (max [pig-penetration] of pigs) )
  set food-facto sum [snack-food-left] of snacks
  tick
end



;;██████ go procedures ██████


;;██████ waitStart ██████████████████████████████████████████
to setup-waiting
  ifelse random_start_time?
  [
    let wait_RD random 600
    set start-time wait_RD
  ]
  [
    set start-time 1
  ]
  set pig-state "waiting"
  set color magenta
end

to waitStart
  if ticks >= start-time
  [
    set pig-state "foraging"
  ]

end

;;██████ forage ██████████████████████████████████████████


to forage
  ifelse any? snacks
  [
    ;;if snacks exist
    set color red
    ;;set target
    ifelse pig-target = 0 or pig-current-path = [] or target-dibs?
    [
      ;;if pig has no target or path
      ask my-links [die]
      set my-snacks snack-list
      ask my-links [die]
      ifelse first-target-probabilistic
      [
        set pig-target select-pig-target-probabilistic my-snacks patch-here
        LCP pig-target
      ]
      [
        select-a-target patch-here
      ]
    ]
    [
      ;;if pig has a target then with probability of p-min
      let p_r random-float 1
      if  p_r <= p-min
      [
        ;;check whether there are any snacks that aren't dibs and closer than the target
        let pig-target-snack one-of snacks-on pig-target
        let distance-to-target distance pig-target-snack
        let attractiveness-of-target attractiveness pig-target-snack patch-here
        ;;if there are any snacks closer than target here
        if any? snacks with
        [
          ;distance myself < distance-to-target and dibs = 0
          (attractiveness self patch-here > attractiveness-of-target) and dibs = 0
        ]
        [
          ;;select with attractiveness less than target and not dibs
          ;set my-snacks snacks with [(attractiveness self patch-here > attractiveness-of-target) and dibs = 0] ;;;***
          set my-snacks snacks with [(attractiveness self patch-here > attractiveness-of-target) and dibs = 0 and distance myself <= smell-range and distance myself >= 1]  ;;***
          reset-target-and-path
          ask my-links [die]
          select-a-target patch-here
        ]
      ]
    ]
    ;;pig has target and path
    let energy1 [cost] of patch-here
    let old-patch patch-here
    step-on-path
    let energy2 [cost] of patch-here
    let stepcost (energy1 + energy2) * 0.5 * distance old-patch
    set pig-energy pig-energy - stepcost
    set pig-penetration distance pig-home
    set pig-depth xcor - ([pxcor] of pig-home)
    set pig-current-sally lput patch-here pig-current-sally
    if patch-here = pig-target
    [
      ;;pig arrived at target
      reset-target-and-path
      if any? snacks-here
      [
        ;;there is a snack at target
        ifelse any? other pigs-here with [pig-state = "feeding"]
        [
          ;;if another pig is here feeding it has dibs on this snack
          ask snacks-here [set dibs 1]
        ]
        [
          ;;there is a snack and nobody has dibs on it
          set pig-state "feeding"
          set pig-snacks-eaten pig-snacks-eaten + 1
          ;;copy current sally details to list of sallies and reset current sally
          set pig-sallies lput pig-current-sally pig-sallies
          set pig-current-sally []
          set color white
          set pig-time-feeding 0
          ask snacks-here [set dibs 1]
        ]
      ]
    ]
    ;update-pig-memory
  ]
  [
    ;;if no snacks exist become blue :(
    be-blue
  ]
end


to select-a-target [patch-origin]
  ifelse target-selection = "probabilistic"
      [
        set pig-target select-pig-target-probabilistic my-snacks patch-origin
        LCP pig-target
      ]
      [
        ifelse target-selection = "deterministic"
        [
          set pig-target select-pig-target-deteriministic my-snacks patch-origin
          LCP pig-target
        ]
        [
          ifelse target-selection = "low-cost" ;;***
          [
            select-ptarget-low-cost my-snacks patch-origin
          ]
          [
            show "weird target selection"
          ]
        ]
      ]
end


to be-blue
  reset-target-and-path
  set pig-state "passive"
  set color blue
end



to-report select-pig-target-deteriministic [the-snacks patch-origin]
  let best-snack max-one-of the-snacks [attractiveness self patch-origin]
  ifelse is-agent? best-snack
  [
    create-link-with best-snack [set color white]
    let best-psnack [patch-here] of  best-snack
    report best-psnack
  ]
  [
    report 0
  ]
end



to select-ptarget-low-cost [the-snacks patch-origin]
  ;show the-snacks
  ;; ***
  ;; 1-sort snacks by attractiveness
  ;; 2-start with the 1st one most attractive
  ;;   calculate path to it, path-cost and path-distance
  ;;   if path-cost/path-distance < gamma then
  ;;      set this snack as target, this path as current-path
  ;;   else select another snack
  ;; 3-do this until the target is chosen or list is empty
  ;; 4-if list is empty be-blue
  ;;

  ask the-snacks
  [
    set snack-attractiveness attractiveness self patch-origin
  ]
  let list-of-my-snacks reverse sort-on [snack-attractiveness ] the-snacks ;;sort snacks by attractiveness
  ;; shorten list-of-my-snacks to min of n-snacks or all snacks
  if n-snacks >= (length list-of-my-snacks)
  [
    let list-length length list-of-my-snacks
    let last-item list-length
    set list-of-my-snacks sublist list-of-my-snacks 0 last-item ;;******
 ]
  while [ pig-target = 0 and not empty? list-of-my-snacks]
  [
    let best-snack first list-of-my-snacks ;;select 1st snack
    ;show best-snack
    create-link-with best-snack [set color white]
    set list-of-my-snacks but-first list-of-my-snacks ;;remove 1st snack from list
    let pbest-snack [patch-here] of  best-snack  ;;find a patch under 1st snack

    let this-path find-a-path pbest-snack patch-origin ;find a path to 1st snack
    ;show this-path
    if length this-path > 0
    [
      set this-path-cost 0
      set this-path-distance 0
      let left-of-this-path this-path
      while [length left-of-this-path > 1]
      [
        let parent-p first left-of-this-path
        ;show parent-p
        set left-of-this-path but-first left-of-this-path
        let child-p first left-of-this-path
        ;show child-p
        let stepdistance Euclidian parent-p child-p
        ;show (word "stepdistance=" stepdistance)
        let stepcost ([cost] of parent-p + [cost] of child-p) * 0.5 * stepdistance
        ;show (word "stepcost=" stepcost)
        set this-path-cost this-path-cost + stepcost
        set this-path-distance this-path-distance + stepdistance
      ]
      ;show (word "this-path-cost=" this-path-cost)
      ;show (word "this-path-distance=" this-path-distance)
      let path-toll this-path-cost / this-path-distance ;;average cost per patch on the path****
      ;show (word "path-toll=" path-toll) ;****
      ifelse path-toll < gamma
      [
        set pig-target pbest-snack
        set pig-optimal-path  reverse this-path
        ;show pig-current-path
        set pig-current-path pig-optimal-path
        set pig-opt-path-cost this-path-cost
        set pig-opt-path-dist this-path-distance
      ]
      [
        ask my-links [die]
      ]
    ]
  ]
  if length list-of-my-snacks <= 1 and pig-target = 0
  [
    be-blue
    reset-target-and-path
  ]
end




to-report snack-list
  let temp-snack-list snacks with
  [
    distance myself <= smell-range  ;;smell-range is usually 50 or 100
    and
    distance myself >= 1
    and
    dibs = 0
  ]
  report temp-snack-list
end





to-report select-pig-target-probabilistic [the-snacks patch-origin]
  let p_r random-float 1
  ifelse any? the-snacks
  [
      let sorted-my-snacks sort-on [distance myself] the-snacks
      let closest-n-snacks []
      let n-origins []
      let n min (list n-snacks length sorted-my-snacks)
      foreach n-values n [ ?1 -> ?1 ]
      [ ?1 ->
        set closest-n-snacks lput (item ?1 sorted-my-snacks) closest-n-snacks
        set n-origins lput patch-origin n-origins
      ]
      let list-of-attr (map attractiveness closest-n-snacks n-origins)
      let sum-attr (reduce + list-of-attr)
      let list-of-prob map [ ?1 -> ?1 / sum-attr ] list-of-attr
      let list-cumul-prob partial-sums list-of-prob
      let p random-float 1
      let list-cumul-prob2 []
      foreach list-cumul-prob
      [ ?1 ->
        if ?1 <= p
        [
          set list-cumul-prob2 fput ?1 list-cumul-prob2
        ]
      ]
      let best-prob 0
      ifelse not empty? list-cumul-prob2
      [
        set best-prob (max list-cumul-prob2)
      ]
      [
        let r position (max list-of-prob) list-of-prob
        set best-prob item r list-cumul-prob
      ]
      let i position best-prob list-cumul-prob
      let best-snack item i closest-n-snacks
      create-link-with best-snack [set color white]
      let best-psnack [patch-here] of  best-snack
      report best-psnack
  ]
  [
    report 0
  ]
end


to-report partial-sums [nums]
  let total 0
  let result []
  foreach nums [ ?1 ->
    set total total + ?1
    set result lput total result
  ]
  report result
end



to-report attractiveness [of-snack at-patch]
  let A0 [snack-food-left] of of-snack
  let d Euclidian of-snack at-patch
  let alpha (ln c) / (k * x_a)
  let A (A0 * exp (-1 * alpha * d))
  report A
end



to-report target-dibs?
  let dibsy false
  ifelse any? snacks-on pig-target
  [
    ask one-of snacks-on [pig-target] of self
    [
      if dibs = 1
      [
        set dibsy true
      ]
    ]
  ]
  [
    set dibsy true
  ]
  report dibsy
end



to reset-target-and-path
  set pig-target 0
  set pig-current-path []
  ;set my-snacks []
  set pig-opt-path-cost 999999
  ask my-links [die]
end




to LCP [target]
  ifelse is-agent? target
  [
    ;let temp-path-cost 0 ;;***
    set pig-optimal-path find-a-path patch-here target
    ;set optimal-path pig-optimal-path
    set pig-current-path pig-optimal-path
    set color violet
  ]
  [
    show "snack dissapeared"
    ;be-blue
    reset-target-and-path
  ]
end



to step-on-path
  ;; make the pig traverse the path one step towards the destination patch
  if (length pig-current-path != 0)
  [
    face first pig-current-path
    pd
    set pen-size 3 ;2 ;2.5 ;7 ;2.5
    set traveled traveled + distance first pig-current-path
    move-to first pig-current-path
    set pig-current-path remove-item 0 pig-current-path
    pu
    pig-count-patch-types
    set Lmean-visits pig-ptypes-visits-mean
    if xcor > pig-max-xcor-ever [ set pig-max-xcor-ever xcor ]
  ]
end

to pig-count-patch-types
  let current-ptype [cost] of patch-here
  let visits table:get Tpig-ptypes current-ptype
  set visits visits + 1
  ;; table:pu tableName key value
  table:put Tpig-ptypes current-ptype visits
  let #cost-item position current-ptype Lcosts
  set Lpig-ptypes2 replace-item #cost-item Lpig-ptypes2 visits
  set pig-patches-visited pig-patches-visited + 1
end



to-report find-a-path [ source-patch destination-patch ]
  ; the actual implementation of the A* path finding algorithm
  ; it takes the source and destination patches as inputs
  ; and reports the optimal path if one exists between them as output
  ;-------------------------------------------
  ; initialize all variables to default values
  let search-done? false
  let search-path []
  let current-patch 0
  let open []
  let closed []
  ;-------------------------------------------
  ; add source patch in the open list
  ask source-patch
  [
    set parent-patch 0
  ]
  set open lput source-patch open
  ;-------------------------------------------
  ; loop until we reach the destination or the open list becomes empty
  while [ (search-done? != true)]
  [
    ifelse length open != 0
    [
      ; sort the patches in open list in increasing order of their f() values
      set open sort-by [ [?1 ?2] -> [f] of ?1 < [f] of ?2 ] open
      ;---------------------------------------
      ; take the first patch in the open list
      ; as the current patch (which is currently being explored (n))
      ; and remove it from the open list
      set current-patch item 0 open
      set open remove-item 0 open
      ;---------------------------------------
      ; add the current patch to the closed list
      set closed lput current-patch closed
      ;---------------------------------------
      ; explore the neighbors of the current patch
      ask current-patch
      [
        ;;if any of the neighbors is the destination stop the search process - Moore (8 neighbors)
        ifelse any? neighbors with [ (pxcor = [ pxcor ] of destination-patch) and (pycor = [pycor] of destination-patch)]
        [
          set search-done? true
        ]
        [
          ; the neighbors should not be obstacles or already explored patches (part of the closed list)
          let obstacle 999999
          ifelse can-cross-roads? [set obstacle 1] [set obstacle 0.75]
          ;ask neighbors with [ cost < 1  and (not member? self closed) and (self != parent-patch) ]  ;Moore 8 neighbors not neighbors4
          ask neighbors with [ cost < obstacle  and (not member? self closed) and (self != parent-patch) ]  ;Moore 8 neighbors not neighbors4
          [
            ; the neighbors to be explored should also not be the source or
            ; destination patches or already a part of the open list (unexplored patches list)
            if not member? self open and self != source-patch and self != destination-patch
            [
              ;if color-foraging [set pcolor 88]
              ; add the eligible patch to the open list
              set open lput self open
              ;--------------------------------
              ; update the path finding variables of the eligible patch
              set parent-patch current-patch
              set g (my-g parent-patch self)
              ;set h ((distance destination-patch) * h-param)
              set h ((Euclidian self destination-patch) * h-param)
              ;set h ((distance destination-patch) * 0.25)  ;;A*, 0.25 is the min cost of non-OS area (0.01 0.05 0.1 0.25)
              ;set h ((distance destination-patch) * 1)     ;;Greedy Best-First-Search
              ;set h ((distance destination-patch) * 0)     ;;Breadth First Search
              set f (g + h)
            ]
          ]
        ]
        if color-foraging [if self != source-patch [set pcolor 87]]
      ]
    ]
    [
      ; if a path is not found (search is incomplete) and the open list is exhausted
      ; display a user message and report an empty search path list.
      ;;perhaps insead add here choose-another-destination◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄
      show (word "A path from the source to the destination does not exist." )
      if is-patch? pig-target
      [
        ask pig-target [ask snacks-here [set dibs 1]]
      ]
      set color turquoise
      reset-target-and-path
      report []
    ]
  ]
  ;;-------------------------------------------
  ;; if a path is found (search completed) add the current patch
  ;; (node adjacent to the destination) to the search path.
  set search-path lput current-patch search-path
  ;;
  ;; calculate total path cost      ;;◄*** ==== ***◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄
  ;set this-path-cost my-g current-patch destination-patch
  ;-------------------------------------------
  ; trace the search path from the current patch
  ; all the way to the source patch using the parent patch
  ; variable which was set during the search for every patch that was explored
  let temp first search-path
  while [ temp != source-patch ]
  [
    if color-path [ask temp [set pcolor cyan]]
    set search-path lput [parent-patch] of temp search-path
    set temp [parent-patch] of temp
  ]
  ;-------------------------------------------
  ; add the destination patch to the front of the search path
  set search-path fput destination-patch search-path
  ;-------------------------------------------
  ; reverse the search path so that it starts from a patch adjacent to the
  ; source patch and ends at the destination patch
  set search-path reverse search-path
  ;-------------------------------------------
  report search-path
end



to-report my-g [my-parent my-patch]
  let g-parent ([g] of my-parent)
  let my-cost [cost] of my-patch
  let parent-cost [cost] of my-parent
  let dist Euclidian my-parent my-patch
  let move-cost 0.5 * ( my-cost + parent-cost)
  report (g-parent + move-cost * dist )
end

to-report my-g2 [my-parent my-patch]
  let g-parent ([g] of my-parent)
  let my-x [pxcor] of my-patch
  let my-y [pycor] of my-patch
  let my-cost [cost] of my-patch
  let parent-x [pxcor] of my-parent
  let parent-y [pycor] of my-parent
  let parent-cost [cost] of my-parent
  let dist sqrt ((my-x - parent-x) ^ 2 + (my-y - parent-y) ^ 2)
  ;let dist2 distance my-parent
  let move-cost 0.5 * ( my-cost + parent-cost)
  report (g-parent + move-cost * dist )
end


to-report Euclidian [agent1 agent2]
  let x1 0.0
  let x2 0.0
  let y1 0.0
  let y2 0.0
  if is-patch? agent1
  [
    set x1 (x1 + [pxcor] of agent1)
    set y1 (y1 + [pycor] of agent1)
  ]
  if is-patch? agent2
  [
    set x2 (x2 + [pxcor] of agent2)
    set y2 (y2 + [pycor] of agent2)
  ]
  if is-turtle? agent1
  [
    set x1 [xcor] of agent1
    set y1 [ycor] of agent1
  ]
  if is-turtle? agent2
  [
    set x2 [xcor] of agent2
    set y2 [ycor] of agent2
  ]
  ;let Upsilon sqrt ( ( x1 - x2) ^ 2 + ( y1 - y2 ) ^ 2 )
  ;show (word x1 " " x2  " " y1  " " y2  " " Upsilon)
  ;report Upsilon
  report sqrt ( ( x1 - x2) * ( x1 - x2) + ( y1 - y2 ) * ( y1 - y2 ) )
end
;;██████ feed ██████████████████████████████████████████


to feed
  ifelse any? snacks-here
  [
    ;;still some snacks here
    let current-snack one-of snacks-here
    let eaten 0
    let feeding-time pig-time-feeding
    ask current-snack
    [
      ifelse snack-food-left > 0
      [
        ;;if there is food still - eat it
        ifelse feeding-time < max-time-feeding
        [
          ;;if there is still time to feed
          ;set color orange
          set snack-food-left (snack-food-left - 1)
          ;set label snack-food-left
          set eaten eaten + 1
          set feeding-time  feeding-time + 1
          ;set size ( 1 / zoomin ) + 1 * (snack-food-left / snack-size)
          set size ( 1 / zoomin ) + 1 ;* (snack-food-left / snack-size)
        ]
        [
          ;;feeding time is over
          ask myself
          [
            ;ask the pig that asked the current-snack
            set pig-state "foraging"
            set color red
            reset-target-and-path
            set pig-time-feeding 0
          ]
          set dibs 0
        ]
      ]
      [
        ;;if the food is finished - snack disappears
        ask myself
        [
          ;ask the pig that asked the current-snack
          set pig-state "foraging"
          set color red
          set pig-target 0
          set pig-current-path []
          set pig-time-feeding 0
        ]
        die
      ]
    ]
    set pig-satiety (pig-satiety + eaten)
    set pig-time-feeding feeding-time
  ]
  [
    ;;no more snacks here
    set pig-state "foraging"
    set color red
    set pig-target 0
    set pig-current-path []
  ]
end



;;██████ memory


to update-pig-memory
end


;;██████ setup ████████████████████████████████████████████████████████████
;;██████ setup ████████████████████████████████████████████████████████████
;;██████ setup ████████████████████████████████████████████████████████████


to setup
  ca
  set list-of-pig-x []
  set list-of-pig-y []
  if set-random-seed? [random-seed behaviorspace-run-number * 7 + 66]
  if set-usr-seed? [random-seed usrSeed * 7 + 66]
  set food-plan (num-of-snacks-to-start * snack-size)
  run setup-type
  map-cost
  add-snacks
  add-pigs
  reset-ticks
  set model-time 0
  set front 0
  set food-facto (sum [snack-food-left] of snacks)
  set snacks-num-start count snacks
  ;set each-pig-visits []
  set ratio num-of-snacks-to-start / (count pigs)
  if reset-random-seed2? [random-seed new-seed]
  create-csv-lists
end


;;██████ setup procedures ██████

to Haifa
  ;;load datasets with names from user input boxes
  let dataset2 gis:load-dataset data_File
  ;let dataset2 gis:load-dataset "cost_m1000x1000.asc"
  ;let dataset2 gis:load-dataset "feed_m1000x500.asc"
  ;set world boundaries (envelope) as union of the datasets
  gis:set-world-envelope
  (
    gis:envelope-union-of (gis:envelope-of dataset2) ;(gis:envelope-of dataset1)
  )
  ;applies datasets as attributes of patches
  gis:apply-raster dataset2 cost
  ;gis:apply-raster dataset1 pahim
  ;let pahim-list []
  ;(
  ;  foreach (list
  ;  (patch 102 80) (patch 90 30) (patch 71 95) (patch 71 94)
  ;  (patch 194 99) (patch 195 99) (patch 196 99) (patch 197 99) (patch 198 99) (patch 199 99)
  ;  (patch 196 98) (patch 197 98) (patch 198 98) (patch 199 98)
  ;  (patch 198 97) (patch 199 97) (patch 199 96))
  ;  [
  ;    ask ?1
  ;    [
  ;      set cost 999999
  ;    ]
  ;  ]
  ;)
  ;ask patches with [pahim = 1]
  ;[
  ;  set pahim-list lput self pahim-list
  ;]
  ;show pahim-list
end



to map-cost
  let COSTtable table:make
  let cost-list [0 0.001 0.1 0.25 0.5 0.75 999999]
  ;let color-list [39.9 65 38 37 36 35 33]
  let color-list [9.9 66 8 7 5 3 0]
  (foreach cost-list color-list [ [?1 ?2] -> table:put COSTtable ?1 ?2 ] )
  ask patches
  [
    set pigvisits 0
    set pigforagevisits 0
    if cost = 0
    [
      set cost 999999
    ]
    if (cost <= 0.01)
    [
      set cost 0.001
      set pcolor lime
    ]
    ;;if cost is not a number than make it  999999
    ifelse cost <= 0 or cost >= 0
    [
      if cost >= 1 [set cost 999999]
      set pcolor table:get COSTtable cost
    ]
    [
      set cost 999999
      set pcolor 9.9
    ]
  ]
end


to add-snacks
  ifelse grid?
  [
    make-grid
  ]
  [
    ask patches-for-snacks
    [
      if not any? snacks-here
      [
        sprout-snacks 1
        [
          set color 45
          set shape "circle"
          set size 2 ;2.5
          if stamp_snacks [stamp]
          set shape "circle" ;"x"
          ;set color white
          ifelse rnd-snack-size
          [
            set snack-food-left random-poisson snack-size
          ]
          [
            set snack-food-left snack-size
          ]
          set color yellow
          ;set size ( 1 / zoomin ) + 1 * (snack-food-left / snack-size)
          set size ( 1 / zoomin ) ;+ 1 ;* (snack-food-left / snack-size)
          set dibs 0
          set snack-attractiveness 0
        ]
      ]
    ]
  ]
end

to-report patches-for-snacks
  ifelse rnd-setup-snacks
  [
    if not any? snacks with [cost = 0.5] [set snacks-urban? false]
    ifelse snacks-urban?
    [
      let numS num-of-snacks-to-start
      if num-of-snacks-to-start >= count patches with [cost = 0.5]
      [
        set numS count patches with [cost = 0.5]
      ]
      report (n-of numS patches with [cost = 0.5])
    ]
    [
      let numS num-of-snacks-to-start
      if num-of-snacks-to-start >= count patches with [cost <= 0.5 and cost >= 0.01]
      [
        set numS count patches with [cost <= 0.5 and cost >= 0.01]
      ]
      report (n-of numS patches with [cost <= 0.5 and cost >= 0.01])
    ]
  ]
  [
    ;let patch-list (list [213 460] [260 490] [329 433] [370 455] [318 310] [265 311])
    if pahim?
    [

      ;let patches-with-pahim (patch-set (patch 40 78) (patch 148 93) (patch 105 67) (patch 188 47) (patch 111 19) (patch 130 77) (patch 99 71) (patch 40 98) (patch 141 4) (patch 197 41) (patch 1 63) (patch 130 24) (patch 73 66) (patch 108 79) (patch 103 49) (patch 99 90) (patch 45 97) (patch 97 26) (patch 9 27) (patch 153 99) (patch 51 91) (patch 88 99) (patch 110 51) (patch 127 99) (patch 171 43) (patch 109 18) (patch 25 31) (patch 28 46) (patch 28 95) (patch 158 35) (patch 66 87) (patch 110 47) (patch 33 74) (patch 164 97) (patch 175 9) (patch 101 2) (patch 134 73) (patch 187 33) (patch 111 26) (patch 189 20) (patch 62 58) (patch 120 92) (patch 111 60) (patch 74 80) (patch 154 32) (patch 55 93) (patch 23 76) (patch 21 81) (patch 42 81) (patch 180 6) (patch 70 37) (patch 58 60) (patch 141 59) (patch 112 65) (patch 130 51) (patch 121 2) (patch 106 1) (patch 49 60) (patch 94 26) (patch 101 93) (patch 68 54) (patch 132 24) (patch 55 37) (patch 18 35) (patch 84 76) (patch 77 96) (patch 172 31) (patch 188 2) (patch 7 94) (patch 46 89) (patch 74 17) (patch 76 28) (patch 22 86) (patch 40 70) (patch 80 34) (patch 89 91) (patch 195 49) (patch 8 59) (patch 145 82) (patch 117 3) (patch 76 25) (patch 119 83) (patch 65 99) (patch 199 48) (patch 182 53) (patch 156 62) (patch 136 90) (patch 114 50) (patch 92 19) (patch 104 38) (patch 108 30) (patch 99 56) (patch 109 15) (patch 109 43) (patch 84 55) (patch 67 16) (patch 114 96) (patch 17 97) (patch 159 99) (patch 69 65) (patch 24 46) (patch 30 76) (patch 116 74) (patch 20 78) (patch 135 62) (patch 129 88) (patch 40 32) (patch 153 84) (patch 129 74) (patch 111 75) (patch 51 72) (patch 102 6) (patch 168 41) (patch 164 34) (patch 83 13) (patch 52 45) (patch 89 99) (patch 107 6) (patch 155 29) (patch 143 65) (patch 58 88) (patch 47 84) (patch 72 40) (patch 32 49) (patch 117 95) (patch 75 51) (patch 164 10) (patch 80 91) (patch 101 32) (patch 55 62) (patch 41 41) (patch 64 22) (patch 69 31) (patch 156 5) (patch 96 1) (patch 0 38) (patch 33 98) (patch 70 78) (patch 131 40) (patch 51 28) (patch 96 41) (patch 133 6) (patch 185 99) (patch 115 85) (patch 87 78) (patch 119 60) (patch 73 23) (patch 38 40) (patch 105 91) (patch 155 77) (patch 62 70) (patch 166 38) (patch 133 87) (patch 70 7) (patch 72 98) (patch 103 19) (patch 31 43) (patch 5 50) (patch 118 98) (patch 168 95) (patch 23 82) (patch 106 37) (patch 112 29) (patch 89 10) (patch 107 99) (patch 1 45) (patch 66 80) (patch 155 91) (patch 61 19) (patch 176 83) (patch 59 52) (patch 115 42) (patch 0 24) (patch 3 33) (patch 199 69) (patch 10 49) (patch 127 79) (patch 56 84) (patch 87 45) (patch 50 74) (patch 168 80) (patch 106 53) (patch 41 62) (patch 82 72) (patch 12 56) (patch 125 91) (patch 172 92) (patch 131 98) (patch 42 88) (patch 141 90) (patch 60 76) (patch 96 31) (patch 43 68) (patch 10 39) (patch 35 69) (patch 156 1) (patch 118 46) (patch 56 24) (patch 133 56) (patch 150 41) (patch 97 84) (patch 92 74) (patch 55 55) (patch 199 45) (patch 155 21) (patch 79 34) (patch 111 87) (patch 27 80) (patch 87 4) (patch 37 72) (patch 138 67) (patch 6 37) (patch 153 8) (patch 78 82) (patch 2 53) (patch 109 66) (patch 4 25) (patch 157 82) (patch 171 79) (patch 107 27) (patch 43 31) (patch 31 69) (patch 163 81) (patch 14 29) (patch 149 28) (patch 64 17) (patch 39 44) (patch 96 34) (patch 30 90) (patch 194 61) (patch 61 91) (patch 35 85) (patch 46 27) (patch 153 45) (patch 126 57) (patch 75 8) (patch 47 66) (patch 25 52) (patch 163 2) (patch 187 81) (patch 113 34) (patch 35 43) (patch 138 9) (patch 118 17) (patch 43 44) (patch 151 70) (patch 120 94) (patch 177 75) (patch 172 36) (patch 182 18) (patch 72 29) (patch 52 56) (patch 120 72) (patch 33 89) (patch 164 86) (patch 144 18) (patch 55 79) (patch 133 99) (patch 79 5) (patch 88 61) (patch 102 14) (patch 111 35) (patch 138 97) (patch 39 83) (patch 77 2) (patch 196 21) (patch 166 53) (patch 13 47) (patch 53 75) (patch 27 73) (patch 141 83) (patch 160 46) (patch 197 65) (patch 26 42) (patch 93 68) (patch 83 90) (patch 45 61) (patch 169 84) (patch 93 87) (patch 82 96) (patch 59 24) (patch 93 9) (patch 22 38) (patch 33 28) (patch 92 54) (patch 161 16) (patch 124 30) (patch 64 33) (patch 91 1) (patch 158 52) (patch 70 74) (patch 97 51) (patch 122 54) (patch 182 97) (patch 123 81) (patch 86 93) (patch 14 41) (patch 84 47) (patch 31 34) (patch 14 92) (patch 16 93) (patch 81 13) (patch 146 86) (patch 47 44) (patch 81 66) (patch 80 49) (patch 96 67) (patch 122 70) (patch 146 36) (patch 97 4) (patch 16 55) (patch 130 29) (patch 179 93) (patch 155 49) (patch 145 94) (patch 70 85) (patch 122 22) (patch 60 35) (patch 135 49) (patch 33 47) (patch 45 30) (patch 163 30) (patch 160 86) (patch 182 82) (patch 127 35) (patch 101 7) (patch 47 93) (patch 88 37) (patch 187 90) (patch 48 20) (patch 42 98) (patch 103 68) (patch 106 63) (patch 85 23) (patch 69 70) (patch 199 84) (patch 1 40) (patch 91 43) (patch 93 59) (patch 194 86) (patch 121 27) (patch 193 79) (patch 67 62) (patch 84 19) (patch 162 13) (patch 36 33) (patch 157 18) (patch 70 15) (patch 44 85) (patch 38 90) (patch 149 10) (patch 149 15) (patch 21 52) (patch 184 4) (patch 77 15) (patch 171 12) (patch 180 30) (patch 127 58) (patch 65 56) (patch 31 33) (patch 38 26) (patch 118 61) (patch 80 7) (patch 191 75) (patch 0 33) (patch 77 58) (patch 51 64) (patch 20 32) (patch 185 76) (patch 107 98) (patch 97 17) (patch 132 70) (patch 46 40) (patch 4 61) (patch 130 18) (patch 95 68) (patch 24 31) (patch 199 57) (patch 102 84) )
      let patches-with-pahim (patch-set (patch 40 78) (patch 148 93) (patch 105 67) (patch 188 47) (patch 111 19) (patch 130 77) (patch 99 71) (patch 40 98) (patch 141 4) (patch 197 41)               (patch 130 24) (patch 73 66) (patch 108 79) (patch 103 49) (patch 99 90) (patch 45 97) (patch 97 26) (patch 9 27) (patch 153 99) (patch 51 91) (patch 88 99) (patch 110 51) (patch 127 99) (patch 171 43) (patch 109 18) (patch 25 31) (patch 28 46) (patch 28 95) (patch 158 35) (patch 66 87) (patch 110 47) (patch 33 74) (patch 164 97) (patch 175 9) (patch 101 2) (patch 134 73) (patch 187 33) (patch 111 26) (patch 189 20) (patch 62 58) (patch 120 92) (patch 111 60) (patch 74 80) (patch 154 32) (patch 55 93) (patch 23 76) (patch 21 81) (patch 42 81) (patch 180 6) (patch 70 37) (patch 58 60) (patch 141 59) (patch 112 65) (patch 130 51) (patch 121 2) (patch 106 1) (patch 49 60) (patch 94 26) (patch 101 93) (patch 68 54) (patch 132 24) (patch 55 37) (patch 18 35) (patch 84 76) (patch 77 96) (patch 172 31) (patch 188 2) (patch 7 94) (patch 46 89) (patch 74 17) (patch 76 28) (patch 22 86) (patch 40 70) (patch 80 34) (patch 89 91) (patch 195 49) (patch 8 59) (patch 145 82) (patch 117 3) (patch 76 25) (patch 119 83) (patch 65 99) (patch 199 48) (patch 182 53) (patch 156 62) (patch 136 90) (patch 114 50) (patch 92 19) (patch 104 38) (patch 108 30) (patch 99 56) (patch 109 15) (patch 109 43) (patch 84 55) (patch 67 16) (patch 114 96) (patch 17 97) (patch 159 99) (patch 69 65) (patch 24 46) (patch 30 76) (patch 116 74) (patch 20 78) (patch 135 62) (patch 129 88) (patch 40 32) (patch 153 84) (patch 129 74) (patch 111 75) (patch 51 72) (patch 102 6) (patch 168 41) (patch 164 34) (patch 83 13) (patch 52 45) (patch 89 99) (patch 107 6) (patch 155 29) (patch 143 65) (patch 58 88) (patch 47 84) (patch 72 40) (patch 32 49) (patch 117 95) (patch 75 51) (patch 164 10) (patch 80 91) (patch 101 32) (patch 55 62) (patch 41 41) (patch 64 22) (patch 69 31) (patch 156 5) (patch 96 1)              (patch 33 98) (patch 70 78) (patch 131 40) (patch 51 28) (patch 96 41) (patch 133 6) (patch 185 99) (patch 115 85) (patch 87 78) (patch 119 60) (patch 73 23) (patch 38 40) (patch 105 91) (patch 155 77) (patch 62 70) (patch 166 38) (patch 133 87) (patch 70 7) (patch 72 98) (patch 103 19) (patch 31 43) (patch 5 50) (patch 118 98) (patch 168 95) (patch 23 82) (patch 106 37) (patch 112 29) (patch 89 10) (patch 107 99)              (patch 66 80) (patch 155 91) (patch 61 19) (patch 176 83) (patch 59 52) (patch 115 42)              (patch 3 33) (patch 199 69) (patch 10 49) (patch 127 79) (patch 56 84) (patch 87 45) (patch 50 74) (patch 168 80) (patch 106 53) (patch 41 62) (patch 82 72) (patch 12 56) (patch 125 91) (patch 172 92) (patch 131 98) (patch 42 88) (patch 141 90) (patch 60 76) (patch 96 31) (patch 43 68) (patch 10 39) (patch 35 69) (patch 156 1) (patch 118 46) (patch 56 24) (patch 133 56) (patch 150 41) (patch 97 84) (patch 92 74) (patch 55 55) (patch 199 45) (patch 155 21) (patch 79 34) (patch 111 87) (patch 27 80) (patch 87 4) (patch 37 72) (patch 138 67) (patch 6 37) (patch 153 8) (patch 78 82) (patch 2 53) (patch 109 66) (patch 4 25) (patch 157 82) (patch 171 79) (patch 107 27) (patch 43 31) (patch 31 69) (patch 163 81) (patch 14 29) (patch 149 28) (patch 64 17) (patch 39 44) (patch 96 34) (patch 30 90) (patch 194 61) (patch 61 91) (patch 35 85) (patch 46 27) (patch 153 45) (patch 126 57) (patch 75 8) (patch 47 66) (patch 25 52) (patch 163 2) (patch 187 81) (patch 113 34) (patch 35 43) (patch 138 9) (patch 118 17) (patch 43 44) (patch 151 70) (patch 120 94) (patch 177 75) (patch 172 36) (patch 182 18) (patch 72 29) (patch 52 56) (patch 120 72) (patch 33 89) (patch 164 86) (patch 144 18) (patch 55 79) (patch 133 99) (patch 79 5) (patch 88 61) (patch 102 14) (patch 111 35) (patch 138 97) (patch 39 83) (patch 77 2) (patch 196 21) (patch 166 53) (patch 13 47) (patch 53 75) (patch 27 73) (patch 141 83) (patch 160 46) (patch 197 65) (patch 26 42) (patch 93 68) (patch 83 90) (patch 45 61) (patch 169 84) (patch 93 87) (patch 82 96) (patch 59 24) (patch 93 9) (patch 22 38) (patch 33 28) (patch 92 54) (patch 161 16) (patch 124 30) (patch 64 33) (patch 91 1) (patch 158 52) (patch 70 74) (patch 97 51) (patch 122 54) (patch 182 97) (patch 123 81) (patch 86 93) (patch 14 41) (patch 84 47) (patch 31 34) (patch 14 92) (patch 16 93) (patch 81 13) (patch 146 86) (patch 47 44) (patch 81 66) (patch 80 49) (patch 96 67) (patch 122 70) (patch 146 36) (patch 97 4) (patch 16 55) (patch 130 29) (patch 179 93) (patch 155 49) (patch 145 94) (patch 70 85) (patch 122 22) (patch 60 35) (patch 135 49) (patch 33 47) (patch 45 30) (patch 163 30) (patch 160 86) (patch 182 82) (patch 127 35) (patch 101 7) (patch 47 93) (patch 88 37) (patch 187 90) (patch 48 20) (patch 42 98) (patch 103 68) (patch 106 63) (patch 85 23) (patch 69 70) (patch 199 84)              (patch 91 43) (patch 93 59) (patch 194 86) (patch 121 27) (patch 193 79) (patch 67 62) (patch 84 19) (patch 162 13) (patch 36 33) (patch 157 18) (patch 70 15) (patch 44 85) (patch 38 90) (patch 149 10) (patch 149 15) (patch 21 52) (patch 184 4) (patch 77 15) (patch 171 12) (patch 180 30) (patch 127 58) (patch 65 56) (patch 31 33) (patch 38 26) (patch 118 61) (patch 80 7) (patch 191 75)              (patch 77 58) (patch 51 64) (patch 20 32) (patch 185 76) (patch 107 98) (patch 97 17) (patch 132 70) (patch 46 40) (patch 4 61) (patch 130 18) (patch 95 68) (patch 24 31) (patch 199 57) (patch 102 84) )
      ;let patches-up50 ( patch-set nobody )
      ;show patches-up50
      ;foreach patches-with-pahim
      ;[
      ;  let py-up50 pycor + 50
      ;  let pxxx pxcor
      ;  lput patches-up50 patch pxcor py-up50
      ;]
      ;show patches-up50
      report patches-with-pahim
    ]
    let patch-list (list [200 66])
    report patches at-points patch-list
  ]
end

to make-grid
  let spacing grid-modul
  let min-xpos floor (min-pxcor + 0.5 * spacing)
  let min-ypos floor (min-pycor + 0.5 * spacing)
  ;;sprout snack-maker in the BL corner
  ;ask patch min-xpos min-ypos
  ask patch max-pxcor min-ypos
  [
    sprout-snacks 1
    [
      set shape "x"
      set color black
      ;set size ( 1 / zoomin )+ 1 * (snack-food-left / snack-size)
      set size ( 1 / zoomin ) + 1 ;* (snack-food-left / snack-size)
      set snack-food-left snack-size
      set dibs 0
    ]
  ]
  ;;calc how many row and cols the box can hold
  let box-width world-width ;- os-width
  let box-height  world-height
  let num-cols ceiling box-width / spacing + 1
  let num-rows ceiling box-height / spacing + 1
  ;;ask snack-maker to jump the grid hatching
  ask snack 0
  [
    repeat num-rows
    [
      repeat num-cols
      [
        hatch 1
        set heading 270
        jump spacing
      ]
      ;setxy min-xpos ycor
      setxy max-pxcor ycor
      set heading 0
      jump spacing
    ]
    die
  ]
  ;; kill snacks that are on buildings or roads or open space
  ask snacks with
  [ [cost] of patch-here > 0.5  or  [cost] of patch-here <= 0.01 ]
  [
    die
  ]
  leave-a-stamp
end


to leave-a-stamp
  ask snacks
  [
    let sz size
    let sh shape
    set shape "circle"
    set size 1.5
    if stamp_snacks [stamp]
    set shape sh
    set size sz
  ]
end

to make-a-start-sign
  sprout 1 [
    set shape "x"
    set color white
    set size 2
    if stamp_snacks [stamp]
    die
  ]
end

to add-pigs
  ask patches-for-pigs
  [
    make-a-start-sign
    sprout-pigs num-pigs-at-start-points
    [
      set size 3 / zoomin + 1
      set shape "pigface"
      ;set color pink
      set heading 0
      ;stamp
      set color magenta
      set pig-state "foraging"
      set pig-satiety 0
      set pig-energy 0
      pd
      set label pig-state
      set label-color black
      set pig-home patch-here
      set pig-time-feeding 0
      set pig-penetration 0
      set pig-depth 0
      set pig-snacks-eaten 0
      set pig-current-sally []
      set pig-sallies []
      setup-pig-count-patch-types
      set Lpig-ptypes2 n-values length Lcosts [0]
      set pig-patches-visited 0
      set pig-max-xcor-ever xcor
      set pig-opt-path-cost 999999
      reset-target-and-path
      setup-waiting
    ]
  ]
end

to setup-pig-count-patch-types
  set Tpig-ptypes table:make
  set Lcosts [0.001 0.1 0.25 0.5 0.75 999999]
  let Lp-list n-values 6 [0]
  (foreach Lcosts Lp-list [ [?1 ?2] -> table:put Tpig-ptypes ?1 ?2 ] )
end



to-report patches-for-pigs
  ifelse rnd-setup-pigs
  [
    ;report (n-of pig-start-points patches with [ cost <= 0.001 and pxcor = 0 ] )
    report (n-of pig-start-points patches with [ cost <= 0.001 and pxcor <= 3 ] )
  ]
  [
    ;let patch-list (list [0 130])
    let patch-list (list [0 70])
    report patches at-points patch-list
  ]
end







;;██████ setup tests ████████████████████████████████████████████████████████████

to scenario1
  ;;backyards
  ask patches [set cost 0.5]
  ;;roads
  let road-width 2
  ask patches with [(pycor mod 22) < 22 and (pycor mod 22) > 22 - road-width - 1] [set cost 0.75]
  ask patches with [(pxcor mod 16) < 16 and (pxcor mod 16) > 16 - road-width - 1] [set cost 0.75]
  ;;houses
  let house-ycor n-values 20 [ ?1 -> ?1 ]
  set house-ycor filter [ ?1 -> (?1 mod 4) >= 1 and (?1 mod 4) < 1 + 2 ] house-ycor
  let house-xcor n-values 14 [ ?1 -> ?1 ]
  set house-xcor filter [ ?1 -> (?1 mod 8) >= 1 and (?1 mod 8) < 1 + 4 ] house-xcor
  let wx n-values (int (max-pxcor / 16)) [ ?1 -> ?1 ]
  let hy n-values (int (max-pycor / 22)) [ ?1 -> ?1 ]
  foreach wx
  [ ?1 ->
    let w ?1
    foreach hy
    [ ??1 ->
      let hh ??1
      foreach house-xcor
      [ ???1 ->
        let x ???1 + w * 16
        foreach house-ycor
        [ ????1 ->
          let y ????1 + hh * 22
          ask patch x y [set cost 999999]
        ]
      ]
    ]
  ]
  ;;open spaces
  ask patches with [pxcor < os-width] [set cost 0.01]
end



to scenario3
  ;set os-width 75
  let road-width 2
  let house-x-size 4
  let house-y-size 2
  let kav-binyan-front 1
  let kav-binyan-back 2
  let kav-binyan-side 1
  let parcel-x house-x-size + kav-binyan-front + kav-binyan-back
  let parcel-y house-y-size + kav-binyan-side * 2
  let houses-in-block-y 5
  let modul-x   parcel-x * 2 + road-width
  let modul-y   parcel-y * houses-in-block-y + road-width
   ;show (word "modul-x=" modul-x " modul-y=" modul-y)
  ;;backyards
  ask patches with [pxcor > os-width] [set cost 0.5]
  let blocks-x n-values modul-x [ ?1 -> ?1 ]
  let blocks-y n-values modul-y [ ?1 -> ?1 ]
  ;;houses
  let house-x filter [ ?1 ->
    (?1 > kav-binyan-front - 1  and ?1 < kav-binyan-front + house-x-size )
    or
    (?1 > kav-binyan-back + parcel-x - 1  and ?1 < kav-binyan-back + house-x-size + parcel-x)
  ] blocks-x
  let house-y filter [ ?1 ->
    ( (?1 mod houses-in-block-y >= road-width + kav-binyan-side) and (?1 mod houses-in-block-y <= road-width + kav-binyan-side + house-y-size) )
  ] blocks-y
    ;show (word "house-x=" house-x " house-y=" house-y)
  let wx n-values (ceiling (max-pxcor / modul-x)) [ ?1 -> ?1 ]
  let hy n-values (ceiling (max-pycor / modul-y)) [ ?1 -> ?1 ]
  let list-of-xx []
  foreach wx [ ?1 ->
    let w ?1
    foreach house-x [ ??1 ->
      let x ??1 + w * modul-x + os-width
      if x <= max-pxcor [
        set list-of-xx lput x list-of-xx
      ]
    ]
  ]
 ;show list-of-xx
  let list-of-yy []
  foreach hy [ ?1 ->
    let hh ?1
    foreach house-y [ ??1 ->
      let y ??1 + hh * modul-y
      if y <= max-pycor [
        set list-of-yy lput y list-of-yy
      ]
    ]
  ]
 ;show list-of-yy
  foreach list-of-xx [ ?1 ->
    let x ?1
    foreach list-of-yy [ ??1 ->
      let y ??1
      ask patch x y [set cost 999999]
    ]
  ]
  ;;roads
  ;ask patches with [(pycor mod modul-y + 1) < modul-y and (pycor mod modul-y) > modul-y - road-width - 1] [set cost 0.75]
  ask patches with [
    (pxcor + os-width) mod modul-x > modul-x - parcel-x  - road-width
    and
    (pxcor + os-width) mod modul-x <= modul-x - parcel-x
    and
    pxcor <= max-pxcor
  ] [set cost 0.75]
  ask patches with [
    pycor mod modul-y > parcel-y * houses-in-block-y
    or
    pycor mod modul-y = 0
  ] [set cost 0.75]
  ;;to delete !!!!
  ask patches with [pxcor <= os-width] [set cost 0.5]
  ;;open spaces
  ask patches with [pxcor < os-width] [set cost 0.001]
end



to scenario2
  ;set os-width 75
  let road-width 2
  let house-x-size 4
  let house-y-size 2
  let kav-binyan-front 1
  let kav-binyan-back 2
  let kav-binyan-side 1
  let parcel-x house-x-size + kav-binyan-front + kav-binyan-back
  let parcel-y house-y-size + kav-binyan-side * 2
  let houses-in-block-y 5
  let modul-x   parcel-x * 2 + road-width
  let modul-y   parcel-y * houses-in-block-y + road-width
   ;show (word "modul-x=" modul-x " modul-y=" modul-y)
  ;;backyards
  ask patches with [pxcor > os-width] [set cost 0.5]
  let blocks-x n-values modul-x [ ?1 -> ?1 ]
  let blocks-y n-values modul-y [ ?1 -> ?1 ]
  ;;houses
  let house-x filter [ ?1 ->
    (?1 > kav-binyan-front - 1  and ?1 < kav-binyan-front + house-x-size )
    or
    (?1 > kav-binyan-back + parcel-x - 1  and ?1 < kav-binyan-back + house-x-size + parcel-x)
  ] blocks-x
  let house-y filter [ ?1 ->
    ( (?1 mod houses-in-block-y >= road-width + kav-binyan-side) and (?1 mod houses-in-block-y <= road-width + kav-binyan-side + house-y-size) )
  ] blocks-y
    ;show (word "house-x=" house-x " house-y=" house-y)
  let wx n-values (ceiling (max-pxcor / modul-x)) [ ?1 -> ?1 ]
  let hy n-values (ceiling (max-pycor / modul-y)) [ ?1 -> ?1 ]
  let list-of-xx []
  foreach wx [ ?1 ->
    let w ?1
    foreach house-x [ ??1 ->
      let x ??1 + w * modul-x + os-width
      if x <= max-pxcor [
        set list-of-xx lput x list-of-xx
      ]
    ]
  ]
 ;show list-of-xx
  let list-of-yy []
  foreach hy [ ?1 ->
    let hh ?1
    foreach house-y [ ??1 ->
      let y ??1 + hh * modul-y
      if y <= max-pycor [
        set list-of-yy lput y list-of-yy
      ]
    ]
  ]
 ;show list-of-yy
  foreach list-of-xx [ ?1 ->
    let x ?1
    foreach list-of-yy [ ??1 ->
      let y ??1
      ask patch x y [set cost 999999]
    ]
  ]
  ;;roads
  ;ask patches with [(pycor mod modul-y + 1) < modul-y and (pycor mod modul-y) > modul-y - road-width - 1] [set cost 0.75]
  ask patches with [
    (pxcor + os-width) mod modul-x > modul-x - parcel-x  - road-width
    and
    (pxcor + os-width) mod modul-x <= modul-x - parcel-x
    and
    pxcor <= max-pxcor
  ] [set cost 0.75]
  ask patches with [
    pycor mod modul-y > parcel-y * houses-in-block-y
    or
    pycor mod modul-y = 0
  ] [set cost 0.75]
  ;;to delete !!!!
  ask patches with [pxcor <= os-width] [set cost 0.5]

  ;;open spaces
  ask patches with [pycor > max-pycor / 2 ] [set cost 999999]

  ;;open spaces
  ask patches with [pxcor < os-width] [set cost 0.001]
end










to Uniform05
  ;set os-width 20
  ;;backyards
  ask patches ;with [pxcor > os-width]
  [
    set cost 0.5
  ]
  ;;open spaces
  ask patches with [pxcor <= os-width] [set cost 0.001]
end

to Uniform025
  ;set os-width 20
  ;;backyards
  ask patches ;with [pxcor > os-width]
  [
    set cost 0.25
  ]
  ;;open spaces
  ask patches with [pxcor <= os-width] [set cost 0.001]
end

;;██████ data analysis ████████████████████████████████████████████████████████████


to create-csv-lists
  set each-pig-sallies []
  set each-pig-sallies  fput (list "setup-type" "snacks" "pigs" "ratio" "pahim?" "run" "gamma" "pig" "sally" "length" "patches-visited") each-pig-sallies
  set each-pig-route-lengths []
  set each-pig-route-lengths fput (list "setup-type" "snacks" "pigs" "p-min" "snack-size" "pahim?" "ratio" "run" "gamma" "pig" "route-L" "easting" "pig-patches-visited" "expenditure" "satiety" "snacks-eaten" "pig-max-xcor-ever" "c0.001" "c0.1" "c0.25" "c0.5" "c0.75" "c999999" "TOT") each-pig-route-lengths
  ;set each-pig-visits []
  ;set each-pig-visits fput (list "setup-type" "num-of-snacks-to-start" "num-pigs-at-start-points" "ratio" "behaviorspace-run-number" "pig" "c0.001" "c0.1" "c0.25" "c0.5" "c0.75" "c999999" "TOT") each-pig-visits

end

to export-data-to-list
  foreach sort-on [who] pigs
  [ ?1 ->
    ask ?1
    [
      let l-temp 0
      foreach pig-sallies
      [ ??1 ->
        set l-temp l-temp + length ??1
        set each-pig-sallies lput (list setup-type num-of-snacks-to-start num-pigs-at-start-points (num-of-snacks-to-start / (count pigs)) pahim? behaviorspace-run-number gamma who (position ??1 pig-sallies)  (length ??1) pig-patches-visited ) each-pig-sallies
      ]
      set each-pig-route-lengths lput (list setup-type num-of-snacks-to-start num-pigs-at-start-points p-min snack-size pahim? (num-of-snacks-to-start / (count pigs)) behaviorspace-run-number gamma who l-temp xcor pig-patches-visited (0 - pig-energy) pig-satiety pig-snacks-eaten pig-max-xcor-ever (item 0 Lpig-ptypes2) (item 1 Lpig-ptypes2) (item 2 Lpig-ptypes2) (item 3 Lpig-ptypes2) (item 4 Lpig-ptypes2) (item 5 Lpig-ptypes2) pig-patches-visited) each-pig-route-lengths
      ;set each-pig-visits lput (list setup-type num-of-snacks-to-start num-pigs-at-start-points (num-of-snacks-to-start / (count pigs)) behaviorspace-run-number who (item 0 Lpig-ptypes2) (item 1 Lpig-ptypes2) (item 2 Lpig-ptypes2) (item 3 Lpig-ptypes2) (item 4 Lpig-ptypes2) (item 5 Lpig-ptypes2) pig-patches-visited) each-pig-visits
      ;show each-pig-route-lengths
    ]
  ]
end

to graph-validtn
  file-open (word "validtn" "-" behaviorspace-run-number ".csv")
  ;;;-------------SHAPKA-----------
  file-type "\n"
  file-type "SPB ratio,"
  file-type (num-of-snacks-to-start / (count pigs))
  file-type "\n"
  file-type (word "pig-start-points," pig-start-points "," "\n" "num-pigs-at-start-points," num-pigs-at-start-points "," "\n" "num-of-snacks-to-start," num-of-snacks-to-start "," "\n" "rnd-setup-pigs," rnd-setup-pigs ",")
  file-type "\n"
  file-type (word "pxcor" "," "pigvisits" "," "pigforagevisits" ",")
  file-type "\n"
  ;;;-------------BODY-------------
  let ii 0
  while [ii <= max-pxcor] [
    let jj (sum [pigvisits] of patches with [pxcor = ii])
    let kk (sum [pigforagevisits] of patches with [pxcor = ii])
    file-type (word ii "," jj "," kk)
    file-type "\n"
    set ii ii + 1
  ]
  ;;;-------------ENDING-----------
  file-close

  let bottom 0
  let top 0
end

to prepare-csv
  ;;
  ;; patches-pigvisits  ;;
  file-open (word "patches-pigvisits"  "-" behaviorspace-run-number ".csv")
  file-type "\n"
  file-type "SPB ratio,"
  file-type (num-of-snacks-to-start / (count pigs))
  file-type "\n"
  file-type (word "pig-start-points," pig-start-points "," "\n" "num-pigs-at-start-points," num-pigs-at-start-points "," "\n" "num-of-snacks-to-start," num-of-snacks-to-start "," "\n" "rnd-setup-pigs," rnd-setup-pigs ",")
  file-type "\n"
  file-type (word "pxcor" "," "pycor" "," "pigvisits" "," "pigforagevisits" "," "behaviorspace-run-number" ",")
  file-type "\n"
  file-close
end


;;;;██████ write-csv ████████████ write-csv █████████████ write-csv ███████████ write-csv ███████████
to write-csv
  prepare-csv
  export-data-to-list
  ;;;______________________________________________*******
  ;file-open (word "patches-pigvisits" ".csv")
  file-open (word "patches-pigvisits"  "-" behaviorspace-run-number ".csv")
  foreach sort patches [ ?1 ->
    ask ?1 [
      file-type (word pxcor "," pycor "," pigvisits "," pigforagevisits "," behaviorspace-run-number ",")
      ;if pxcor = max-pxcor [ file-type "\n" ]
      file-type "\n"
    ]
  ]
  file-close
  ;;;____________________________****
  if Write_pig-route-lengths
  [
    ;;
    file-open (word "each-pig-route-lengths" ".csv")
    foreach each-pig-route-lengths
    [ ?1 ->
      foreach ?1
      [ ??1 ->
        file-type ??1
        file-type ","
      ]
      file-print ""
    ]
    file-close
  ]
  ;;;____________________________****
  if Write_pig-sallies
  [
    file-open (word "each-pig-sallies" ".csv")
    foreach each-pig-sallies
    [ ?1 ->
      foreach ?1
      [ ??1 ->
        file-type ??1
        file-type ","
      ]
      file-print ""
    ]
    file-close
  ]
  ;;;______________________________________________
  ;;
  if Write_list-of-pig-x-run
  [
    ;
    file-open (word "list-of-pig-x-run" ".csv")
    file-type "\n"
    file-type (num-of-snacks-to-start / (count pigs))
    file-type ","
    foreach list-of-pig-x [ ?1 ->
      file-type ?1
      file-type ","
    ]
    file-close
  ]
  ;;;______________________________________________*******
  if Write_patches-pigvisits-matrx
  [
    ;
    file-open (word "patches-pigvisits-matrx" "-" behaviorspace-run-number ".csv")
    file-type (word "pigvisits" "\n")
    file-type (word "behaviorspace-run-number," behaviorspace-run-number "," "\n")
    file-type "BPS ratio,"
    file-type (num-of-snacks-to-start / (count pigs))
    file-type "\n"
    file-type (word "pig-start-points," pig-start-points "," "\n" "num-pigs-at-start-points," num-pigs-at-start-points "," "\n" "num-of-snacks-to-start," num-of-snacks-to-start "," "\n" "rnd-setup-pigs," rnd-setup-pigs "," "\n")
    file-type "\n"
    file-type (word "," "pxcor" ",")
    let ii 0
    while [ii <= max-pxcor] [
      file-type (word ii ",")
      set ii ii + 1
    ]
    file-type "\n"
    file-type (word "pycor" "," "\n")
    foreach sort patches [ ?1 ->
      ask ?1 [
        if pxcor = min-pxcor [file-type (word pycor "," ",")]
        file-type (word pigvisits ",")
        if pxcor = max-pxcor [ file-type "\n" ]
      ]
    ]
    file-close
    ;;;_______________________
    file-open (word "patches-pigvisits-forage-matrx" "-" behaviorspace-run-number ".csv")
    file-type (word "pigforagevisits" "\n")
     file-type (word "behaviorspace-run-number," behaviorspace-run-number "," "\n")
    file-type "SPB ratio,"
    file-type (num-of-snacks-to-start / (count pigs))
    file-type "\n"
    file-type (word "pig-start-points," pig-start-points "," "\n" "num-pigs-at-start-points," num-pigs-at-start-points "," "\n" "num-of-snacks-to-start," num-of-snacks-to-start "," "\n" "rnd-setup-pigs," rnd-setup-pigs "," "\n")
    file-type "\n"
    file-type "\n"
    file-type (word "," "pxcor" ",")
    set ii 0
    while [ii <= max-pxcor] [
      file-type (word ii ",")
      set ii ii + 1
    ]
    file-type "\n"
    file-type (word "pycor" "," "\n")
    foreach sort patches [ ?1 ->
      ask ?1 [
        if pxcor = min-pxcor [file-type (word pycor "," ",")]
        file-type (word pigforagevisits ",")
        if pxcor = max-pxcor [ file-type "\n" ]
      ]
    ]
    file-close
  ]
end


to-report pig-ptypes-visits-mean                         ;;pig-ptypes-stats
  let Lptypes-visits-mean n-values (length Lcosts) [0]
  foreach sort-on [who] pigs
  [ ?1 ->
    ask ?1
    [
      ;let Lpcosts table:keys Tpig-ptypes
      let Lptypes-visits []
      let Lmean-temp Lptypes-visits-mean
      foreach Lcosts
      [ ??1 ->
        set Lptypes-visits lput table:get Tpig-ptypes ??1 Lptypes-visits
      ]
      ;show Lptypes-visits
      set Lptypes-visits-mean (map [ [??1 ??2] -> ??1 + ??2 ] Lptypes-visits Lmean-temp)
    ]
  ]
  set Lptypes-visits-mean map [ ?1 -> ?1 / count pigs ] Lptypes-visits-mean
  report Lptypes-visits-mean
end


to record-snacks
  if setup-type = "Haifa"
  [

    set snack-patch-list-h []
    ask patches with [any? snacks-here]
    [
      set snack-patch-list-h fput self snack-patch-list-h
    ]
  ]
end



to recreate_snacks
  let patches-for-old-snacks
  (patch-set
    ;(patch 164 92) (patch 59 36) (patch 131 63) (patch 187 28) (patch 79 60) (patch 64 39) (patch 1 46) (patch 154 38) (patch 58 74) (patch 40 63) (patch 167 21) (patch 72 98) (patch 3 34) (patch 42 1) (patch 36 84) (patch 107 80) (patch 22 41) (patch 134 24) (patch 104 54) (patch 67 11) (patch 93 80) (patch 81 22) (patch 85 6) (patch 115 52) (patch 129 94) (patch 169 81) (patch 118 82) (patch 156 18) (patch 39 35) (patch 111 72) (patch 21 79) (patch 157 4) (patch 162 53) (patch 104 42) (patch 183 4) (patch 140 56) (patch 119 95) (patch 70 69) (patch 25 40) (patch 106 31) (patch 12 48) (patch 184 31) (patch 77 45) (patch 92 2) (patch 152 34) (patch 77 7) (patch 29 86) (patch 32 65) (patch 139 91) (patch 178 30) (patch 161 40) (patch 165 19) (patch 109 59) (patch 179 21) (patch 24 83) (patch 52 38) (patch 105 41) (patch 126 34) (patch 125 63) (patch 77 21) (patch 136 2) (patch 35 38) (patch 122 26) (patch 83 42) (patch 177 92) (patch 161 44) (patch 31 88) (patch 92 79) (patch 42 48) (patch 65 64) (patch 159 16) (patch 90 99) (patch 146 28) (patch 147 53) (patch 120 68) (patch 62 40) (patch 11 35) (patch 28 24) (patch 168 32) (patch 22 45) (patch 108 99) (patch 4 1) (patch 176 38) (patch 92 35) (patch 127 56) (patch 93 89) (patch 36 27) (patch 68 43) (patch 12 29) (patch 199 96) (patch 153 0) (patch 69 31) (patch 135 25) (patch 49 65) (patch 156 39) (patch 182 86) (patch 135 93) (patch 15 4) (patch 64 57) (patch 65 43) (patch 176 10) (patch 43 59) (patch 181 35) (patch 143 76) (patch 135 50) (patch 143 71) (patch 50 33) (patch 189 80) (patch 92 19) (patch 159 37) (patch 124 63) (patch 83 23) (patch 40 52) (patch 64 44) (patch 63 42) (patch 151 20) (patch 29 83) (patch 134 16) (patch 105 31) (patch 148 66) (patch 96 73) (patch 52 35) (patch 108 46) (patch 80 27) (patch 149 53) (patch 107 99) (patch 80 52) (patch 62 44) (patch 117 17) (patch 154 7) (patch 152 38) (patch 106 16) (patch 40 41) (patch 176 96) (patch 2 1) (patch 61 48) (patch 64 87) (patch 96 26) (patch 95 88) (patch 189 94) (patch 139 41) (patch 137 90) (patch 140 77) (patch 65 40) (patch 199 12) (patch 33 74) (patch 33 98) (patch 9 31) (patch 152 12) (patch 70 41) (patch 134 49) (patch 35 44) (patch 128 35) (patch 162 89) (patch 64 6) (patch 97 5) (patch 37 68) (patch 112 40) (patch 99 0) (patch 89 50) (patch 58 48) (patch 6 40) (patch 104 4) (patch 94 83) (patch 49 96) (patch 120 76) (patch 148 40) (patch 40 3) (patch 19 54) (patch 165 10) (patch 124 17) (patch 57 71) (patch 33 82) (patch 158 88) (patch 132 98) (patch 134 56) (patch 66 34) (patch 188 93) (patch 27 35) (patch 128 62) (patch 72 65) (patch 72 18) (patch 136 48) (patch 27 47) (patch 192 80) (patch 61 44) (patch 197 66) (patch 76 60) (patch 75 76) (patch 139 79) (patch 107 40) (patch 93 60) (patch 104 6) (patch 157 15) (patch 54 30) (patch 127 71) (patch 148 49) (patch 95 56) (patch 79 14) (patch 131 9) (patch 73 8) (patch 79 45) (patch 35 71) (patch 105 83) (patch 130 89) (patch 94 58) (patch 139 76) (patch 151 75) (patch 95 49) (patch 21 80) (patch 115 75) (patch 99 19) (patch 68 28) (patch 3 38) (patch 64 74) (patch 70 74) (patch 85 71) (patch 60 43) (patch 136 50) (patch 163 99) (patch 42 60) (patch 28 72) (patch 92 58) (patch 180 7) (patch 60 28) (patch 38 83) (patch 188 30) (patch 38 51) (patch 66 21) (patch 37 51) (patch 185 79) (patch 110 19) (patch 183 5) (patch 65 65) (patch 157 66) (patch 23 26) (patch 14 24) (patch 149 33) (patch 105 98) (patch 92 22) (patch 177 14) (patch 165 22) (patch 23 78) (patch 62 78) (patch 162 42) (patch 119 1) (patch 160 83) (patch 64 12) (patch 70 26) (patch 0 63) (patch 144 73) (patch 165 59) (patch 40 93) (patch 112 18) (patch 153 46) (patch 149 19) (patch 168 80) (patch 163 96) (patch 107 74) (patch 174 48) (patch 183 21) (patch 140 61) (patch 26 96) (patch 39 37) (patch 68 98) (patch 43 31) (patch 14 92) (patch 170 76) (patch 179 26) (patch 188 84) (patch 108 16) (patch 83 5) (patch 63 28) (patch 126 91) (patch 177 80) (patch 151 99) (patch 94 40) (patch 171 36) (patch 154 92) (patch 188 38) (patch 12 53) (patch 152 27) (patch 160 86) (patch 78 48) (patch 88 27) (patch 191 77) (patch 33 42) (patch 54 39) (patch 156 29) (patch 136 0) (patch 114 42) (patch 186 3) (patch 3 25) (patch 155 85) (patch 25 73) (patch 4 43) (patch 72 1) (patch 28 49) (patch 41 47) (patch 168 22)
    (patch 99 84) (patch 182 95) (patch 110 77) (patch 49 68) (patch 82 76) (patch 181 99) (patch 85 79) (patch 180 31) (patch 113 39) (patch 125 23) (patch 138 4) (patch 101 55) (patch 165 5) (patch 109 84) (patch 27 77) (patch 97 86) (patch 184 19) (patch 176 15) (patch 12 39) (patch 128 84) (patch 8 33) (patch 150 78) (patch 112 32) (patch 152 0) (patch 29 23) (patch 175 48) (patch 177 50) (patch 129 69) (patch 189 21) (patch 103 1) (patch 120 88) (patch 55 83) (patch 116 93) (patch 171 24) (patch 94 78) (patch 160 89) (patch 27 68) (patch 174 1) (patch 147 71) (patch 40 44) (patch 111 47) (patch 150 26) (patch 81 93) (patch 44 79) (patch 60 71) (patch 164 82) (patch 193 85) (patch 174 97) (patch 121 92) (patch 187 47) (patch 27 88) (patch 130 60) (patch 196 37) (patch 66 75) (patch 24 76) (patch 96 41) (patch 129 15) (patch 53 60) (patch 180 42) (patch 25 52) (patch 138 45) (patch 104 26) (patch 191 1) (patch 104 48) (patch 87 55) (patch 32 68) (patch 95 79) (patch 147 90) (patch 146 45) (patch 68 23) (patch 114 76) (patch 46 29) (patch 49 52) (patch 19 38) (patch 12 25) (patch 10 21) (patch 176 88) (patch 131 66) (patch 195 79) (patch 184 87) (patch 70 61) (patch 1 59) (patch 145 67) (patch 186 29) (patch 164 36) (patch 2 23) (patch 82 2) (patch 96 19) (patch 191 20) (patch 15 46) (patch 46 76) (patch 178 96) (patch 188 81) (patch 73 71) (patch 50 59) (patch 83 3) (patch 171 18) (patch 151 35) (patch 63 42) (patch 6 58) (patch 73 67) (patch 91 22) (patch 148 29) (patch 74 65) (patch 122 92) (patch 42 67) (patch 176 46) (patch 30 47) (patch 158 81) (patch 95 96) (patch 63 97) (patch 105 81) (patch 95 3) (patch 155 40) (patch 13 83) (patch 146 15) (patch 172 79) (patch 149 30) (patch 17 84) (patch 186 69) (patch 18 91) (patch 105 37) (patch 106 72) (patch 182 92) (patch 167 79) (patch 199 19) (patch 170 30) (patch 145 96) (patch 16 46) (patch 1 24) (patch 11 52) (patch 66 16) (patch 45 67) (patch 93 95) (patch 15 83) (patch 57 16) (patch 133 46) (patch 37 95) (patch 6 51) (patch 32 94) (patch 179 87) (patch 44 85) (patch 103 16) (patch 187 84) (patch 165 21) (patch 118 20) (patch 23 32) (patch 174 0) (patch 158 21) (patch 65 71) (patch 155 1) (patch 148 77) (patch 185 86) (patch 68 41) (patch 113 87) (patch 35 21) (patch 130 15) (patch 64 28) (patch 113 65) (patch 41 49) (patch 103 43) (patch 117 3) (patch 97 32) (patch 86 4) (patch 83 93) (patch 38 52) (patch 30 96) (patch 186 90) (patch 41 92) (patch 36 69) (patch 79 10) (patch 71 26) (patch 70 23) (patch 134 98) (patch 189 32) (patch 63 80) (patch 108 32) (patch 52 50) (patch 46 40) (patch 163 53) (patch 157 63) (patch 87 82) (patch 125 92) (patch 168 20) (patch 72 14) (patch 128 30) (patch 184 5) (patch 28 79) (patch 179 16) (patch 64 13) (patch 129 43) (patch 180 77) (patch 197 67) (patch 172 3) (patch 185 82) (patch 191 24) (patch 34 91) (patch 0 33) (patch 44 28) (patch 146 56) (patch 78 35) (patch 0 18) (patch 81 69) (patch 159 75) (patch 106 88) (patch 189 24) (patch 83 72) (patch 146 31) (patch 70 15) (patch 197 7) (patch 79 94) (patch 77 81) (patch 174 75) (patch 145 55) (patch 186 22) (patch 131 38) (patch 77 43) (patch 190 95) (patch 14 25) (patch 125 76) (patch 115 2) (patch 112 95) (patch 142 50) (patch 34 86) (patch 161 25) (patch 92 39) (patch 142 33) (patch 51 21) (patch 185 1) (patch 143 57) (patch 63 33) (patch 49 63) (patch 176 8) (patch 81 20) (patch 168 48) (patch 185 50) (patch 111 38) (patch 181 25) (patch 85 29) (patch 22 52) (patch 24 72) (patch 119 19) (patch 112 71) (patch 30 26) (patch 143 54) (patch 85 92) (patch 4 33) (patch 117 21) (patch 116 22) (patch 88 3) (patch 34 96) (patch 191 16) (patch 156 34) (patch 173 21) (patch 146 93) (patch 193 5) (patch 13 42) (patch 136 75) (patch 44 62) (patch 116 17) (patch 140 6) (patch 41 69) (patch 87 70) (patch 132 46) (patch 147 86) (patch 111 15) (patch 122 94) (patch 171 31) (patch 37 54) (patch 157 15) (patch 52 42) (patch 132 10) (patch 15 56) (patch 68 45) (patch 169 19) (patch 87 5) (patch 168 86) (patch 120 72) (patch 21 49) (patch 137 86) (patch 188 32) (patch 167 33) (patch 65 10) (patch 95 88) (patch 71 10) (patch 105 27) (patch 68 2) (patch 186 46) (patch 124 64) (patch 62 12) (patch 69 79) (patch 170 35) (patch 109 33) (patch 63 72) (patch 122 98) (patch 42 90) (patch 123 91) (patch 104 0) (patch 119 25) (patch 18 37)
  )
    ask patches-for-old-snacks
    [
      if not any? snacks-here
      [
        sprout-snacks 1
        [
          set color 45
          set shape "circle"
          set size 2 ;2.5
          if stamp_snacks [stamp]
          set shape "circle" ;"x"
          ;set color white
          ifelse rnd-snack-size
          [
            set snack-food-left random-poisson snack-size
          ]
          [
            set snack-food-left snack-size
          ]
          set color yellow
          ;set size ( 1 / zoomin ) + 1 * (snack-food-left / snack-size)
          set size ( 1 / zoomin ) ;+ 1 ;* (snack-food-left / snack-size)
          set dibs 0
          set snack-attractiveness 0
        ]
      ]
    ]
end



;;----------------------------------------------------------
;; created by Marina Toger
;;
;; PhD advisors Prof. Itzhak Benenson, Prof. Danny Czamanski
;; in collaboration with Dr. Dan Malkinson
;; thanks for programming advise to Lev Toger
;;
;; 2015/07/05
;;----------------------------------------------------------

;; \m/
@#$#@#$#@
GRAPHICS-WINDOW
506
10
1117
622
-1
-1
3.0
1
20
1
1
1
0
0
0
1
0
200
0
200
0
0
1
ticks
30.0

BUTTON
5
10
183
49
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

SLIDER
5
196
181
229
pig-start-points
pig-start-points
1
100
5.0
1
1
NIL
HORIZONTAL

SLIDER
201
236
377
269
num-of-snacks-to-start
num-of-snacks-to-start
0
500
300.0
10
1
NIL
HORIZONTAL

BUTTON
6
52
92
85
NIL
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

SWITCH
168
1384
298
1417
color-foraging
color-foraging
1
1
-1000

SWITCH
168
1351
298
1384
color-path
color-path
1
1
-1000

TEXTBOX
15
1275
96
1293
Debugging
13
0.0
1

SWITCH
5
268
181
301
rnd-setup-pigs
rnd-setup-pigs
0
1
-1000

SWITCH
12
1005
164
1038
rnd-setup-snacks
rnd-setup-snacks
0
1
-1000

SLIDER
202
202
377
235
snack-size
snack-size
1
600
60.0
1
1
NIL
HORIZONTAL

SLIDER
10
936
187
969
max-ticks
max-ticks
60
36000
600.0
60
1
NIL
HORIZONTAL

MONITOR
198
10
284
63
NIL
model-time
17
1
13

SLIDER
8
901
187
934
max-time-feeding
max-time-feeding
60
36000
36000.0
60
1
NIL
HORIZONTAL

TEXTBOX
218
65
263
83
hh:mm
11
0.0
1

SLIDER
4
233
182
266
num-pigs-at-start-points
num-pigs-at-start-points
1
50
1.0
1
1
NIL
HORIZONTAL

SLIDER
380
281
499
314
smell-range
smell-range
10
500
410.0
10
1
NIL
HORIZONTAL

BUTTON
97
52
182
85
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

SWITCH
14
1381
165
1414
rnd-snack-size
rnd-snack-size
1
1
-1000

INPUTBOX
136
1217
190
1277
zoomin
0.5
1
0
Number

CHOOSER
6
89
182
134
target-selection
target-selection
"probabilistic" "deterministic" "low-cost"
2

INPUTBOX
10
1126
60
1186
c
10.0
1
0
Number

INPUTBOX
60
1126
110
1186
k
0.1
1
0
Number

SWITCH
13
1347
165
1380
snacks-urban?
snacks-urban?
1
1
-1000

PLOT
-3
533
373
705
pig_depth
ticks
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"mean-Easting" 1.0 0 -2674135 true "" "plot mean [xcor] of pigs"
"max-Easting" 1.0 0 -7500403 true "" "plot max [xcor] of pigs"
"max-X-ever" 1.0 0 -16777216 true "" "plot max [pig-max-xcor-ever] of pigs"

MONITOR
281
791
374
844
mean-satiety
mean [pig-satiety] of pigs
17
1
13

MONITOR
280
847
375
900
mean-energy
mean [pig-energy] of pigs
17
1
13

CHOOSER
6
134
182
179
setup-type
setup-type
"Haifa" "scenario1" "scenario2" "scenario3" "Uniform05" "Uniform025"
0

INPUTBOX
110
1126
160
1186
x_a
50.0
1
0
Number

INPUTBOX
381
218
458
278
n-snacks
50.0
1
0
Number

INPUTBOX
10
1208
97
1268
p-min
0.1
1
0
Number

MONITOR
194
996
249
1041
#snacks
count snacks
17
1
11

MONITOR
390
410
482
455
os 0.01
count patches with [ cost <= 0.001]
17
1
11

MONITOR
308
746
374
791
NIL
food-facto
17
1
11

MONITOR
387
638
484
683
built 999999
count patches with [cost > 1]
17
1
11

MONITOR
388
547
483
592
backyard 0.5
count patches with [cost = 0.5]
17
1
11

MONITOR
388
592
484
637
roads 0.75
count patches with [cost = 0.75]
17
1
11

INPUTBOX
193
1217
252
1277
os-width
1.0
1
0
Number

MONITOR
308
715
374
760
NIL
food-plan
17
1
11

SWITCH
13
1041
103
1074
grid?
grid?
1
1
-1000

SLIDER
14
1075
190
1108
grid-modul
grid-modul
1
200
14.0
1
1
NIL
HORIZONTAL

TEXTBOX
17
180
58
198
Pigs
11
0.0
1

TEXTBOX
211
185
264
203
Snacks
11
0.0
1

SWITCH
11
971
114
1004
pahim?
pahim?
1
1
-1000

BUTTON
190
1315
284
1348
put-mahsom
ask patches with [pxcor = 50][set cost 999999]\nmap-cost\nask snacks with [ [cost] of patch-here > 0.5] [die]
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
379
126
487
159
NIL
write-csv
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
280
902
376
955
mean-s-eaten
mean [pig-snacks-eaten] of pigs
17
1
13

MONITOR
388
500
483
545
gardens 0.25
count patches with [cost = 0.25]
17
1
11

MONITOR
389
454
483
499
agri 0.1
count patches with [cost = 0.1]
17
1
11

MONITOR
387
683
484
728
NIL
count patches
17
1
11

TEXTBOX
9
710
159
738
on avg Haifa sallies are\n1.2 of Uniform025 sallies
11
0.0
1

TEXTBOX
141
1202
291
1220
landscape
11
0.0
1

TEXTBOX
13
1110
163
1128
params of attractiveness
11
0.0
1

TEXTBOX
385
188
485
220
target selection out of
11
0.0
1

TEXTBOX
11
1191
161
1219
prob to reeval target
11
0.0
1

MONITOR
196
902
250
947
ratio
(count snacks) / (count pigs)
17
1
11

TEXTBOX
394
391
478
409
landscape data
11
0.0
1

SLIDER
203
152
375
185
gamma
gamma
0.2
0.8
0.55
0.05
1
NIL
HORIZONTAL

TEXTBOX
206
136
356
154
Costdistance threshold
11
0.0
1

SWITCH
1436
209
1603
242
set-random-seed?
set-random-seed?
1
1
-1000

SLIDER
6
743
178
776
h-param
h-param
0
1
0.5
.05
1
NIL
HORIZONTAL

TEXTBOX
8
781
230
853
A* heuristic parameter\n0.25 is the min cost of \n           non-OS area (0.01 0.05 0.1 0.25)\n1   Greedy Best-First-Search \n0   Breadth First Search
11
0.0
1

SWITCH
1436
274
1605
307
reset-random-seed2?
reset-random-seed2?
1
1
-1000

MONITOR
289
11
356
56
not-blue
count pigs with [pig-state != \"passive\"]
17
1
11

INPUTBOX
1439
148
1495
208
usrSeed
1.0
1
0
Number

SWITCH
1435
242
1605
275
set-usr-seed?
set-usr-seed?
1
1
-1000

BUTTON
1428
78
1495
111
NIL
map-cost
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
194
949
251
994
#pigs
count pigs
17
1
11

MONITOR
187
269
253
314
snacks@start
num-of-snacks-to-start
17
1
11

MONITOR
254
269
322
314
ratio@start
num-of-snacks-to-start / (count pigs)
17
1
11

SWITCH
13
1309
184
1342
can-cross-roads?
can-cross-roads?
0
1
-1000

BUTTON
1427
13
1495
46
png-ready
;map-cost\nask links [die]\nask pigs [set label \"\"]\n\n;;recolor\nask pigs [set color blue] ;pigs all blue\nask snacks [set color 45 set size 2] ;snacks yellow\nask links [die]\nask patches with [cost = 0.75] [ set pcolor 4]\nask patches with [cost = 0.5] [ set pcolor 6]\nask patches with [cost = 0.25] [ set pcolor 8]\nask patches with [cost = 999999] [ set pcolor 2]
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
1428
46
1495
79
recolor
ask pigs [set color blue] ;pigs all blue\nask snacks [set color 45] ;snacks yellow\nask links [die]\nask patches with [cost = 0.75] [ set pcolor 4]\nask patches with [cost = 0.5] [ set pcolor 6]\nask patches with [cost = 0.25] [ set pcolor 8]\nask patches with [cost = 999999] [ set pcolor 2]\n\n\n\n\n;ask snacks [set color 25]                            ;;snacks orange\n;ask snacks [set color black]                         ;;snacks black\n\n;ask patches with [cost = 999999] [ set pcolor 0]     ;;buildings black\n;ask patches with [cost = 999999] [ set pcolor 9.9]   ;;buildings white\n\n;ask patches with [cost < 0.1] [ set pcolor 65 ]      ;; os brighter green\n;ask patches with [cost < 0.1] [ set pcolor 66 ]      ;; os another green\n\n;ask pigs [set color 104] ;pigs all blue
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
188
721
302
781
data_File2
a_denya.asc
1
0
String

PLOT
0
342
367
528
boars_x_
m
count
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range min-pxcor (max-pxcor * 5)\nset-plot-y-range 0 count pigs\nset-histogram-num-bars 20\nset-plot-pen-mode 1" ""
PENS
"list-of-pig-x" 1.0 1 -16777216 true "set-histogram-num-bars 20\nset-plot-pen-mode 1" "histogram list-of-pig-x"

MONITOR
320
270
378
315
NIL
gamma
17
1
11

BUTTON
378
47
486
80
NIL
prepare-csv
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
374
10
481
38
press this before behaviorSpace run
11
0.0
1

MONITOR
179
1135
236
1180
alpha
(ln c) / (k * x_a)
3
1
11

SWITCH
7
863
191
896
first-target-probabilistic
first-target-probabilistic
1
1
-1000

BUTTON
387
331
504
364
NIL
graph-validtn
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1436
322
1624
355
Write_pig-route-lengths
Write_pig-route-lengths
1
1
-1000

SWITCH
1436
355
1582
388
Write_pig-sallies
Write_pig-sallies
1
1
-1000

SWITCH
1436
388
1615
421
Write_list-of-pig-x-run
Write_list-of-pig-x-run
1
1
-1000

SWITCH
1436
420
1657
453
Write_patches-pigvisits-matrx
Write_patches-pigvisits-matrx
1
1
-1000

SWITCH
2
304
182
337
random_start_time?
random_start_time?
1
1
-1000

CHOOSER
204
88
370
133
data_File
data_File
"a_denya.asc" "a_neve_shaanan_built_park2.asc" "a_ein_hayam.asc" "a_ramat_hanasi.asc" "a_hadar.asc" "a_ramat_hen.asc" "c0st_m1000x500.asc" "a_horev.asc" "a_shambur.asc" "a_karmeliya.asc" "a_vardiya.asc" "a_moriya.asc" "bolvanka.asc" "a_neve_shaanan.asc" "s02.asc" "a_neve_shaanan_built_park.asc"
5

SWITCH
1311
462
1455
495
stamp_snacks
stamp_snacks
1
1
-1000

BUTTON
1316
497
1445
530
NIL
ask snacks [die]
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
1316
531
1432
564
NIL
ask links [die]
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
1317
566
1440
599
NIL
record-snacks
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
1323
609
1508
642
NIL
show  snack-patch-list-h
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
1321
651
1453
684
recreate_snacks
recreate_snacks
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
1310
426
1419
459
recreate_pig
ask patch 1 83\n[sprout-pigs 1\n    [\n      set size 3 / zoomin + 1\n      set shape \"pigface\"\n      ;set color pink\n      set heading 0\n      ;stamp\n      set color magenta\n      set pig-state \"foraging\"\n      set pig-satiety 0\n      set pig-energy 0\n      pd\n      set label pig-state\n      set label-color black\n      set pig-home patch-here\n      set pig-time-feeding 0\n      set pig-penetration 0\n      set pig-depth 0\n      set pig-snacks-eaten 0\n      set pig-current-sally []\n      set pig-sallies []\n      setup-pig-count-patch-types\n      set Lpig-ptypes2 n-values length Lcosts [0]\n      set pig-patches-visited 0\n      set pig-max-xcor-ever xcor\n      set pig-opt-path-cost 999999\n      reset-target-and-path\n      setup-waiting\n    ]\n    ]
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
1309
392
1422
425
NIL
ask pigs [die]
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
1310
356
1419
389
NIL
ask turtles [die]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## Assumptions and parameters
Pigs know the open space that they wake up at. We ignore the process of looking for a path to the snack. We assume the pig looked and found a least-cost-path (LCP). During the day people threw out food into garbage cans => Snacks appear randomly in built areas. Each snack emanates smell that decays with distance. The smell of snacks can have a cut-off smell-range.

Each food unit takes max-time-feeding to eat. Pig will eat 1 unit of food each tick before continuing. Pigs don’t share food => if there is another pig, the latest arrival will have to leave (we ignore if it is dominant and other social dynamics).

Time assumption:
1 tick = 1 second
max-ticks = 3600 is one night = 10 h = 600 min = 3600 sec
pigs move 5 m/s which is 1 cell each tick
1 h = 60 min = 360 sec = 360 ticks
speed of feeding pig = 0 (no movement while feeding)

LCP algorithm A* function f = g + h, where g is cost till here, and h is distance to target (I will try to make it 0, but that makes Dijkstra from A*).

Snacks are either same size or if rnd-snack-size is TRUE then it's a Poisson distribution around snack-size mean
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

pigface
true
0
Polygon -7500403 true true 150 75 180 75 195 90 210 105 240 150 240 180 210 210 195 225 180 225 165 240 150 240
Polygon -16777216 true false 150 150 180 150 195 165 180 195 150 210
Polygon -7500403 true true 210 90 240 75 255 75 270 90 285 90 270 120 255 135 210 120 210 105
Polygon -7500403 true true 90 90 60 75 45 75 30 90 15 90 30 120 45 135 90 120 90 105
Polygon -7500403 true true 150 75 120 75 105 90 90 105 60 150 60 180 90 210 105 225 120 225 135 240 150 240
Polygon -16777216 true false 150 150 120 150 105 165 120 195 150 210
Rectangle -7500403 true true 120 165 135 180
Rectangle -7500403 true true 165 165 180 180
Polygon -16777216 true false 105 120 120 120 135 135 105 135 105 120
Polygon -16777216 true false 195 120 180 120 165 135 195 135 195 120

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="160303" repetitions="365" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>write-csv
;let hist_word (word behaviorspace-run-number "pigs_x_obs.csv")
;export-plot "boars_x_" hist_word</final>
    <exitCondition>ticks &gt;= max-ticks or not any? pigs with [pig-state != "passive"]</exitCondition>
    <metric>front</metric>
    <metric>mean [pig-max-xcor-ever] of pigs</metric>
    <metric>mean [pig-energy] of pigs</metric>
    <metric>mean [pig-satiety] of pigs</metric>
    <metric>mean [traveled] of pigs</metric>
    <metric>mean [pig-snacks-eaten] of pigs</metric>
    <metric>num-of-snacks-to-start / (count pigs)</metric>
    <metric>mean [pig-patches-visited] of pigs</metric>
    <metric>Lcosts</metric>
    <metric>item 0 Lmean-visits</metric>
    <metric>item 2 Lmean-visits</metric>
    <metric>item 3 Lmean-visits</metric>
    <metric>item 4 Lmean-visits</metric>
    <enumeratedValueSet variable="random_start_time?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-pigs-at-start-points">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pig-start-points">
      <value value="20"/>
    </enumeratedValueSet>
    <steppedValueSet variable="num-of-snacks-to-start" first="100" step="100" last="500"/>
    <enumeratedValueSet variable="smell-range">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="0.55"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="setup-type">
      <value value="&quot;scenario3&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-min">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-snacks">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="target-selection">
      <value value="&quot;low-cost&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="h-param">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="snack-size">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rnd-setup-snacks">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pahim?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rnd-setup-pigs">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="set-usr-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="set-random-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reset-random-seed2?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rnd-snack-size">
      <value value="false"/>
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
