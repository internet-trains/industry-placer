// Objectives

// 1. Maintain functionality but improve script performance
// 2. Extend script functionality into other 'post-map creation' initialization
//     ex. drawing roads between towns?
// 3. Extend script to handle more uses cases -- don't hardcode cargo types
// 4. Reference appropriate documentation for game API calls

import("util.superlib", "SuperLib", 36);
Log <- SuperLib.Log;
require("progress.nut");

class IndustryConstructor extends GSController {
    test_counter = 0;
    // Config set variables
    town_industry_limit = 5; // How many industries max per town (not including cluster industries)
    town_radius = 20; // How far away to consider a tile part of a town
    town_long_radius = 70; // The zone from town_radius to town_cluster_distance will be the 'outer' zone where cluster industries are available
    cluster_radius = 20; // Cluster footprint size
    cluster_occ_pct = 80; // Percent cutoff for cluster footprint availability. Bump this up if you see a lot of clusters that are 'undersized'.
    cluster_industry_limit = 10;
    cluster_spacing = 30; // Min. spacing between clusters
    industry_spacing = 9; // Min. spacing between industries
    industry_newgrf = "North American FIRS";
    large_town_cutoff = 1200; // how big a town needs to be before it is ineligible for clusters
    large_town_spacing = 100; // how far clusters have to be from large towns, above
    farm_spacing = 20;
    raw_industry_min = 5;
    proc_industry_min = 5;
    tertiary_industry_min = 5;

    // End config set variables
    company_id = 0;
    build_limit = 0;
    chunk_size = 256; // Change this if Valuate runs out of CPU time
    town_industry_counts = GSTownList();

    // Tile lists
    land_tiles = GSTileList();
    shore_tiles = GSTileList();
    water_tiles = GSTileList();
    nondesert_tiles = GSTileList();
    nonsnow_tiles = GSTileList();
    town_tiles = GSTileList();
    outer_town_tiles = GSTileList();
    core_town_tiles = GSTileList();

    // Town eligibility lists: 1 for eligible in that category, 0 else
    // A town is 'eligible' if any tiles in its influence are still available for industry construction
    town_eligibility_default = GSTownList();
    town_eligibility_water = GSTownList();
    town_eligibility_shore = GSTownList();
    town_eligibility_townbldg = GSTownList();
    town_eligibility_neartown = GSTownList();
    town_eligibility_nondesert = GSTownList();
    town_eligibility_nonsnow = GSTownList();
    town_eligibility_nonsnowdesert = GSTownList();

    // Cluster map: tiles that are eligible for being the 'home' of a cluster
    // We gradually drop tiles from this as we attempt to site clusters and build industries
    cluster_eligibility_water = GSTileList();
    cluster_eligibility_nondesert = GSTileList();
    cluster_eligibility_nonsnow = GSTileList();
    cluster_eligibility_nonsnowdesert = GSTileList();
    cluster_eligibility_land = GSTileList();

    farmindustry_list = [];
    rawindustry_list = []; // array of raw industry type id's, set in industryconstructor.init.
    rawindustry_list_count = 0; // count of primary industries, set in industryconstructor.init.
    procindustry_list = []; // array of processor industry type id's, set in industryconstructor.init.
    procindustry_list_count = 0; // count of secondary industries, set in industryconstructor.init.
    tertiaryindustry_list = []; // array of tertiary industry type id's, set in industryconstructor.init.
    tertiaryindustry_list_count = 0; // count of tertiary industries, set in industryconstructor.init.
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
    return null;
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
    local farm_industries = [];
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
    local farm_override = [];

    if(name == "North American FIRS") {
        water_based_industries = [
                                  "Oil Rig",
                                  "Fishing Grounds",
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
                             "Mint",
                             "Smithy Forge"
                             ];
        farm_override = [
                         "Arable Farm",
                         "Mixed Farm"
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
        if(InArray(ind_name, farm_override)) {
            farmindustry_list.push(ind_id);
        } else if(InArray(ind_name, primary_override)) {
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
    Print("-----Farm industries:-----");
    foreach(ind_id in farmindustry_list) {
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
    Sleep(1);
    company_id = GSCompany.ResolveCompanyID(GSCompany.COMPANY_FIRST);
    RegisterIndustryGRF(industry_newgrf);
    MapPreprocess();

    // Town eligibility statuses
function IndustryConstructor::FillCash() {
    if(GSCompany.GetBankBalance(company_id) < 20000000) {
        GSCompany.ChangeBankBalance(company_id, 1000000000, GSCompany.EXPENSES_OTHER);
    }
}

function IndustryConstructor::Build(industry_id, tile_index) {
    FillCash();
    local mode = GSCompanyMode(company_id);
    local build_status = false;
    // Shores are wierd. Industries are built from their top left corner; but a shore industry also has to touch land on one side
    // Without better knowledge of geometry, we'll just spam build in a 6x6 region up and to the left of the desired tile
    if(industry_classes.GetValue(industry_id) == 2) {
        local top_corner = GSMap.GetTileIndex(max(GSMap.GetTileX(tile_index) - 6, 1),
                                              max(GSMap.GetTileY(tile_index) - 6, 1));
        local build_zone = GSTileList();
        build_zone.AddRectangle(top_corner, tile_index);
        foreach(tile_id, value in build_zone) {
            build_status = GSIndustryType.BuildIndustry(industry_id, tile_id);
            if(build_status) {
                return build_status;
            }
        }
        return false;
    }
    return GSIndustryType.BuildIndustry(industry_id, tile_index);
}

function IndustryConstructor::InitializeTowns() {
    town_eligibility_default.Valuate(Id)
    town_eligibility_water.Valuate(Id);
    town_eligibility_shore.Valuate(Id);
    town_eligibility_townbldg.Valuate(Id);
    town_eligibility_neartown.Valuate(Id);
    town_eligibility_nondesert.Valuate(Id);
    town_eligibility_nonsnow.Valuate(Id);
    town_eligibility_nonsnowdesert.Valuate(Id);
    town_industry_counts.Valuate(Zero);
}

function IndustryConstructor::InitializeClusterMap() {
    cluster_eligibility_water.AddList(outer_town_tiles);
    cluster_eligibility_water.KeepList(water_tiles);
    cluster_eligibility_nondesert.AddList(outer_town_tiles);
    cluster_eligibility_nondesert.KeepList(nondesert_tiles);
    cluster_eligibility_nonsnow.AddList(outer_town_tiles);
    cluster_eligibility_nonsnow.KeepList(nonsnow_tiles);
    cluster_eligibility_nonsnowdesert.AddList(outer_town_tiles);
    cluster_eligibility_nonsnowdesert.KeepList(nondesert_tiles);
    cluster_eligibility_nonsnowdesert.KeepList(nonsnow_tiles);
    cluster_eligibility_land.AddList(outer_town_tiles);
    cluster_eligibility_land.KeepList(land_tiles);
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
            land_tiles.AddList(chunk_land);
            shore_tiles.AddList(chunk_shore);
            water_tiles.AddList(chunk_water);
            nondesert_tiles.AddList(chunk_nondesert);
            nonsnow_tiles.AddList(chunk_nonsnow);
            if(progress.Increment()) {
                Print(progress);
            }
        }
    }
    BuildEligibleTownTiles();
    Print("Land tile list size: " + land_tiles.Count());
    Print("Shore tile list size: " + shore_tiles.Count());
    Print("Water tile list size: " + water_tiles.Count());
    Print("Nondesert tile list size: " + nondesert_tiles.Count());
    Print("Nonsnow tile list size: " + nonsnow_tiles.Count());
    Print("Town tile list size: " + town_tiles.Count());
    Print("Outer town tile list size: " + outer_town_tiles.Count());
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
    local progress = ProgressReport(town_list.Count());
    foreach(town_id, tile_id in town_list) {
        core_town_tiles.AddList(RectangleAroundTile(tile_id, 4));
        local local_town_tiles = RectangleAroundTile(tile_id, town_radius);
        local distant_town_tiles = RectangleAroundTile(tile_id, town_long_radius);

        foreach(tile, value in distant_town_tiles) {
            if(local_town_tiles.HasItem(tile)) {
                outer_town_tiles.RemoveItem(tile);
                if(!town_tiles.HasItem(tile)) {
                    town_tiles.AddItem(tile, value);
                }
            } else {
                if(!outer_town_tiles.HasItem(tile) && !town_tiles.HasItem(tile)) {
                    outer_town_tiles.AddItem(tile, value);
                }
            }
        }
        if(progress.Increment()) {
            Print(progress);
        }
    }
    // Cull all outer town tiles that 'splashed' into nearby towns
    foreach(tile, value in outer_town_tiles) {
        if(town_tiles.HasItem(tile)) {
            outer_town_tiles.RemoveItem(tile);
        }
    }
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
        terrain_tiles.AddList(core_town_tiles);
        break;
    case "NearTown":
        terrain_tiles.AddList(town_tiles);
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
    outer_town_tiles.RemoveItem(tile_id);
    core_town_tiles.RemoveItem(tile_id);
}


// Check that the tile is sufficiently far from towns
// Two conditions:
// 1. Far enough from all 'big' towns.
// 2. Far enough from any town.
function IndustryConstructor::CloseToTown(tile_id) {

}
    // Checking nearest like this can have an issue in the pathological case
    // where the nearest town is small and it's 1 tile closer than the second-nearest town
    // A. nearest town small, slightly further town big - behavior is to accept cluster construction (incorrectly)
    // B. nearest town big, slightly further town small - behavior is to reject cluster construction (correctly)
    return (distanceToTown > large_town_spacing && population < large_town_cutoff);
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

function IndustryConstructor::ScatteredBuildMethod(industry_id) {
        }

        }
    }
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

}
