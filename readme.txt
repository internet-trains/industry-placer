Industry Constructor GameScript by R2dical
==========================================

A game script for OpenTTD, that provides options for how
industries are built and can also maintain the number level
as the game progresses.

Version 3, tested with OpenTTD 1.3.2

Released under GPL v3.

WARNING: This script changes some game settings, see Usage below.

Note: 
- This script can take a while with large maps and/or some setting combinations.
- For large maps set debug = 2 to see where the script gets stuck and tweak the
  settings to speed it up on the fly. (importantly: Prospect abnormal industries 
  rather than use methods? = true)
- The script will say "Built all industry class types" when done in the GS Debug menu.

Requires
--------

Superlib*	v35
MinchinWeb*	v6

*Note these are the Game Script versions of these libraries.

NewGrf
------

Newgrf compatible as long as the settings are consistent with any 
extra requirements in the newgrf industries (eg Pikkas PBI).

The script identifies "special" industries by name, so may not pick 
up these if they are changed by a newgrf.

Installation
------------
TBA

Recommended you install via the ingame content function.

Usage
-----

- This script must be selected in game from the AI/Script dialogue.
- Select "parameters", the following will change your game Advanced settings:

	General
	- Max distance from edge for Oil Refineries.
	- Allow multiple similar industries per town?

- Set parameters if you do not desire the defaults, the settings are 
based on a 256 * 256 map.
- Set the rest from defaults how you desire your game, recommended that 
you do not make drastic changes first few times.

- Start a new game (with No. of industries = funding only).
- Pause if not.
- Open the AI/Game script dialogue and track the progress of the script.
- If the script is taking a long time, or you are getting errors, set Debug = 2.
- Modify the available settings as the script runs till it completes.
- Once "completed" message shows you can unpause and play:).

You may get various error msgs with some settings combinations, when industries can not be built. 
I made an effort to make these msgs somewhat helpful but due to the vast number of combinations
of settings I cannot provide a exact solution to get the industries to build. Most of the time you
can tweak the setting a bit to fix and these are intuitive, I leave it to the player to solve
for their desired settings :) Post on the forum thread if you want some help.

Required game settings
----------------------

No. of industries				Funding only
Allow multiple similar industries per town*	Yes (Recommended, not required)
Max distance from edge for Oil Refineries *	32 (Recommended, not required)

*These settings are replicated in the script parameters, and affect those 
in the Advanced Menu.

Recommended map settings
------------------------

Towns				Normal
Terrain type			Hilly (Recommended, not required)
Sea level			Very low
Variety distribution		Low
Edges				All water
Snow line			4

Abnormal industries
-------------------
Oil Refinery		(temperate + arctic + tropical - must be within X of edge of map)
Farm			(arctic - must be below snow line)
Forest			(arctic - must be above snow line)
Water Supply		(tropical - must be in desert)

Special industries
------------------
Bank			(temperate + arctic + tropical - must be in towns > 1200 (choose min town pop))
Oil Rig			(temperate - must be in water (choose a starting year))
Water Tower		(tropical - must be on desert tiles within a town (choose min town pop))
Lumber Mill		(tropical - not created, must be in rainforest (choose to create))

Notes
-----
No special/abnormal industries in toyland.
All distance measurements are in ManhattanDistance.
Method parameters are dynamic in game so you can tweak settings as they are used.

Parameters
----------

Based on 256 x 256, some settings are scaled for larger / smaller maps.

General
- Max distance from edge for Oil Refineries.
	Linked to the setting in Advanced Settings.
- Allow multiple similar industries per town?
	Linked to the setting in Advanced Settings.
- Prospect abnormal industries rather than use methods?
	Use this setting when the script is getting stuck at the abnormal industries (see above).

Manage
- Manage industry amount?
	Yes to build industries every X months based on current numbers.
- Industry build rate (months)
	The waiting period to build more industries.
- Industry build limit (per refresh)
	The max number to build every period.

Debug
- Log level (higher = print more)


Density
- Total industries
	The base number of industries (based on a 256 * 256 map).
- Min industries %
	Modifies chances based on total.
- Max industries %
	Modifies chances based on total.
- Primary industries proportion
	Proportion of "raw producer" industries.
- Secondary industries proportion
	Proportion of "processing" industries.
- Tertiary industries proportion
	Proportion of "accepting only" industries.
- Special industries proportion
	Proportion of "special" industries (see above section).
- Primary industries spawning method
	Method to use to spawn "raw producer" industries.
- Secondary industries spawning method
	Method to use to spawn "processing" industries.
- Tertiary industries spawning method
	Method to use to spawn "accepting only" industries.

Scattered
	Tries to build with an even distribution, away from other industries and towns.
- Minimum distance from towns
- Minimum distance from industries

Cluster
	Tries to build a cluster of the same industries, USUALLY REQUIRES 
	MULTI IND PER TOWN TO WORK.
 - Maximum industries per cluster
 - Minimum distance between same cluster industries
 - Maximum distance between same cluster industries
 - Minimum distance between clusters
 - Minimum distance from towns
 - Minimum distance from industries

Town
	Tries to build industries close to a town, REQUIRES MULTI IND PER TOWN 
	above if you activate it here.
 - Minimum population
 - Minimum distance from town
 - Maximum distance from town factor
 	Used in the calculation of minimum radius from town center (Radius = Houses# * (x / 100)).
 - Maximum total industries per town
 - Minimum distance from other industries
 - Multiple same industries in town?

Special
	Handles climate-specific, special build type industries.
 - Minimum town pop for Banks
 - Minimum year for Oil Rigs
 - Minimum town pop for Water Towers
 - Build Lumber Mills?
