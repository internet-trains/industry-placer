# Industry Placer

This is a heavily modified version of the industry placer script from R2dical,
posted at https://www.tt-forums.net/viewtopic.php?f=65&t=67181&start=40

This script attempts to place industries at the game start in a fun and
asymmetrical way.

Primary resource generating industries are placed somewhat close to towns in
large clusters. Secondary processing industries are placed randomly as
before. Tertiary destination industries are placed inside towns. Farms are used
to fill in the space that's left.

## Installation

Put the repo files in `<OpenTTD path>\game\Industry_Placer`

## Usage

After choosing a compatible industry set, make sure industry is "funding only".
Configure the game script and once you start the game with it, wait for it to
finish. It may take a while on longer maps, and opening the AI/Game Script Debug
can help pass the time. Remember, hitting 'fast forward' in the game makes
scripts run faster!

The script in particular may appear to 'hang' when it's first getting started,
as it is building and randomizing a tile list.

## Compatible Industry NewGRFs

So far, only the default temperate industry set, FIRS Steeltown, FIRS North
America, and FIRS Extreme have support. Additional NewGRFs can be defined and
customized by modifying the `RegisterIndustryGRF` function in `main.nut`.

## Parameters

* Which industry NewGRF are you using?

Toggle between NewGRFs. Bad things happen if this is wrong.

* Max industries per town?

This is the cap on how many tertiary industries can exist in a town.

* Tertiary industry distance from town limit

This caps how far away a tertiary industry can be from a town.

* Primary industry distance from town limit

This caps how close a primary industry can be to a town.

* Cluster footprint radius

This sets the (square) radius of a cluster location. Smaller will make for
smaller clusters.

* Percent available space for cluster siting required

This sets the acceptable threshold for cluster footprints. Setting this to 100
will mean only square cluster-zones exist; setting this to 0 means it accepts
any footprint (and may create clusters with only 1-2 industries).

* Max industries per cluster

This is the upper cap on industries in a cluster. Other constraints -- distance
between industries and cluster footprint size & acceptable space -- will dictate
if this cap is reached.

* Space between cluster zones

This is the distance between cluster zones.

* Space between any two industries

This is the distance between any two industries on the map.

* Clusters avoid towns above this size

For large towns, this is the closest a cluster can get. This feature doesn't
actually work right now.

* Clusters stay this far away from towns above large town cutoff

This defines the 'large town' used in the earlier parameter.

* Spacing between farm fill

This defines how dense farms are in the final step of industry placement.

* Attempt to build this many clusters of raw industry

This is an upper bound on how many clusters will be attempted. Tiles can be
exhausted way before this limit is reached.

* Attempt to build this many processing industries

This is an upper bound on how many processing industries will be attempted.

* Attempt to build this many tertiary industries

This is an upper bound on how many tertiary industries will be attempted. Towns
can be exhausted way before this limit is reached.

* Debug log level - 3 for most verbose

Controls the volume of messages in the debug window.
