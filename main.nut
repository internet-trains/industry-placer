/*   This file is part of IndustryConstructor, which is a GameScript for OpenTTD
 *   Copyright (C) 2013  R2dical
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Objectives

// 1. Maintain functionality but improve script performance
// 2. Extend script functionality into other 'post-map creation' initialization
//     ex. drawing roads between towns?
// 3. Extend script to handle more uses cases -- don't hardcode cargo types
// 4. Reference appropriate documentation for game API calls

// Notes:
// Log levels:
//    static LVL_INFO = 1;           // main info. eg what it is doing
//    static LVL_SUB_DECISIONS = 2;  // sub decisions - eg. reasons for not doing certain things etc.
//    static LVL_DEBUG = 3;          // debug prints - debug prints during carrying out actions



// Imports - wtf does this do
import("util.superlib", "SuperLib", 36);
Result <- SuperLib.Result;
Log <- SuperLib.Log;
Helper <- SuperLib.Helper;
ScoreList <- SuperLib.ScoreList;
Tile <- SuperLib.Tile;
Direction <- SuperLib.Direction;
Town <- SuperLib.Town;
Industry <- SuperLib.Industry;

require("progress.nut");

import("util.MinchinWeb", "MinchinWeb", 6);
SpiralWalker <- MinchinWeb.SpiralWalker;
// https://www.tt-forums.net/viewtopic.php?f=65&t=57903
// SpiralWalker - allows you to define a starting point and walks outward

class IndustryConstructor extends GSController {
    test_counter = 0;
    build_limit = 0;
    town_industry_limit = 5; // set in config
    town_radius = 20; // set in config
    industry_newgrf = "North American FIRS"; //set in config

    chunk_size = 256; // Change this if Valuate runs out of CPU time
    town_industry_counts = GSTownList();

    // Map mask
    alias_tiles = GSTileList();

    // Tile lists
    land_tiles = GSTileList();
    shore_tiles = GSTileList();
    water_tiles = GSTileList();
    nondesert_tiles = GSTileList();
    nonsnow_tiles = GSTileList();

    town_tiles = GSTileList();

    // Town eligibility lists: 1 for eligible in that category, 0 else
    town_eligibility_default = GSTownList();
    town_eligibility_water = GSTownList();
    town_eligibility_shore = GSTownList();
    town_eligibility_townbldg = GSTownList();
    town_eligibility_neartown = GSTownList();
    town_eligibility_nondesert = GSTownList();
    town_eligibility_nonsnow = GSTownList();
    town_eligibility_nonsnowdesert = GSTownList();

    // Cluster parameters
    confirmed_cluster_list = GSTileList();
    confirmed_cluster_footprints = GSTileList();
    cluster_radius = 10;
    cluster_footprint_size_req = 4; // How many alias points the cluster footprint should hit.
    cluster_point_limit = 1000;

    ind_type_count = 0; // count of industries in this.ind_type_list, set in industryconstructor.init.
    cargo_paxid = 0; // passenger cargo id, set in industryconstructor.init.

    rawindustry_list = []; // array of raw industry type id's, set in industryconstructor.init.
    rawindustry_list_count = 0; // count of primary industries, set in industryconstructor.init.
    procindustry_list = []; // array of processor industry type id's, set in industryconstructor.init.
    procindustry_list_count = 0; // count of secondary industries, set in industryconstructor.init.
    tertiaryindustry_list = []; // array of tertiary industry type id's, set in industryconstructor.init.
    tertiaryindustry_list_count = 0; // count of tertiary industries, set in industryconstructor.init.

    // user variables
    density_ind_total = 0; // set from settings, in industryconstructor.init. total industries, integer always >= 1
    density_ind_min = 0; // set from settings, in industryconstructor. init.min industry density %, float always < 1.
    density_ind_max = 0; // set from settings, in industryconstructor.init. max industry density %, float always > 1.
    density_raw_prop = 0; // set from settings, in industryconstructor.init. primary industry proportion, float always < 1.
    density_proc_prop = 0; // set from settings, in industryconstructor.init. secondary industry proportion, float always < 1.
    density_tert_prop = 0; // set from settings, in industryconstructor.init. tertiary industry proportion, float always < 1.
    density_raw_method = 0; // set from settings, in industryconstructor.init.
    density_proc_method = 0; // set from settings, in industryconstructor.init.
    density_tert_method = 0; // set from settings, in industryconstructor.init.

    industry_classes = GSIndustryTypeList(); // Stores the build-type of industries
    industry_class_lookup = [
                             "Default",
                             "Water",
                             "Shore",
                             "TownBldg",
                             "NearTown",
                             "Nondesert",
                             "Nonsnow",
                             "Nonsnowdesert"];

    constructor() {
    }
}

// Save function
function IndustryConstructor::Save() {
    return {};
}

// Load function
function IndustryConstructor::Load() {
}

// Program start function
function IndustryConstructor::Start() {
    this.Init();
    //this.BuildIndustry();
}

function IndustryConstructor::InArray(item, array) {
    for(local i = 0; i < array.len(); i++) {
        if(array[i] == item) {
            return true;
        }
    }
    return false;
}

function IndustryConstructor::RegisterIndustryGRF(name) {
    Print("Registering " + name + " industries.");
    local water_based_industries = [];
    local shore_based_industries = [];
    local townbldg_based_industries = [];
    local neartown_based_industries = [];
    local nondesert_based_industries = [];
    local nonsnow_based_industries = [];
    local nonsnowdesert_based_industries = [];
    // Overrides are for industries that we want to force into a tier
    /*
     * From the API docs:
     *   Industries might be neither raw nor processing. This is usually the
     *   case for industries which produce nothing (e.g. power plants), but
     *   also for weird industries like temperate banks and tropic lumber
     *   mills.
     */
    local primary_override = [];
    local secondary_override = [];
    local tertiary_override = [];
    if(name == "North American FIRS") {
        water_based_industries = [
                                  "Oil Rig",
                                  "Fishing Site",
                                  "Dredging Site"
                                  ];
        shore_based_industries = [
                                  "Bulk Terminal",
                                  "Goods Port",
                                  "Liquids Terminal"
                                  ];
        townbldg_based_industries = [
                                     "General Store",
                                     "Grocery Store",
                                     "Hardware Store",
                                     "Smithy Forge"
                                     ];
        neartown_based_industries = [
                                     "Vehicle Dealer",
                                     "Bank"
                                     ];
        nondesert_based_industries = [
                                      "Forestry"
                                      ];
        nonsnow_based_industries = [
                                    "Fruit Plantation"
                                    ];
        nonsnowdesert_based_industries = [
                                          "Arable Farm",
                                          "Dairy Farm",
                                          "Mixed Farm"
                                          ];
        tertiary_override = [
                             "Mint"
                             ];
    }
    if(name == "FIRS Complex") {
        //tk
    }
    if(name == "FIRS Steeltown") {
        //tk
    }

    foreach(ind_id, value in industry_classes) {
        local ind_name = GSIndustryType.GetName(ind_id);
        if(InArray(ind_name, water_based_industries)) {
            industry_classes.SetValue(ind_id, 1);
        }
        if(InArray(ind_name, shore_based_industries)) {
            industry_classes.SetValue(ind_id, 2);
        }
        if(InArray(ind_name, townbldg_based_industries)) {
            industry_classes.SetValue(ind_id, 3);
        }
        if(InArray(ind_name, neartown_based_industries)) {
            industry_classes.SetValue(ind_id, 4);
        }
        if(InArray(ind_name, nondesert_based_industries)) {
            industry_classes.SetValue(ind_id, 5);
        }
        if(InArray(ind_name, nonsnow_based_industries)) {
            industry_classes.SetValue(ind_id, 6);
        }
        if(InArray(ind_name, nonsnowdesert_based_industries)) {
            industry_classes.SetValue(ind_id, 7);
        }
    }

    foreach(ind_id, value in GSIndustryTypeList()) {
        local ind_name = GSIndustryType.GetName(ind_id);
        // We have to descend down these if else statements in order
        // Otherwise the overrides don't work
        if(InArray(ind_name, primary_override)) {
            rawindustry_list.push(ind_id);
        } else if(InArray(ind_name, secondary_override)) {
            procindustry_list.push(ind_id);
        } else if(InArray(ind_name, tertiary_override)) {
            tertiaryindustry_list.push(ind_id);
        } else if(GSIndustryType.IsRawIndustry(ind_id)) {
            rawindustry_list.push(ind_id);
        } else if(GSIndustryType.IsProcessingIndustry(ind_id)) {
            procindustry_list.push(ind_id);
        } else {
            tertiaryindustry_list.push(ind_id);
        }
    }
    Print("-----Primary industries:-----");
    foreach(ind_id in rawindustry_list) {
        Print(GSIndustryType.GetName(ind_id) + ": " + industry_class_lookup[industry_classes.GetValue(ind_id)]);
    }
    Print("-----Secondary industries:-----");
    foreach(ind_id in procindustry_list) {
        Print(GSIndustryType.GetName(ind_id) + ": " + industry_class_lookup[industry_classes.GetValue(ind_id)]);
    }
    Print("-----Tertiary industries:-----");
    foreach(ind_id in tertiaryindustry_list) {
        Print(GSIndustryType.GetName(ind_id) + ": " + industry_class_lookup[industry_classes.GetValue(ind_id)]);
    }
    Print("-----Registration done.-----")
}

// Zero
function IndustryConstructor::Zero(x) {
    return 0;
}

// Identity
function IndustryConstructor::Id(x) {
    return 1;
}

// Initialization function
function IndustryConstructor::Init() {
    RegisterIndustryGRF(industry_newgrf);
    MapPreprocess();

    // Town eligibility statuses
    town_eligibility_default.Valuate(Id)
    town_eligibility_water.Valuate(Id);
    town_eligibility_shore.Valuate(Id);
    town_eligibility_townbldg.Valuate(Id);
    town_eligibility_neartown.Valuate(Id);
    town_eligibility_nondesert.Valuate(Id);
    town_eligibility_nonsnow.Valuate(Id);
    town_eligibility_nonsnowdesert.Valuate(Id);

    town_industry_counts.Valuate(Zero);
    Sleep(100);
    PrepareClusterMap();
    while(true) {
        
    }
}


// Map preprocessor
// Creates data for all tiles on the map

function IndustryConstructor::MapPreprocess() {
    Print("Building map tile list.");
    local all_tiles = GSTileList();
    all_tiles.AddRectangle(GSMap.GetTileIndex(1, 1),
                           GSMap.GetTileIndex(GSMap.GetMapSizeX() - 2,
                                              GSMap.GetMapSizeY() - 2));
    Print("Map list size: " + all_tiles.Count());
    local chunks = (GSMap.GetMapSizeX() - 2) * (GSMap.GetMapSizeY() - 2) / (chunk_size * chunk_size);
    Print("Loading " + chunks + " chunks:");
    // Hybrid approach:
    // Break the map into chunk_size x chunk_size chunks and valuate on each of them
    local progress = ProgressReport(chunks);
    for(local y = 1; y < GSMap.GetMapSizeY() - 1; y += chunk_size) {
        for(local x = 1; x < GSMap.GetMapSizeX() - 1; x += chunk_size) {
            local chunk_land = GetChunk(x, y);
            local chunk_shore = GetChunk(x, y);
            local chunk_water = GetChunk(x, y);
            local chunk_alias = GetChunk(x, y);
            local chunk_nondesert = GSTileList();
            local chunk_nonsnow = GSTileList();
            chunk_land.Valuate(GSTile.IsCoastTile);
            chunk_land.KeepValue(0);
            chunk_land.Valuate(GSTile.IsWaterTile);
            chunk_land.KeepValue(0);
            chunk_land.Valuate(IsFlatTile);
            chunk_land.KeepValue(1);
            chunk_shore.Valuate(GSTile.IsCoastTile);
            chunk_shore.KeepValue(1);
            chunk_water.Valuate(GSTile.IsWaterTile);
            chunk_water.KeepValue(1);
            chunk_water.Valuate(IsFlatTile);
            chunk_water.KeepValue(1);
            chunk_nondesert.AddList(chunk_land);
            chunk_nondesert.Valuate(GSTile.IsDesertTile);
            chunk_nondesert.KeepValue(0);
            chunk_nonsnow.AddList(chunk_land);
            chunk_nonsnow.Valuate(GSTile.IsSnowTile);
            chunk_nonsnow.KeepValue(0);
            chunk_alias.Valuate(TileAliasX);
            chunk_alias.KeepValue(0);
            chunk_alias.Valuate(TileAliasY);
            chunk_alias.KeepValue(0);
            land_tiles.AddList(chunk_land);
            shore_tiles.AddList(chunk_shore);
            water_tiles.AddList(chunk_water);
            nondesert_tiles.AddList(chunk_nondesert);
            nonsnow_tiles.AddList(chunk_nonsnow);
            alias_tiles.AddList(chunk_alias);
            if(progress.Increment()) {
                Print(progress);
            }
        }
    }
    town_tiles = BuildEligibleTownTiles();
    Print("Land tile list size: " + land_tiles.Count());
    Print("Shore tile list size: " + shore_tiles.Count());
    Print("Water tile list size: " + water_tiles.Count());
    Print("Nondesert tile list size: " + nondesert_tiles.Count());
    Print("Nonsnow tile list size: " + nonsnow_tiles.Count());
    Print("Alias mask size: " + alias_tiles.Count());
}

function IndustryConstructor::TileAliasX(tile_id) {
    local tile_x = GSMap.GetTileX(tile_id);
    return tile_x % 13;
}

function IndustryConstructor::TileAliasY(tile_id) {
    local tile_y = GSMap.GetTileY(tile_id);
    return tile_y % 13;
}

function IndustryConstructor::IsFlatTile(tile_id) {
    return GSTile.GetSlope(tile_id) == GSTile.SLOPE_FLAT;
}

// Returns the map chunk with x, y in the upper left corner
// i.e. GetChunk(1, 1) will give you (1, 1) to (257, 257)
function IndustryConstructor::GetChunk(x, y) {
    local chunk = GSTileList();
    chunk.AddRectangle(GSMap.GetTileIndex(x, y),
                       GSMap.GetTileIndex(min(x + 256, GSMap.GetMapSizeX() - 2),
                                          min(y + 256, GSMap.GetMapSizeY() - 2)));
    return chunk;
}

// Go through each town and identify every valid tile_id (do we have a way to ID the town of a tile?)
function IndustryConstructor::BuildEligibleTownTiles() {
    /*
    1. get every town
    2. get every tile in every town
    3. cull based on config parameters
     */
    Print("Building town tile list.");
    local town_list = GSTownList();
    town_list.Valuate(GSTown.GetLocation);
    local all_town_tiles = GSTileList();
    local progress = ProgressReport(town_list.Count());
    foreach(town_id, tile_id in town_list) {
        local local_town_tiles = RectangleAroundTile(tile_id, town_radius);
        foreach(tile, value in local_town_tiles) {
            if(!all_town_tiles.HasItem(tile)) {
                all_town_tiles.AddTile(tile);
            }
        }
        if(progress.Increment()) {
            Print(progress);
        }
    }
    Print("Town tile list size: " + all_town_tiles.Count());
    return all_town_tiles;
}

// Paints on the map all tiles in a given list
function IndustryConstructor::DiagnosticTileMap(tilelist, persist = false) {
    foreach(tile_id, value in tilelist) {
        GSSign.BuildSign(tile_id, ".");
    }
    GSController.Sleep(1);
    if(!persist) {
        foreach(sign_id, value in GSSignList()) {
            if(GSSign.GetName(sign_id) == ".") {
                GSSign.RemoveSign(sign_id);
            }
        }
    }
}

function IndustryConstructor::RectangleAroundTile(tile_id, radius) {
    local tile_x = GSMap.GetTileX(tile_id);
    local tile_y = GSMap.GetTileY(tile_id);
    local from_x = min(max(tile_x - radius, 1), GSMap.GetMapSizeX() - 2);
    local from_y = min(max(tile_y - radius, 1), GSMap.GetMapSizeY() - 2);
    local from_tile = GSMap.GetTileIndex(from_x, from_y);
    local to_x = min(max(tile_x + radius, 1), GSMap.GetMapSizeX() - 2);
    local to_y = min(max(tile_y + radius, 1), GSMap.GetMapSizeY() - 2);
    local to_tile = GSMap.GetTileIndex(to_x, to_y);
    local tiles = GSTileList();
    tiles.AddRectangle(from_tile, to_tile);
    return tiles;
}

// Fetch eligible tiles belonging to the town with the given ID
function IndustryConstructor::GetEligibleTownTiles(town_id, terrain_class) {
    local local_town_tiles = RectangleAroundTile(GSTown.GetLocation(town_id), town_radius);
    // now do a comparison between local town tiles and the terrain lists
    local local_eligible_tiles = GSTileList();
    local terrain_tiles = GSTileList();
    switch(terrain_class) {
    case "Water":
        terrain_tiles.AddList(water_tiles);
        break;
    case "Shore":
        terrain_tiles.AddList(shore_tiles);
        break;
    case "TownBldg":
        // ?
        break;
    case "NearTown":
        // ?
        break;
    case "Nondesert":
        terrain_tiles.AddList(nondesert_tiles);
        break;
    case "Nonsnow":
        terrain_tiles.AddList(nonsnow_tiles);
        break;
    case "Nonsnowdesert":
        foreach(tile_id, value in nonsnow_tiles) {
            if(nondesert_tiles.HasItem(tile_id)) {
                terrain_tiles.AddItem(tile_id, value);
            }
        }
        break;
    case "Default":
        terrain_tiles.AddList(land_tiles);
        foreach(tile_id, value in terrain_tiles){} // WTF IS THIS
        break;
    case "All":
        return local_town_tiles;
    }
    foreach(tile_id, value in local_town_tiles) {
        if(terrain_tiles.HasItem(tile_id)) {
            local_eligible_tiles.AddItem(tile_id, value);
        }
    }
    return local_eligible_tiles;
}

// Builds industries in the order of their IDs
function IndustryConstructor::BuildIndustry() {
    Print("Building industries:");

    foreach(industry_id in GSIndustryTypeList) {
        build_method = LookupIndustryBuildMethod(industry_id);
        for(local i = 0; i < BUILD_TARGET; i++) {
            // Build
            switch(build_method) {
                case 1:
                    // Increment count using town build
                    CURRENT_BUILD_COUNT += TownBuildMethod(CURRENT_IND_ID);
                    break;
                case 2:
                    // Increment count using cluster build
                    CURRENT_BUILD_COUNT += ClusterBuildMethod(CURRENT_IND_ID);
                    break;
                case 3:
                    // Increment count using scatter build
                    CURRENT_BUILD_COUNT += ScatteredBuildMethod(CURRENT_IND_ID);
                    break;
            this.ErrorHandler();
            }
            // Display status
            Log.Info(" ~Built " + CURRENT_BUILD_COUNT + " / " + BUILD_TARGET, Log.LVL_SUB_DECISIONS);
        }
    }
}

// Given a tile list, filter to only tiles of that terrain class
function IndustryConstructor::FilterToTerrain(tile_list, terrain_class) {
    local filtered_list = GSTileList();
    switch(terrain_class) {
    case "Water":
        foreach(tile_id, value in tile_list) {
            if(water_tiles.HasItem(tile_id)) {
                filtered_list.AddTile(tile_id);
            };
        }
        break;
    case "Shore":
        foreach(tile_id, value in tile_list) {
            if(shore_tiles.HasItem(tile_id)) {
                filtered_list.AddTile(tile_id);
            }
        }
        break;
    case "TownBldg":
    case "NearTown":
    case "Nondesert":
    case "Nonsnow":
    case "Nonsnowdesert":
    case "Default":
        foreach(tile_id, value in tile_list) {
            if(land_tiles.HasItem(tile_id)) {
                filtered_list.AddTile(tile_id);
            }
        }
        break;
    }
    return filtered_list;
}

function IndustryConstructor::GetEligibleTowns(terrain_class) {
    local town_list = GSTownList();
    switch(terrain_class) {
    case "Water":
        town_list = town_eligibility_water;
        break;
    case "Shore":
        town_list = town_eligibility_shore;
        break;
    case "TownBldg":
        town_list = town_eligibility_townbldg;
        break
    case "NearTown":
        town_list = town_eligibility_neartown;
        break
    case "Nondesert":
        town_list = town_eligibility_nondesert;
        break
    case "Nonsnow":
        town_list = town_eligibility_nonsnow;
        break
    case "Nonsnowdesert":
        town_list = town_eligibility_nonsnowdesert;
        break
    case "Default":
        town_list = town_eligibility_default;
        break
    }
    town_list.KeepValue(1);
    return town_list;
}

// Town build method function
// return 1 if built and 0 if not
// Big issue: town eligibility is really eligibility by class -- we can exhaust all the shore tiles of a town, but still be able to build industries on land near the town. How to handle?
function IndustryConstructor::TownBuildMethod(industry_id) {
    local ind_name = GSIndustryType.GetName(industry_id);
    local terrain_class = industry_class_lookup[industry_classes.GetValue(industry_id)];
    local eligible_towns = GetEligibleTowns(terrain_class);
    Print(eligible_towns.Count());
    if(eligible_towns.IsEmpty() == true) {
        Print("No more eligible " + terrain_class + " towns!");
        return 0;
    }
    local town_id = RandomAccessGSList(eligible_towns);
    local eligible_tiles = GetEligibleTownTiles(town_id, terrain_class);
    Print("Attempting " + ind_name + " in " + GSTown.GetName(town_id));

    if(eligible_tiles.Count() == 0) {
        Print("Exhausted " + terrain_class + " in " + GSTown.GetName(town_id));
        DropTown(town_id, terrain_class);
        return 0;
    }
    // Exclude eligible tiles based on industry class:
    //DiagnosticTileMap(eligible_tiles);
    // For each tile in the town tile list, try to build in one of them randomly
    // - Maintain spacing as given by config file
    // - Once built, remove the tile ID from the global eligible tile list
    // - Two checks at the end:
    //    - Check for town industry limit here and cull from eligible_towns if this puts it over the limit
    //    - Check if the town we just built in now no longer has any eligible tiles
    local stopper = 0;
    while(eligible_tiles.Count() > 0 && stopper < 5) { // The stopper is because of a wierd rate limiter
        stopper++;
        Sleep(5);
        // Pull a random tile
        local attempt_tile = RandomAccessGSList(eligible_tiles);
        eligible_tiles.RemoveItem(attempt_tile);
        ClearTile(attempt_tile);
        local build_success = GSIndustryType.BuildIndustry(industry_id, attempt_tile);
        if(build_success) {
            Print("Founded " + ind_name + " in " + GSTown.GetName(town_id));
            // Check town industry limit (TK) and remove town from global eligible town list if so
            local town_current_industries = town_industry_counts.GetValue(town_id) + 1;
            town_industry_counts.SetValue(town_id, town_current_industries);
            if(town_current_industries == town_industry_limit) {
                // Remove town from eligible list AND remove its tiles from the eligible tiles list
                foreach(tile_id, value in GetEligibleTownTiles(town_id, "All")) {
                    ClearTile(tile_id);
                }
                eligible_towns.RemoveItem(town_id);
            }
            return 1;
        }
    }
    Print(GSTown.GetName(town_id) + " exhausted.");
    // Tiles exhausted, return
    return 0;
}

function IndustryConstructor::DropTown(town_id, terrain_class) {
    switch(terrain_class) {
    case "Water":
        town_eligibility_water.SetValue(town_id, 0);
        break;
    case "Shore":
        town_eligibility_shore.SetValue(town_id, 0);
        break;
    case "TownBldg":
        town_eligibility_townbldg.SetValue(town_id, 0);
        break;
    case "NearTown":
        town_eligibility_neartown.SetValue(town_id, 0);
        break;
    case "Nondesert":
        town_eligibility_nondesert.SetValue(town_id, 0);
        break;
    case "Nonsnow":
        town_eligibility_nonsnow.SetValue(town_id, 0);
        break;
    case "Nonsnowdesert":
        town_eligibility_nonsnowdesert.SetValue(town_id, 0);
        break;
    case "Default":
        town_eligibility_default.SetValue(town_id, 0);
        break;
    }
}

function IndustryConstructor::RandomAccessGSList(gslist) {
    local index = [];
    foreach(item, value in gslist) {
        index.push(item);
    }
    return index[GSBase.RandRange(index.len())];
}

// Clean remove function for tiles
// We maintain several parallel lists of tiles (each can be thought of as an 'information layer'
// So when we remove a tile from eligibility, we should remove them from all of these lists
// Be sure to come back and update this if new information layers are added
// This is a TILE ID based function
function IndustryConstructor::ClearTile(tile_id) {
    land_tiles.RemoveItem(tile_id);
    shore_tiles.RemoveItem(tile_id);
    water_tiles.RemoveItem(tile_id);
    nondesert_tiles.RemoveItem(tile_id);
    nonsnow_tiles.RemoveItem(tile_id);
    town_tiles.RemoveItem(tile_id);
}

function IndustryConstructor::PrepareClusterMap() {
    // Preprocessing for cluster step.
    // Build up a list of valid cluster centers (equivalently, cluster footprints)
    // We should proceed from most restricted terrain type to most general
    // since more restrictive terrain types can be used for general industries
    // Nonsnow nondesert
    // Nonsnow
    // Nondesert
    // Generic
    // Water (special case?)

    // More properly, we should build cluster maps using the smallest lists going to the largest
    // Let's just TBD that...

    // Step 1. Draw a random tile from the list
    // Check two things:
    // a. Tile distances to towns, cities, etc.
    // b. The size of the footprint were we to use this as the home node.
    // If both checks pass, add it to the list of cluster 'centers'. Otherwise remove tile from eligibility.
    // Step 2. Clear the footprint of the added tile from all tile lists
    // Stop when either we run out of tiles or we have enough clusters
    // Enough clusters = # of primary industries * # of clusters for each primary industry


    // Once we have our cluster homes/footprints we assign industries to them
    // Start with the most restricted class of industry and move up from there
    // If we still have available footprints once the # of clusters for each primary industry is satisfied,
    // just push the remainders into the next, less restrictive stack.

    // We can do a more aggressive version of the existing optimization to check only odd X, Y coordinate tiles
    // Because a cluster has to have a certain 'size' to it
    Print("Identifying cluster locations:");
    // 1. Nondesert, nonsnow
    local points_added = BuildClusterPoints("Nonsnowdesert");
    Print(points_added + " nondesert, nonsnow clusters.");
    // 2. Nondesert
    points_added = BuildClusterPoints("Nondesert");
    Print(points_added + " nondesert clusters.");
    // 3. Nonsnow
    points_added = BuildClusterPoints("Nonsnow");
    Print(points_added + " nonsnow clusters.");
    // 4. Regular land (i.e. all other terrain)
    points_added = BuildClusterPoints("Default");
    Print(points_added + " generic land clusters.");
    // 5. Water (special case?)
    points_added = BuildClusterPoints("Water");
    Print(points_added + " water clusters.");
}

function IndustryConstructor::BuildClusterPoints(terrain_class) {
    local potential_cluster_list = GSTileList();
    potential_cluster_list.AddList(alias_tiles);
    potential_cluster_list.RemoveList(confirmed_cluster_footprints);
    switch(terrain_class) {
    case "Water":
        potential_cluster_list.KeepList(water_tiles);
        break;
    case "Nondesert":
        potential_cluster_list.KeepList(nondesert_tiles);
        break;
    case "Nonsnow":
        potential_cluster_list.KeepList(nonsnow_tiles);
        break;
    case "Nonsnowdesert":
        potential_cluster_list.KeepList(nondesert_tiles);
        potential_cluster_list.KeepList(nonsnow_tiles);
        break;
    case "Default":
        potential_cluster_list.KeepList(land_tiles);
        break;
    }
    local points_added = 0;
    local progress = ProgressReport(potential_cluster_list.Count());
    while(potential_cluster_list.Count() > 0 && points_added <= cluster_point_limit) {
        points_added += FindCluster(potential_cluster_list, terrain_class);
        if(progress.Increment()) {
            Print(progress);
        }
    }
    return points_added;
}
// Check that the tile is sufficiently far from towns
// Two conditions:
// 1. Far enough from all 'big' towns.
// 2. Far enough from any town.
function IndustryConstructor::CloseToTown(tile_id) {

}

function IndustryConstructor::FindCluster(tile_list, terrain_class) {
    local test_tile = RandomAccessGSList(tile_list);
    tile_list.RemoveItem(test_tile);
    // Check that it is sufficiently far from all towns
    if(CloseToTown(test_tile)) {
        return 0;
    }
    local footprint = GetFootprint(test_tile, tile_list, cluster_radius);
    local terrain_value = -1;
    switch(terrain_class) {
    case "Water":
        terrain_value = 0;
        break;
    case "Nondesert":
        terrain_value = 1;
        break;
    case "Nonsnow":
        terrain_value = 2;
        break;
    case "Nonsnowdesert":
        terrain_value = 3;
        break;
    case "Default":
        terrain_value = 4;
        break;
    }
    if(footprint.Count() > cluster_footprint_size_req) {
        confirmed_cluster_list.AddItem(test_tile, terrain_value);
        tile_list.RemoveList(footprint);
        confirmed_cluster_footprints.AddList(footprint);
        return 1;
    }
    return 0;
}

// Scans a radius around a tile for the number of tiles in the tile list around a given tile
function IndustryConstructor::GetFootprint(tile_id, tile_list, radius) {
    local footprint = RectangleAroundTile(tile_id, radius);
    footprint.KeepList(tile_list)
    return footprint;
}

// Cluster build method function, return # of industries built
function IndustryConstructor::ClusterBuildMethod(industry_id) {
    local ind_name = GSIndustryType.GetName(industry_id);
    local terrain_class = industry_class_lookup[industry_classes.GetValue(industry_id)];

    // Q: does the rate limiter strike if we have two different zones?
    // Get tile to center cluster on
    local tile1 = GSMap.GetTileIndex(32, 32);
    local tile2 = GSMap.GetTileIndex(96, 96);
    local spiral1 = SpiralWalker();
    local spiral2 = SpiralWalker();
    // - Set spiral walker on node tile
    spiral1.Start(tile1);
    spiral2.Start(tile2);

    return 0;
}

// Scattered build method function (3), return 1 if built and 0 if not
function IndustryConstructor::ScatteredBuildMethod(industry_id) {
    local TOWN_DIST = 0;
    local IND = null;
    local IND_DIST = 0;
    local MULTI = 0;

    // Loop until correct tile
    while(BUILD_TRIES > 0) {
        // Get a random tile
        TILE_ID = Tile.GetRandomTile();

        // Check dist from town
        // - Get distance to town
        TOWN_DIST = GSTown.GetDistanceManhattanToTile(GSTile.GetClosestTown(TILE_ID),TILE_ID);
        // - If less than minimum, re loop
        if(TOWN_DIST < (GSController.GetSetting("SCATTERED_MIN_TOWN") * MULTI)) continue;

        // Check dist from ind
        // - Get industry
        IND = this.GetClosestIndustry(TILE_ID);
        // - If not null (null - no indusrties)
        if(IND != null) {
            // - Get distance
            IND_DIST = GSIndustry.GetDistanceManhattanToTile(IND,TILE_ID);
            // - If less than minimum, re loop
            if(IND_DIST < (GSController.GetSetting("SCATTERED_MIN_IND") * MULTI)) continue;
        }

        // Try build
        if (GSIndustryType.BuildIndustry(industry_id, TILE_ID) == true) return 1;

        // Increment and check counter
        BUILD_TRIES--
        if(BUILD_TRIES == ((256 * 256 * 2.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == ((256 * 256 * 1.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == ((256 * 256 * 0.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == 0) {
            Log.Error("IndustryConstructor.ScatteredBuildMethod: Couldn't find a valid tile!", Log.LVL_INFO)
        }
    }
    Log.Error("IndustryConstructor.ScatteredBuildMethod: Build failed!", Log.LVL_INFO)
    return 0;
}

/*
Helper functions
 */

// Custom get closest industry function
function IndustryConstructor::GetClosestIndustry(tile_id) {
    // Create a list of all industries
    local ind_list = GSIndustryList();

    // If count is 0, return null
    if(ind_list.Count() == 0) return null;

    // Valuate by distance from tile
    ind_list.Valuate(GSIndustry.GetDistanceManhattanToTile, tile_id);

    // Sort smallest to largest
    ind_list.Sort(GSList.SORT_BY_VALUE, GSList.SORT_ASCENDING);

    // Return the top one
    return ind_list.Begin();
}

// Min/Max X/Y list function, returns a 4 tile list with X Max, X Min, Y Max, Y Min, or blank list on fail.
// If second param is == true, returns a 2 tile list with XY Min and XY Max, or blank list on fail.
function IndustryConstructor::ListMinMaxXY(tile_list, two_tile) {
    // Squirrel is pass-by-reference
    local local_list = GSList();
    local_list.AddList(tile_list);
    local_list.Valuate(GSMap.IsValidTile);
    local_list.KeepValue(1);

    if(local_list.IsEmpty()) {
        return null;
    }

    local_list.Valuate(GSMap.GetTileX);
    local_list.Sort(GSList.SORT_BY_VALUE, false);
    x_max_tile = local_list.Begin();
    local_list.Sort(GSList.SORT_BY_VALUE, true);
    x_min_tile = local_list.Begin();

    local_list.Valuate(GSMap.GetTileY);
    local_list.Sort(GSList.SORT_BY_VALUE, false);
    y_max_tile = local_list.Begin();
    local_list.Sort(GSList.SORT_BY_VALUE, true);
    y_min_tile = local_list.Begin();

    local output_tile_list = GSTileList();

    if(two_tile) {
        local x_min = GSMap.GetTileX(x_min_tile);
        local x_max = GSMap.GetTileX(x_max_tile);
        local y_min = GSMap.GetTileY(y_min_tile);
        local y_max = GSMap.GetTileY(y_max_tile);
        output_tile_list.AddTile(GSMap.GetTileIndex(x_min, y_min));
        output_tile_list.AddTile(GSMap.GetTileIndex(x_max, y_max));
    } else {
        output_tile_list.AddTile(x_max_tile);
        output_tile_list.AddTile(x_min_tile);
        output_tile_list.AddTile(y_max_tile);
        output_tile_list.AddTile(y_min_tile);
    }
    return output_tile_list;
}

// Function to check if tile is industry, returns true or false
function IsIndustry(tile_id) {return (GSIndustry.GetIndustryID(tile_id) != 65535);}

function GetTownDistFromEdge(town_id) {
    return GSMap.DistanceFromEdge(GSTown.GetLocation(town_id));
}

// Given a tile, returns true if the nearest industry is further away than TOWN_MIND_IND
function IndustryConstructor::FarFromIndustry(tile_id) {
    local nearest_industry_tile = this.GetClosestIndustry(tile_id);
    if(nearest_industry_tile == null) {
        return true; // null case - no industries on map
    }
    local ind_distance = GSIndustry.GetDistanceManhattanToTile(nearest_industry_tile, tile_id);
    return ind_distance > (GSController.GetSetting("TOWN_MIN_IND"));
}

function IndustryConstructor::Print(string) {
    Log.Info((GSDate.GetSystemTime() % 3600) + " " + string, Log.LVL_INFO);
}

/*
 * Given a list of tiles, expand to include 5 tiles in the 'north' and 'west' direction
 */
function IndustryConstructor::AddBuffer(tile_list, buffer_x_neg, buffer_y_neg, buffer_x_pos, buffer_y_pos, debug = false) {
    local buffer_list = GSTileList();
    foreach(tile, value in tile_list) {
        // Add not just the tile, but all tiles north and west by buffer amount
        for(local y_offset = -buffer_y_pos; y_offset <= buffer_y_neg; y_offset++) {
            for(local x_offset = -buffer_x_pos; x_offset <= buffer_x_neg; x_offset++) {
                local candidate_x = GSMap.GetTileX(tile);
                local candidate_y = GSMap.GetTileY(tile);
                candidate_x = min(max(candidate_x + x_offset, 1), GSMap.GetMapSizeX() - 2);
                candidate_y = min(max(candidate_y + y_offset, 1), GSMap.GetMapSizeY() - 2);
                local candidate_tile = GSMap.GetTileIndex(candidate_x, candidate_y);
                if(!buffer_list.HasItem(candidate_tile)) {
                    buffer_list.AddTile(candidate_tile);
                    if(debug) {
                        GSSign.BuildSign(candidate_tile, ".");
                    }
                }
            }
        }
    }
    return buffer_list;
}
