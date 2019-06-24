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



// Imports
import("util.superlib", "SuperLib", 36);
Result        <- SuperLib.Result;
Log        <- SuperLib.Log;
Helper        <- SuperLib.Helper;
ScoreList    <- SuperLib.ScoreList;
Tile        <- SuperLib.Tile;
Direction    <- SuperLib.Direction;
Town        <- SuperLib.Town;
Industry    <- SuperLib.Industry;

import("util.MinchinWeb", "MinchinWeb", 6);
SpiralWalker <- MinchinWeb.SpiralWalker;
// https://www.tt-forums.net/viewtopic.php?f=65&t=57903
// SpiralWalker - allows you to define a starting point and walks outward

// Extend GS class
class IndustryConstructor extends GSController {
    MAP_SIZE_X = 1.0;
    MAP_SIZE_Y = 1.0;
    MAP_SCALE = 1.0;

    BUILD_LIMIT = 0; // Set from settings, in class constructor and each refresh.(initial is max ind per map, subs is max per refresh)
    CONTINUE_GS = null; // True if whole script must continue.
    INIT_PERFORMED = false; // True if IndustryConstructor.Init has run.
    LOAD_PERFORMED = false; // Bool of load status
    FIRSTBUILD_PERFORMED = null; // True if IndustryConstructor.Load OR IndustryConstructor.BuildIndustryClass has run.
    PRIMARY_PERFORMED = null; // True if IndustryConstructor.BuildIndustryClass has run for primary industries.
    SECONDARY_PERFORMED = null; // True if IndustryConstructor.BuildIndustryClass has run for secondary industries.
    TERTIARY_PERFORMED = null; // True if IndustryConstructor.BuildIndustryClass has run for tertiary industries.
    SPECIAL_PERFORMED = null; // True if IndustryConstructor.BuildIndustryClass has run for special industries.
    BUILD_SPEED = 0; // Global build speed variable

    CLUSTERNODE_LIST_IND = []; // Sub-array of industry types, for cluster builder
    CLUSTERNODE_LIST_COUNT = []; // Sub-array of industry count, for cluster builder
    CLUSTERTILE_LIST = []; // Sub-array of node tiles, must be used with above 2D

    TOWNNODE_LIST_TOWN = []; // Sub-array of town ids registered
    TOWNNODE_LIST_IND = []; // Sub-array of industry types, for town builder
    TOWNNODE_LIST_COUNT = []; // Sub-array of industry count, for town builder

    IND_TYPE_LIST = 0; // Is GSIndustryTypeList(), set in IndustryConstructor.Init.
    IND_TYPE_COUNT = 0; // Count of industries in this.IND_TYPE_LIST, set in IndustryConstructor.Init.
    CARGO_PAXID = 0; // Passenger cargo ID, set in IndustryConstructor.Init.

    RAWINDUSTRY_LIST = []; // Array of raw industry type ID's, set in IndustryConstructor.Init.
    RAWINDUSTRY_LIST_COUNT = 0; // Count of primary industries, set in IndustryConstructor.Init.
    PROCINDUSTRY_LIST = []; // Array of processor industry type ID's, set in IndustryConstructor.Init.
    PROCINDUSTRY_LIST_COUNT = 0; // Count of secondary industries, set in IndustryConstructor.Init.
    TERTIARYINDUSTRY_LIST = []; // Array of tertiary industry type ID's, set in IndustryConstructor.Init.
    TERTIARYINDUSTRY_LIST_COUNT = 0; // Count of tertiary industries, set in IndustryConstructor.Init.
    SPECIALINDUSTRY_LIST = []; // Array of special industry type ID's, set in IndustryConstructor.Init.
    SPECIALINDUSTRY_LIST_COUNT = 0; // Count of special industries, set in IndustryConstructor.Init.
    SPECIALINDUSTRY_TYPES = ["Bank", "Oil Rig", "Water Tower", "Lumber Mill"];

    // User variables
    DENSITY_IND_TOTAL = 0; // Set from settings, in IndustryConstructor.Init. Total industries, integer always >= 1
    DENSITY_IND_MIN = 0; // Set from settings, in IndustryConstructor. Init.Min industry density %, float always < 1.
    DENSITY_IND_MAX = 0; // Set from settings, in IndustryConstructor.Init. Max industry density %, float always > 1.
    DENSITY_RAW_PROP = 0; // Set from settings, in IndustryConstructor.Init. Primary industry proportion, float always < 1.
    DENSITY_PROC_PROP = 0; // Set from settings, in IndustryConstructor.Init. Secondary industry proportion, float always < 1.
    DENSITY_TERT_PROP = 0; // Set from settings, in IndustryConstructor.Init. Tertiary industry proportion, float always < 1.
    DENSITY_SPEC_PROP = 0; // Set from settings, in IndustryConstructor.Init. Special industry proportion, float always < 1.
    DENSITY_RAW_METHOD = 0; // Set from settings, in IndustryConstructor.Init.
    DENSITY_PROC_METHOD = 0; // Set from settings, in IndustryConstructor.Init.
    DENSITY_TERT_METHOD = 0; // Set from settings, in IndustryConstructor.Init.

    constructor() {
        LOAD_PERFORMED = false;
        INIT_PERFORMED = false;
        CONTINUE_GS = true;
        MAP_SIZE_X = GSMap.GetMapSizeX();
        MAP_SIZE_Y = GSMap.GetMapSizeY();
        BUILD_LIMIT = GSController.GetSetting("BUILD_LIMIT");
        FIRSTBUILD_PERFORMED = false;
        PRIMARY_PERFORMED = false;
        SECONDARY_PERFORMED = false;
        TERTIARY_PERFORMED = false;
        SPECIAL_PERFORMED = false;

        // Create a new industry type list
        IND_TYPE_LIST = GSIndustryTypeList();
        // Count industry types
        IND_TYPE_COUNT = IND_TYPE_LIST.Count();
    }
}

// Save function
function IndustryConstructor::Save() {
    //Display save msg
    Log.Info("+==============================+", Log.LVL_INFO);
    Log.Info("Saving data", Log.LVL_INFO);

    // Create the save data table
    local SV_DATA = {
        //SV_IND_TYPE_LIST = IND_TYPE_LIST
        SV_RAW = RAWINDUSTRY_LIST,
        SV_PROC = PROCINDUSTRY_LIST,
        SV_TERT = TERTIARYINDUSTRY_LIST,
        SV_SPECIAL = SPECIALINDUSTRY_LIST,
        SV_CLUSTERNODE_IND = CLUSTERNODE_LIST_IND,
        SV_CLUSTERNODE_COUNT = CLUSTERNODE_LIST_COUNT,
        SV_CLUSTERTILES = CLUSTERTILE_LIST,
        SV_TOWNNODE_TOWN = TOWNNODE_LIST_TOWN,
        SV_TOWNNODE_IND = TOWNNODE_LIST_IND,
        SV_TOWNNODE_COUNT = TOWNNODE_LIST_COUNT
    };

    // Return save data to call
    this.ErrorHandler();
    return SV_DATA;
}

// Load function
function IndustryConstructor::Load(SV_VERSION, SV_TABLE) {
    // Display load msg
    Log.Info("+==============================+", Log.LVL_INFO);
    Log.Info("Loading data, saved with version " + SV_VERSION + " of game script", Log.LVL_INFO);

    // Loop through save table
    foreach(SV_KEY, SV_VAL in SV_TABLE) {
        if(SV_KEY == "SV_IND_TYPE_LIST") IND_TYPE_LIST = SV_VAL;
        if(SV_KEY == "SV_RAW") RAWINDUSTRY_LIST = SV_VAL;
        if(SV_KEY == "SV_PROC") PROCINDUSTRY_LIST = SV_VAL;
        if(SV_KEY == "SV_TERT") TERTIARYINDUSTRY_LIST = SV_VAL;
        if(SV_KEY == "SV_SPECIAL") SPECIALINDUSTRY_LIST = SV_VAL;
        if(SV_KEY == "SV_CLUSTERNODE_IND") CLUSTERNODE_LIST_IND = SV_VAL;
        if(SV_KEY == "SV_CLUSTERNODE_COUNT") CLUSTERNODE_LIST_COUNT = SV_VAL;
        if(SV_KEY == "SV_CLUSTERTILES") CLUSTERTILE_LIST = SV_VAL;
        if(SV_KEY == "SV_TOWNNODE_TOWN") TOWNNODE_LIST_TOWN = SV_VAL;
        if(SV_KEY == "SV_TOWNNODE_IND") TOWNNODE_LIST_IND = SV_VAL;
        if(SV_KEY == "SV_TOWNNODE_COUNT") TOWNNODE_LIST_COUNT = SV_VAL;
    }
    // Update load status
    LOAD_PERFORMED = true;
    FIRSTBUILD_PERFORMED = true;
    this.ErrorHandler();
}

// Program start function
function IndustryConstructor::Start() {
    this.Init();
    this.BuildIndustry();
    this.ErrorHandler();
}

// Initialization function
function IndustryConstructor::Init() {
    // Check GS continue
    if(CONTINUE_GS == false) return;

    // Display status msg
    Log.Info("+==============================+", Log.LVL_INFO);
    Log.Info("Initializing...", Log.LVL_INFO);

    // Set Advanced Setting parameters
    // - Check for multi ind per town setting
    // - - Check if valid
    if(GSGameSettings.IsValid("multiple_industry_per_town") == true) {
        // - - Set to one in parameters
        GSGameSettings.SetValue("multiple_industry_per_town", GSController.GetSetting("MULTI_IND_TOWN"));
        // - - Check if false
        if(GSGameSettings.GetValue("multiple_industry_per_town") == 0) Log.Warning("Multiple industries per town disabled, will slow down or prevent some build methods!", Log.LVL_INFO);
    }
    // -- Else invalid
    else Log.Error("Multiple industries per town setting could not be detected!", Log.LVL_INFO);
    // - Check for oil ind distance setting
    // - - Check if valid
    if(GSGameSettings.IsValid("oil_refinery_limit") == true) {
        // - - Set to one in parameters
        GSGameSettings.SetValue("oil_refinery_limit", GSController.GetSetting("MAX_OIL_DIST"));
        }
    // -- Else invalid
    else Log.Error("Max distance from edge for Oil Refineries setting could not be detected!", Log.LVL_INFO);

    // Assign PAX cargo id
    // - Create cargo list
    local CARGO_LIST = GSCargoList();
    // - Loop for each cargo
    foreach (CARGO_ID in CARGO_LIST) {
        // - Assign passenger cargo ID
        if(GSCargo.GetTownEffect(CARGO_ID) == GSCargo.TE_PASSENGERS) CARGO_PAXID = CARGO_ID;
    }

    // If load has not happened, then this is a new game
    if (this.LOAD_PERFORMED == false) {
        // Display status msg
        Log.Info(">This is a new game, preparing...", Log.LVL_INFO);

        // Check if there are industries on map (if user has not set to funding only error...)
        // Define new industry list
        local IND_LIST = GSIndustryList();
        // Count industries
        local IND_LIST_COUNT = IND_LIST.Count();

        // If there are industries on the map
        if (IND_LIST_COUNT > 0) {
            // Display error msg
            Log.Warning(">There are " + IND_LIST_COUNT + " industries on the map, when there must be none!", Log.LVL_INFO);

            // Set GS continue to false
            CONTINUE_GS = false;

            // End function
            return;
        }
        // Else no industries
        else {
            local IS_SPECIAL = false;
            local IND_NAME = "";
            // Display status msg
            Log.Info(">There are " + IND_TYPE_COUNT + " industry types.", Log.LVL_INFO);

            // Loop through list
            foreach(IND_ID, _ in IND_TYPE_LIST) {
                // Get current ID name
                IND_NAME = GSIndustryType.GetName(IND_ID);

                // Loop through special list
                foreach(SPECIAL_NAME in SPECIALINDUSTRY_TYPES) {
                    // If current ID name is a special = SPECIALINDUSTRY_LIST
                    if(IND_NAME == SPECIAL_NAME) {
                        // Display industry type name msg
                        Log.Info(" ~Special Industry: " + IND_NAME, Log.LVL_SUB_DECISIONS);

                        // Add industry id to raw list
                        SPECIALINDUSTRY_LIST.push(IND_ID);

                        // Assign true and end loop
                        IS_SPECIAL = true;
                        break;
                    }
                }

                // If the current ID was special
                if(IS_SPECIAL == true) {
                    // Reset and jump to next id
                    IS_SPECIAL = false;
                    continue;
                }

                // If current ID is a raw producer = RAWINDUSTRY_LIST
                if (GSIndustryType.IsRawIndustry(IND_ID)) {
                    // Display industry type name msg
                    Log.Info(" ~Raw Industry: " + IND_NAME, Log.LVL_SUB_DECISIONS);

                    // Add industry id to raw list
                    RAWINDUSTRY_LIST.push(IND_ID);
                }
                //else not a raw producer
                else {
                    // If current ID is a processor = PROCINDUSTRY_LIST
                    if (GSIndustryType.IsProcessingIndustry(IND_ID)) {
                        // Display industry type name msg
                        Log.Info(" ~Processor Industry: " + IND_NAME, Log.LVL_SUB_DECISIONS);

                        // Add industry id to processor list
                        PROCINDUSTRY_LIST.push(IND_ID);
                    }
                    // Else is an other industry = TERTIARYINDUSTRY_LIST
                    else {
                        // Display industry type name msg
                        Log.Info(" ~Tertiary Industry: " + IND_NAME, Log.LVL_SUB_DECISIONS);

                        // Add industry id to other list
                        TERTIARYINDUSTRY_LIST.push(IND_ID);
                    }
                }
            }
        }
    }
    // Else not a new game
    else {
        // Display status msg
        Log.Info(">This is a loaded game, preparing...", Log.LVL_INFO);
    }

    // Count lists
    RAWINDUSTRY_LIST_COUNT = RAWINDUSTRY_LIST.len();
    PROCINDUSTRY_LIST_COUNT = PROCINDUSTRY_LIST.len();
    TERTIARYINDUSTRY_LIST_COUNT = TERTIARYINDUSTRY_LIST.len();
    SPECIALINDUSTRY_LIST_COUNT = SPECIALINDUSTRY_LIST.len();

    // Display statuses
    Log.Info(">There are " + RAWINDUSTRY_LIST_COUNT + " Primary industry types.", Log.LVL_INFO);
    Log.Info(">There are " + PROCINDUSTRY_LIST_COUNT + " Secondary industry types.", Log.LVL_INFO);
    Log.Info(">There are " + TERTIARYINDUSTRY_LIST_COUNT + " Tertiary industry types.", Log.LVL_INFO);
    Log.Info(">There are " + SPECIALINDUSTRY_LIST_COUNT + " Special industry types.", Log.LVL_INFO);

    // Import settings
    // - Determine map multiplier, as float
    MAP_SCALE = (MAP_SIZE_X / 256.0) * (MAP_SIZE_Y / 256.0)

    // - Display status msg
    Log.Info(">Map size scale is: " + MAP_SCALE, Log.LVL_INFO);

    // - Assign settings
    local RAW_PROP = GSController.GetSetting("DENSITY_RAW_PROP").tofloat();
        if(RAWINDUSTRY_LIST_COUNT < 1) RAW_PROP = 0.0;
    local PROC_PROP = GSController.GetSetting("DENSITY_PROC_PROP").tofloat();
        if(PROCINDUSTRY_LIST_COUNT < 1) PROC_PROP = 0.0;
    local TERT_PROP = GSController.GetSetting("DENSITY_TERT_PROP").tofloat();
        if(TERTIARYINDUSTRY_LIST_COUNT < 1) TERT_PROP = 0.0;
    local SPEC_PROP = GSController.GetSetting("DENSITY_SPEC_PROP").tofloat();
        if(SPECIALINDUSTRY_LIST_COUNT < 1) SPEC_PROP = 0.0;
    local TOTAL_PROP = RAW_PROP + PROC_PROP + TERT_PROP + SPEC_PROP;

    DENSITY_IND_TOTAL = (GSController.GetSetting("DENSITY_IND_TOTAL") * MAP_SCALE).tointeger();
        // Make 1 if below
    if (DENSITY_IND_TOTAL < 1) DENSITY_IND_TOTAL = 1;
    DENSITY_IND_MIN = GSController.GetSetting("DENSITY_IND_MIN").tofloat() / 100.0;
    DENSITY_IND_MAX = GSController.GetSetting("DENSITY_IND_MAX").tofloat() / 100.0;
    DENSITY_RAW_PROP = (GSController.GetSetting("DENSITY_RAW_PROP").tofloat() / TOTAL_PROP);
        if(RAWINDUSTRY_LIST_COUNT < 1) DENSITY_RAW_PROP = 0;
    DENSITY_PROC_PROP = (GSController.GetSetting("DENSITY_PROC_PROP").tofloat() / TOTAL_PROP);
        if(PROCINDUSTRY_LIST_COUNT < 1) DENSITY_PROC_PROP = 0;
    DENSITY_TERT_PROP = (GSController.GetSetting("DENSITY_TERT_PROP").tofloat() / TOTAL_PROP);
        if(TERTIARYINDUSTRY_LIST_COUNT < 1) DENSITY_TERT_PROP = 0;
    DENSITY_SPEC_PROP = (GSController.GetSetting("DENSITY_SPEC_PROP").tofloat() / TOTAL_PROP);
        if(SPECIALINDUSTRY_LIST_COUNT < 1) DENSITY_SPEC_PROP = 0;
    DENSITY_RAW_METHOD = GSController.GetSetting("DENSITY_RAW_METHOD");
    DENSITY_PROC_METHOD = GSController.GetSetting("DENSITY_PROC_METHOD");
    DENSITY_TERT_METHOD = GSController.GetSetting("DENSITY_TERT_METHOD");

    // - Display status msgs
    Log.Info(">Total industries assigned: " + DENSITY_IND_TOTAL, Log.LVL_SUB_DECISIONS);
    Log.Info(">Min per industry assigned: " + DENSITY_IND_MIN, Log.LVL_SUB_DECISIONS);
    Log.Info(">Max per industry assigned: " + DENSITY_IND_MAX, Log.LVL_SUB_DECISIONS);
    Log.Info(">Primary industry proportion assigned: " + DENSITY_RAW_PROP, Log.LVL_SUB_DECISIONS);
    Log.Info(">Secondary industry proportion assigned: " + DENSITY_PROC_PROP, Log.LVL_SUB_DECISIONS);
    Log.Info(">Tertiary industry proportion assigned: " + DENSITY_TERT_PROP, Log.LVL_SUB_DECISIONS);
    Log.Info(">Special industry proportion assigned: " + DENSITY_SPEC_PROP, Log.LVL_SUB_DECISIONS);
    Log.Info(">Primary industry method assigned: " + DENSITY_RAW_METHOD, Log.LVL_SUB_DECISIONS);
    Log.Info(">Secondary industry method assigned: " + DENSITY_PROC_METHOD, Log.LVL_SUB_DECISIONS);
    Log.Info(">Tertiary industry method assigned: " + DENSITY_TERT_METHOD, Log.LVL_SUB_DECISIONS);

    // Declare function status
    this.INIT_PERFORMED = true;
}

// Builds industries in the order of their IDs
function IndustryConstructor::BuildIndustry() {
    // Display status msg
    Log.Info("+==============================+", Log.LVL_INFO);
    Log.Info("Building industries...", Log.LVL_INFO);

    // Iterate through the list of all industries
    Log.Info(" ~Building " + BUILD_TARGET + " " + GSIndustryType.GetName(CURRENT_IND_ID), Log.LVL_SUB_DECISIONS);

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
                case 4:
                    // Increment count using special build
                    CURRENT_BUILD_COUNT += SpecialBuildMethod(CURRENT_IND_ID);
                    break;
            this.ErrorHandler();
            }
            // Display status
            Log.Info(" ~Built " + CURRENT_BUILD_COUNT + " / " + BUILD_TARGET, Log.LVL_SUB_DECISIONS);
        }
    }
}

// Special build method for special industries, uses "hard code" methods specific for each type
// return 1 if built and 0 if not
function IndustryConstructor::SpecialBuildMethod(INDUSTRY_ID) {
    // Switch ind id for each type, must be same as in SPECIALINDUSTRY_TYPES
    switch(GSIndustryType.GetName(INDUSTRY_ID)) {
        case SPECIALINDUSTRY_TYPES[0]:            // "Bank"
            // Check towns with pop > parameter
            // - Create town list
            local LOCAL_TOWN_LIST = GSTownList();
            // - Valuate by population
            LOCAL_TOWN_LIST.Valuate(GSTown.GetPopulation);
            // - Remove below parameter
            LOCAL_TOWN_LIST.RemoveBelowValue(GSController.GetSetting("SPEC_BANK_MINPOP"));

            // Check if valid
            if(LOCAL_TOWN_LIST.IsEmpty() == true) {
                Log.Warning(" ~IndustryConstructor.SpecialBuildMethod: No towns with more than " + GSController.GetSetting("SPEC_BANK_MINPOP") + " for Banks!", Log.LVL_SUB_DECISIONS);
                return 0;
            }
            // Try prospect
            if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
            break;
        case SPECIALINDUSTRY_TYPES[1]:            // "Oil Rig"
            // Check if current date is before param
            if(GSDate.GetCurrentDate() < GSDate.GetDate(GSController.GetSetting("SPEC_RIG_MINYEAR"), 1, 1)) {
                Log.Warning(" ~IndustryConstructor.SpecialBuildMethod: Year is less than " + GSController.GetSetting("SPEC_RIG_MINYEAR") + " for Oil Rig!", Log.LVL_SUB_DECISIONS);
                return 0;
            }
            // Try prospect
            if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
            break;
        case SPECIALINDUSTRY_TYPES[2]:            // "Water Tower"
            // Check towns with pop > parameter
            // - Create town list
            local LOCAL_TOWN_LIST = GSTownList();
            // - Valuate by population
            LOCAL_TOWN_LIST.Valuate(GSTown.GetPopulation);
            // - Remove below parameter
            LOCAL_TOWN_LIST.RemoveBelowValue(GSController.GetSetting("SPEC_WTR_MINPOP"));

            // Check if valid
            if(LOCAL_TOWN_LIST.IsEmpty() == true) {
                Log.Warning(" ~IndustryConstructor.SpecialBuildMethod: No towns with more than " + GSController.GetSetting("SPEC_WTR_MINPOP") + " for Water Towers!", Log.LVL_SUB_DECISIONS);
                return 0;
            }
            // Try prospect
            if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
            break;
        case SPECIALINDUSTRY_TYPES[3]:            // "Lumber Mill"
            // Check if must not build param
            if(GSController.GetSetting("SPEC_LBR_BOOL") == 0) return 0;
            // Try prospect
            if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
            break;
        default:
            // Display error
            Log.Error(" ~IndustryConstructor.SpecialBuildMethod: Industry " + GSIndustryType.GetName(INDUSTRY_ID) + " not supported!", Log.LVL_INFO);
    }
    return 0;
}

// Town build method function
// return 1 if built and 0 if not
function IndustryConstructor::TownBuildMethod(INDUSTRY_ID) {

    local ind_name = GSIndustryType.GetName(INDUSTRY_ID);

    // Assign and moderate map multiplier
    local MULTI = 1;
    if (MAP_SCALE <= MULTI)    MULTI = MAP_SCALE;

    // Create town list for townbuilder
    local LOCAL_TOWN_LIST = GSTownList();
    // Valuate by population
    LOCAL_TOWN_LIST.Valuate(GSTown.GetPopulation);
    // Remove below parameter
    LOCAL_TOWN_LIST.RemoveBelowValue(GSController.GetSetting("TOWN_MIN_POP"));

    // Check abnormal industries, for towns
    // - Oil Refinery
    if(IND_NAME == "Oil Refinery") {
        // - Check to rather prospect
        if(GSController.GetSetting("PROS_BOOL") == 1) {
            // Try prospect
            if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
            else return 0;
        }
        // - Check oil ind setting, and remove towns further from edge
        //   Mainly for speed purposes...
        if(GSGameSettings.IsValid("oil_refinery_limit") == true) {
            // Valuate by edge distance
            LOCAL_TOWN_LIST.Valuate(GetTownDistFromEdge);
            // Remove towns farther than max, including town radius
            local MAX_DIST = GSGameSettings.GetValue("oil_refinery_limit") + (GSController.GetSetting("TOWN_MAX_RADIUS") - 2)
            if(MAX_DIST < 0) MAX_DIST = 0;
            LOCAL_TOWN_LIST.RemoveAboveValue(MAX_DIST);
        }
    }
    // - Farm
    if(IND_NAME == "Farm") {
        // - Check climate
        local ISCLIMATE_ARCTIC = (GSGame.GetLandscape () == GSGame.LT_ARCTIC);
        if(ISCLIMATE_ARCTIC == true) {
            // - Check to rather prospect
            if(GSController.GetSetting("PROS_BOOL") == 1) { return GSIndustryType.ProspectIndustry(INDUSTRY_ID) ? 1 : 0; } // Try prospect
        }
    }
    // - Forest
    if(IND_NAME == "Forest") {
        // - Check climate
        if(ISCLIMATE_ARCTIC == true) {
            // - Check to rather prospect
            if(GSController.GetSetting("PROS_BOOL") == 1) { return GSIndustryType.ProspectIndustry(INDUSTRY_ID) ? 1 : 0; } // Try prospect
        }
    }
    // - Water Supply
    if(IND_NAME == "Water Supply") {
        // - Check climate
        local ISCLIMATE_TROPIC = (GSGame.GetLandscape () == GSGame.LT_TROPIC);
        if(ISCLIMATE_TROPIC == true) {
            // - Check to rather prospect
            if(GSController.GetSetting("PROS_BOOL") == 1) { return GSIndustryType.ProspectIndustry(INDUSTRY_ID) ? 1 : 0; } // Try prospect
        }
    }

    // Loop through town list arrays
    for(local i = 0; i < this.TOWNNODE_LIST_TOWN.len(); i++) {

        // Remove towns with ind ID in if TOWN_MULTI_BOOL
        // If - TOWN_MULTI_BOOL
        if(GSController.GetSetting("TOWN_MULTI_BOOL") == 0) {
            // - If current list id == ind id, remove town
            if(this.TOWNNODE_LIST_IND[i] == INDUSTRY_ID) LOCAL_TOWN_LIST.RemoveItem(this.TOWNNODE_LIST_TOWN[i])
        }

        // Remove towns with max
        // - If loop town count >= setting, remove from list
        if(this.TOWNNODE_LIST_COUNT[i] >= GSController.GetSetting("TOWN_MAX_IND")) LOCAL_TOWN_LIST.RemoveItem(this.TOWNNODE_LIST_TOWN[i])
    }

    // Check if the list is not empty
    if(LOCAL_TOWN_LIST.IsEmpty() == true) {
        Log.Error(" ~IndustryConstructor.TownBuildMethod: Town list is empty!", Log.LVL_INFO);
        return 0;
    }

    // Loop until tries are maxed (mainly debug)
    local BUILD_TRIES = LOCAL_TOWN_LIST.Count() * 3;
    while (BUILD_TRIES > 0) {

        // Get start ID
        local TOWN_ID = LOCAL_TOWN_LIST.Begin();
        // Get random ID
        for(local i = 0; i < GSBase.RandRange(LOCAL_TOWN_LIST.Count()); i++) {
            TOWN_ID = LOCAL_TOWN_LIST.Next();
        }
        // Debug msg
        Log.Info("   ~Trying to build in " + GSTown.GetName(TOWN_ID), Log.LVL_DEBUG);

        // Create list of town tiles
        //local TOWN_TILE_LIST = this.GetTownHouseList(TOWN_ID, CARGO_PAXID);
        //(2nd option)//local TOWN_TILE_LIST = Tile.GetTownTiles(TOWN_ID);
        local TOWN_RADIUS = (GSTown.GetHouseCount(TOWN_ID).tofloat() * (GSController.GetSetting("TOWN_MAX_RADIUS").tofloat() / 100.0)).tointeger();
        local TOWN_TILE_LIST = Tile.MakeTileRectAroundTile(GSTown.GetLocation(TOWN_ID),TOWN_RADIUS);
        // Debug msg
        Log.Info("   ~Got town tile list!", Log.LVL_DEBUG);

        // Get min/ max tiles
        local MIN_MAX_TILE_LIST = ListMinMaxXY(TOWN_TILE_LIST, true)
        // Debug msg
        Log.Info("   ~Got min/max tile list!", Log.LVL_DEBUG);

        // Create list for border tiles
        local BORDER_TILE_LIST = Tile.GrowTileRect(TOWN_TILE_LIST, GSController.GetSetting("TOWN_MAX_RADIUS"));
        // - Remove the town rectangle
        BORDER_TILE_LIST.RemoveRectangle(MIN_MAX_TILE_LIST.Begin(), MIN_MAX_TILE_LIST.Next());
        // Debug msg
        Log.Info("   ~Got border tile list!", Log.LVL_DEBUG);

        // Sort by random
        BORDER_TILE_LIST.Valuate(GSBase.RandItem);
        // Debug msg
        Log.Info("   ~Got random list!", Log.LVL_DEBUG);

        // Debug msg
        Log.Info("   ~Got tile list!", Log.LVL_DEBUG);

        // Loop for each tile in list
        local BORDER_TILE = null;
        local IND = null;
        local IND_DIST = 0;
        for(local i = 0; i < BORDER_TILE_LIST.Count(); i++) {

            // If first loop, start at beginning
            if(i == 0) BORDER_TILE = BORDER_TILE_LIST.Begin();
            // Else go to next
            else BORDER_TILE = BORDER_TILE_LIST.Next();

            // If invalid tile, reloop
            if(GSMap.IsValidTile(BORDER_TILE) == false) continue;

            // If water tile, reloop
            if(GSTile.IsWaterTile(BORDER_TILE) == true) continue;

            // Debug msg
            if(GSGameSettings.GetValue("log_level") >= 4)Log.Info(GSMap.IsValidTile(BORDER_TILE), Log.LVL_DEBUG);
            if(GSGameSettings.GetValue("log_level") >= 4) GSSign.BuildSign(BORDER_TILE, "Try")

            // Check abnormal industries
            local TILE_TERRAIN = GSTile.GetTerrainType(BORDER_TILE);
            // - Oil Refinery
            if(IND_NAME == "Oil Refinery") {
                // - Check oil ind setting, and compare to current tile and re loop if above
                if(GSGameSettings.IsValid("oil_refinery_limit") == true) if(GSMap.DistanceFromEdge(BORDER_TILE) > GSGameSettings.GetValue("oil_refinery_limit")) continue;
            }
            // - Farm
            if(IND_NAME == "Farm") {
                // - Check climate
                if(ISCLIMATE_ARCTIC == true) {
                    // - Check if tile is snow and re loop if true
                    if(TILE_TERRAIN == GSTile.TERRAIN_SNOW) continue;
                }
            }
            // - Forest
            if(IND_NAME == "Forest") {
                // - Check climate
                if(ISCLIMATE_ARCTIC == true) {
                    // - Check if tile is not snow and re loop if true
                    if(TILE_TERRAIN != GSTile.TERRAIN_SNOW) continue;
                }
            }

            //Check dist from ind
            // - Get industry
            IND = this.GetClosestIndustry(BORDER_TILE);
            // - If not null (null - no indusrties)
            if(IND != null) {
                // - Get distance
                IND_DIST = GSIndustry.GetDistanceManhattanToTile(IND,BORDER_TILE);
                // - If less than minimum, re loop
                if(IND_DIST < (GSController.GetSetting("TOWN_MIN_IND") * MULTI)) continue;
            }

            // Try build
            if(GSIndustryType.BuildIndustry(INDUSTRY_ID, BORDER_TILE) == true) {

                // Debug msg
                Log.Info("   ~Built!", Log.LVL_DEBUG);

                // Loop through town list arrays
                local EXIST_TOWN = false;
                for(local i = 0; i < TOWNNODE_LIST_TOWN.len(); i++) {
                    // If current town is in array
                    if(TOWNNODE_LIST_TOWN[i] == TOWN_ID) {
                        // Set bool
                        EXIST_TOWN = true;
                        // Inc count in array
                        TOWNNODE_LIST_COUNT[i]++
                        // Set ind in array
                        TOWNNODE_LIST_IND[i] = INDUSTRY_ID;
                    }
                }

                // If town was not in array
                if(EXIST_TOWN == false) {
                    // Add town to array
                    TOWNNODE_LIST_TOWN.push(TOWN_ID);
                    // Add ind id to array
                    TOWNNODE_LIST_IND.push(INDUSTRY_ID);
                    // Add count to array
                    TOWNNODE_LIST_COUNT.push(1);
                }
                return 1;
            }
        }

        // Dec tries
        BUILD_TRIES--
    }
    // Display error msg
    Log.Error("IndustryConstructor.TownBuildMethod: Couldn't find a valid tile to set node on!", Log.LVL_INFO)
    return 0;
}

// Cluster build method function (2), return 1 if built and 0 if not
function IndustryConstructor::ClusterBuildMethod(INDUSTRY_ID) {

    // Variables
    local IND_NAME = GSIndustryType.GetName(INDUSTRY_ID)            // Industry name string
    local LIST_VALUE = 0; // The point on the list surrently, to synchronise between lists
    local NODE_TILE = null;
    local MULTI = 0;
    local IND = null;
    local IND_DIST = 0;

    // Check if industry is not buildable
    if(!GSIndustryType.CanBuildIndustry(INDUSTRY_ID)) {
        // Display error
        Log.Error(" ~IndustryConstructor.ClusterBuildMethod: Industry not buildable!", Log.LVL_INFO);
        return 0;
    }

    // Assign and moderate map multiplier
    if(MAP_SCALE > 1) MULTI = 1;
    else MULTI = MAP_SCALE;

    // Find if node exists already
    // - Check if node list has entries
    //Log.Info("Node list length: " + CLUSTERNODE_LIST_IND.len(), Log.LVL_INFO)
    if (CLUSTERNODE_LIST_IND.len() > 0) {
        // - Loop through node list
        for(local i = 0; i < CLUSTERNODE_LIST_IND.len(); i++) {
            // - If node for industry exists
            if(CLUSTERNODE_LIST_IND[i] == INDUSTRY_ID) {
                // - If industry count is less than or equal to global, node tile is that tile
                if(CLUSTERNODE_LIST_COUNT[i] < GSController.GetSetting("CLUSTER_NODES")) {
                    // Set node tile
                    NODE_TILE = CLUSTERTILE_LIST[i];
                    // Display status msg
                    //Log.Info("Using existing node: " + GSMap.IsValidTile(NODE_TILE), Log.LVL_INFO)
                    // Inc list counter
                    LIST_VALUE = i;
                    break;
                }
            }
        }
    }
    // If node tile doesn't exist then get one
    if(NODE_TILE == null)
    {
        //Display status msg
        //Log.Info("Finding new node", Log.LVL_INFO)
        local SEARCH_TRIES = ((256 * 256 * 3) * MAP_SCALE);
        local NODEMATCH = false;
        local NODEGOT = false;
        // Loop until suitable node
        while(SEARCH_TRIES > 0 && NODEGOT == false) {

            // Increment and check counter
            SEARCH_TRIES--
            if(SEARCH_TRIES == ((256 * 256 * 2.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Search tries left: " + SEARCH_TRIES, Log.LVL_INFO);
            if(SEARCH_TRIES == ((256 * 256 * 1.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Search tries left: " + SEARCH_TRIES, Log.LVL_INFO);
            if(SEARCH_TRIES == ((256 * 256 * 0.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Search tries left: " + SEARCH_TRIES, Log.LVL_INFO);
            if(SEARCH_TRIES == 0) {
                Log.Error("IndustryConstructor.ClusterBuildMethod: Couldn't find a valid tile to set node on!", Log.LVL_INFO)
                return 0
            }
            // Get a random tile
            NODE_TILE = Tile.GetRandomTile();

            // Is buildable
            if(GSTile.IsBuildable(NODE_TILE) == false) continue;

            // Check abnormal industries
            // - Oil Refinery
            if(IND_NAME == "Oil Refinery") {
                // - Check to rather prospect
                if(GSController.GetSetting("PROS_BOOL") == 1) {
                    // Try prospect
                    if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                    else return 0;
                }
                // - Check oil ind setting, and compare to current tile and re loop if above
                if(GSGameSettings.IsValid("oil_refinery_limit") == true) if(GSMap.DistanceFromEdge(BORDER_TILE) > GSGameSettings.GetValue("oil_refinery_limit")) continue;
            }
            // - Farm
            if(IND_NAME == "Farm") {
                // - Check climate
                if(GSGame.GetLandscape () == GSGame.LT_ARCTIC) {
                    // - Check to rather prospect
                    if(GSController.GetSetting("PROS_BOOL") == 1) {
                        // Try prospect
                        if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                        else return 0;
                    }
                    // - Check if tile is snow and re loop if true
                    if(GSTile.GetTerrainType(NODE_TILE) == GSTile.TERRAIN_SNOW) continue;
                }
            }
            // - Forest
            if(IND_NAME == "Forest") {
                // - Check climate
                if(GSGame.GetLandscape () == GSGame.LT_ARCTIC) {
                    // - Check to rather prospect
                    if(GSController.GetSetting("PROS_BOOL") == 1) {
                        // Try prospect
                        if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                        else return 0;
                    }
                    // - Check if tile is not snow and re loop if true
                    if(GSTile.GetTerrainType(NODE_TILE) != GSTile.TERRAIN_SNOW) continue;
                }
            }
            // - Water Supply
            if(IND_NAME == "Water Supply") {
                // - Check climate
                if(GSGame.GetLandscape () == GSGame.LT_TROPIC) {
                    // - Check to rather prospect
                    if(GSController.GetSetting("PROS_BOOL") == 1) {
                        // Try prospect
                        if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                        else return 0;
                    }
                    // - Check if tile is not desert and re loop if true
                    if(GSTile.GetTerrainType(NODE_TILE) != GSTile.TERRAIN_DESERT) continue;
                }
            }

            // Check dist from edge
            //if(GSMap.DistanceFromEdge(NODE_TILE) < (GSController.GetSetting("CLUSTER_MIN_EDGE") * MULTI)) continue;

            // Check dist from town
            local TOWN_DIST = 0;
            // - Get distance to town
            TOWN_DIST = GSTown.GetDistanceManhattanToTile(GSTile.GetClosestTown(NODE_TILE),NODE_TILE);
            // - If less than minimum, re loop
            if(TOWN_DIST < (GSController.GetSetting("CLUSTER_MIN_TOWN") * MULTI)) continue;

            //Check dist from ind
            // - Get industry
            IND = this.GetClosestIndustry(NODE_TILE);
            // - If not null (null - no indusrties)
            if(IND != null) {
                // - Get distance
                IND_DIST = GSIndustry.GetDistanceManhattanToTile(IND,NODE_TILE);
                // - If less than minimum, re loop
                if(IND_DIST < (GSController.GetSetting("CLUSTER_MIN_IND") * MULTI)) continue;
            }

            // Check dist from other clusters
            NODEMATCH = false;
            // - Check if node list has entries
            if (CLUSTERNODE_LIST_IND.len() > 0) {
            //    // - Loop through node list
                for(local i = 0; i < CLUSTERTILE_LIST.len(); i++) {
            //        // - If below min dist, then set match and end
                    if(GSTile.GetDistanceManhattanToTile(NODE_TILE,CLUSTERTILE_LIST[i]) < GSController.GetSetting("CLUSTER_MIN_NODE")) {
                        NODEMATCH = true;
                        break;
                    }
                }
            }
            // - Check if match, and continue if true
            if(NODEMATCH == true) continue;
        //    Log.Info("node fine", Log.LVL_INFO)

            // Add to node list
            CLUSTERNODE_LIST_IND.push(INDUSTRY_ID);
            CLUSTERNODE_LIST_COUNT.push(0);
            CLUSTERTILE_LIST.push(NODE_TILE);
            LIST_VALUE = CLUSTERTILE_LIST.len() - 1;
            NODEGOT = true;
        }
    }
    // Get tile to build industry on
    local TILE_ID = null;
    // Build tries defines the area to build on, and the first try is the first node. Therefore the tries should be the square of
    // the max distance parameter times the number of industries.
    local BUILD_TRIES = (GSController.GetSetting("CLUSTER_RADIUS_MAX") * GSController.GetSetting("CLUSTER_RADIUS_MAX") * GSController.GetSetting("CLUSTER_NODES")).tointeger();
    //Log.Info("Build tries: " + BUILD_TRIES, Log.LVL_INFO)
    // - Create spiral walker
    local SPIRAL_WALKER = SpiralWalker();
    // - Set spiral walker on node tile
    SPIRAL_WALKER.Start(NODE_TILE);
    // Debug sign
    if(GSGameSettings.GetValue("log_level") >= 4) GSSign.BuildSign(NODE_TILE,"Node tile: " + GSIndustryType.GetName (INDUSTRY_ID));

    // Loop till built
    while(BUILD_TRIES > 0) {

        // Walk one tile
        SPIRAL_WALKER.Walk();
        // Get tile
        TILE_ID = SPIRAL_WALKER.GetTile();

        // Check dist from ind
        // - Get industry
        IND = this.GetClosestIndustry(TILE_ID);
        // - If not null (null - no indusrties)
        if(IND != null) {
            // - Get distance
            IND_DIST = GSIndustry.GetDistanceManhattanToTile(IND,TILE_ID);
            // - If less than minimum, re loop
            if(IND_DIST < (GSController.GetSetting("CLUSTER_RADIUS_MIN") * MULTI)) continue;
            // - If more than maximum, re loop
            //if(IND_DIST > (GSController.GetSetting("CLUSTER_RADIUS_MAX") * MULTI)) continue;
        }

        // Try build
        if (GSIndustryType.BuildIndustry(INDUSTRY_ID, TILE_ID) == true) {
            CLUSTERNODE_LIST_COUNT[LIST_VALUE]++
            return 1;
        }

        // Increment and check counter
        BUILD_TRIES--
        if(BUILD_TRIES == ((256 * 256 * 2.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == ((256 * 256 * 1.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == ((256 * 256 * 0.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == 0) {
            Log.Error("IndustryConstructor.ClusterBuildMethod: Couldn't find a valid tile to build on!", Log.LVL_INFO)
        }
    }
    Log.Error("IndustryConstructor.ClusterBuildMethod: Build failed!", Log.LVL_INFO)
    return 0;
}

// Scattered build method function (3), return 1 if built and 0 if not
function IndustryConstructor::ScatteredBuildMethod(INDUSTRY_ID) {
    local IND_NAME = GSIndustryType.GetName(INDUSTRY_ID); // Industry name string
    local TILE_ID = null;
    local BUILD_TRIES = ((256 * 256 * 3) * MAP_SCALE).tointeger();
    local TOWN_DIST = 0;
    local IND = null;
    local IND_DIST = 0;
    local MULTI = 0;

    // Check if industry is not buildable
    if(!GSIndustryType.CanBuildIndustry(INDUSTRY_ID)) {
        // Display error
        Log.Error(" ~Industry not buildable!", Log.LVL_INFO);
        return 0;
    }

    // Assign and moderate map multiplier
    if(MAP_SCALE > 1) MULTI = 1;
    else MULTI = MAP_SCALE;

    // Loop until correct tile
    while(BUILD_TRIES > 0) {
        // Get a random tile
        TILE_ID = Tile.GetRandomTile();

        // Check abnormal industries
        // - Oil Refinery
        if(IND_NAME == "Oil Refinery") {
            // - Check to rather prospect
            if(GSController.GetSetting("PROS_BOOL") == 1) {
                // Try prospect
                if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                else return 0;
            }
            // - Check oil ind setting, and compare to current tile and re loop if above
                if(GSGameSettings.IsValid("oil_refinery_limit") == true) if(GSMap.DistanceFromEdge(BORDER_TILE) > GSGameSettings.GetValue("oil_refinery_limit")) continue;
        }
        // - Farm
        if(IND_NAME == "Farm") {
            // - Check climate
            if(GSGame.GetLandscape () == GSGame.LT_ARCTIC) {
                // - Check to rather prospect
                if(GSController.GetSetting("PROS_BOOL") == 1) {
                    // Try prospect
                    if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                    else return 0;
                }
                // - Check if tile is snow and re loop if true
                if(GSTile.GetTerrainType(TILE_ID) == GSTile.TERRAIN_SNOW) continue;
            }
        }
        // - Forest
        if(IND_NAME == "Forest") {
            // - Check climate
            if(GSGame.GetLandscape () == GSGame.LT_ARCTIC) {
                // - Check to rather prospect
                if(GSController.GetSetting("PROS_BOOL") == 1) {
                    // Try prospect
                    if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                    else return 0;
                }
                // - Check if tile is not snow and re loop if true
                if(GSTile.GetTerrainType(TILE_ID) != GSTile.TERRAIN_SNOW) continue;
            }
        }
        // - Water Supply
        if(IND_NAME == "Water Supply") {
            // - Check climate
            if(GSGame.GetLandscape () == GSGame.LT_TROPIC) {
                // - Check to rather prospect
                if(GSController.GetSetting("PROS_BOOL") == 1) {
                    // Try prospect
                    if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                    else return 0;
                }
                // - Check if tile is not desert and re loop if true
                if(GSTile.GetTerrainType(TILE_ID) != GSTile.TERRAIN_DESERT) continue;
            }
        }

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
        if (GSIndustryType.BuildIndustry(INDUSTRY_ID, TILE_ID) == true) return 1;

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

// Random build method function (4), return 1 if built and 0 if not
function IndustryConstructor::RandomBuildMethod(INDUSTRY_ID) {

    local IND_NAME = GSIndustryType.GetName(INDUSTRY_ID); // Industry name string
    local TILE_ID = null;
    local BUILD_TRIES = ((256 * 256 * 2) * MAP_SCALE).tointeger();

    //Check if industry is not buildable
    if(!GSIndustryType.CanBuildIndustry(INDUSTRY_ID)) {
        // Display error
        Log.Error(" ~Industry not buildable!", Log.LVL_INFO);
        return 0;
    }

    // Loop until correct tile
    while(BUILD_TRIES > 0) {
        // Get a random tile
        TILE_ID = Tile.GetRandomTile();

        // Check abnormal industries
        // - Oil Refinery
        if(IND_NAME == "Oil Refinery") {
            // - Check to rather prospect
            if(GSController.GetSetting("PROS_BOOL") == 1) {
                // Try prospect
                if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                else return 0;
            }
            // - Check oil ind setting, and compare to current tile and re loop if above
                if(GSGameSettings.IsValid("oil_refinery_limit") == true) if(GSMap.DistanceFromEdge(TILE_ID) > GSGameSettings.GetValue("oil_refinery_limit")) continue;
        }
        // - Farm
        if(IND_NAME == "Farm") {
            // - Check climate
            if(GSGame.GetLandscape () == GSGame.LT_ARCTIC) {
                // - Check to rather prospect
                if(GSController.GetSetting("PROS_BOOL") == 1) {
                    // Try prospect
                    if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                    else return 0;
                }
                // - Check if tile is snow and re loop if true
                if(GSTile.GetTerrainType(TILE_ID) == GSTile.TERRAIN_SNOW) continue;
            }
        }
        // - Forest
        if(IND_NAME == "Forest") {
            // - Check climate
            if(GSGame.GetLandscape () == GSGame.LT_ARCTIC) {
                // - Check to rather prospect
                if(GSController.GetSetting("PROS_BOOL") == 1) {
                    // Try prospect
                    if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                    else return 0;
                }
                // - Check if tile is not snow and re loop if true
                if(GSTile.GetTerrainType(TILE_ID) != GSTile.TERRAIN_SNOW) continue;
            }
        }
        // - Water Supply
        if(IND_NAME == "Water Supply") {
            // - Check climate
            if(GSGame.GetLandscape () == GSGame.LT_TROPIC) {
                // - Check to rather prospect
                if(GSController.GetSetting("PROS_BOOL") == 1) {
                    // Try prospect
                    if(GSIndustryType.ProspectIndustry (INDUSTRY_ID) == true) return 1;
                    else return 0;
                }
                // - Check if tile is not desert and re loop if true
                if(GSTile.GetTerrainType(TILE_ID) != GSTile.TERRAIN_DESERT) continue;
            }
        }

        // Try build
        if (GSIndustryType.BuildIndustry(INDUSTRY_ID, TILE_ID) == true) return 1;

        // Increment and check counter
        BUILD_TRIES--
        if(BUILD_TRIES == ((256 * 256 * 1.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == ((256 * 256 * 1.0) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == ((256 * 256 * 0.5) * MAP_SCALE).tointeger()) Log.Warning(" ~Tries left: " + BUILD_TRIES, Log.LVL_INFO);
        if(BUILD_TRIES == 0) {
            Log.Error("IndustryConstructor.RandomBuildMethod: Couldn't find a valid tile!", Log.LVL_INFO);
        }
    }
    Log.Error("IndustryConstructor.RandomBuildMethod: Build failed!", Log.LVL_INFO);
    return 0;
}

// NOTE: Has to be called from the HandleEvents of main.
function IndustryConstructor::HandleEvents() {
    // Check GS continue
    if(CONTINUE_GS == false) {
        return;
    }

    // Display status msg
    Log.Info("+==============================+", Log.LVL_INFO);
    Log.Info("Event handling...", Log.LVL_INFO);

    // While events are waiting
    while (GSEventController.IsEventWaiting()) {
        // Next event in variable
        local NEXT_EVENT = GSEventController.GetNextEvent();
        switch (NEXT_EVENT.GetEventType()) {
            // Event: New industry
            case GSEvent.ET_INDUSTRY_OPEN:
            // Display status msg
            Log.Info(">New industry opened event", Log.LVL_SUB_DECISIONS);
            // Convert the event
            local EVENT_CONTROLER = GSEventIndustryOpen.Convert(NEXT_EVENT);
            // Get the industry ID
            local INDUSTRY_ID  = EVENT_CONTROLER.GetIndustryID();
            // Get the tile of the industry
            local TILE_ID = GSIndustry.GetLocation(INDUSTRY_ID);
            // Demolish the industry
            GSTile.DemolishTile(TILE_ID);
            break;
            // Event: Industry
            case GSEvent.ET_INDUSTRY_CLOSE:
            // Display status msg
            Log.Info(">Industry closed event", Log.LVL_SUB_DECISIONS)
            // Convert the event
            local EVENT_CONTROLER = GSEventIndustryClose.Convert(NEXT_EVENT);
            // Get the industry ID
            local INDUSTRY_ID  = EVENT_CONTROLER.GetIndustryID();
            // Do nothing, as reduced number of industries will be handeled in the next refresh loop
            break;
            // Unhandled events
            default:
            // Display status msg
            //Log.Info(">Unhandled event", Log.LVL_INFO)
            break;
        }
    }
}

// Custom get closest industry function
function IndustryConstructor::GetClosestIndustry(TILE) {
    // Create a list of all industries
    local IND_LIST = GSIndustryList();

    // If count is 0, return null
    if(IND_LIST.Count() == 0) return null;

    // Valuate by distance from tile
    IND_LIST.Valuate(GSIndustry.GetDistanceManhattanToTile, TILE);

    // Sort smallest to largest
    IND_LIST.Sort(GSList.SORT_BY_VALUE, GSList.SORT_ASCENDING);

    // Return the top one
    return IND_LIST.Begin();
}

// Town house list function, returns a list of tiles with houses on from a town
function IndustryConstructor:: GetTownHouseList(TOWN_ID, CARGO_ID) {
    // Below requires
    //    TOWN_ID // ID of town
    //    CARGO_PAXID    //    Passenger cargo ID

    // Configure variables
    local HOUSE_COUNT_FACTOR = 1.25; // Account for multi tile buildings
    local MAX_TRIES = (128 * 128); // Maximum size for search, to prevent infinite loop

    // Create a blank tile list
    local TOWN_HOUSE_LIST = GSTileList();
    local TOWN_HOUSE_LIST_COUNT = 0;

    // Create a cargo counter
    local CARGO_COUNTER = 0;
    //GSLog.Info(GSCargo.GetCargoLabel(CARGO_PAXID));

    // Get town house count
    local TOWN_HOUSE_COUNT = GSTown.GetHouseCount(TOWN_ID);

    // Set current tile
    local CURRENT_TILE = GSTown.GetLocation(TOWN_ID);

    //GSLog.Info(TOWN_ID);
    //GSLog.Info("===");
    //GSLog.Info(GSTile.IsWithinTownInfluence(CURRENT_TILE,TOWN_ID));
    //GSLog.Info(GSTile.GetTownAuthority(CURRENT_TILE)); //= TOWN_ID
    //GSLog.Info(GSTile.IsBuildable(CURRENT_TILE)); //=false
    //GSLog.Info(GSTile.GetOwner(CURRENT_TILE)); //=-1
    //GSLog.Info(GSTile.IsStationTile(CURRENT_TILE)); //=false
    //GSLog.Info(GSTile.GetCargoAcceptance(CURRENT_TILE, CARGO_PAXID,1,1,0)); //=0

    // Create spiral walker
    local SPIRAL_WALKER = SpiralWalker();
    // Set spiral walker on town center tile, always a road
    SPIRAL_WALKER.Start(CURRENT_TILE);

    // Create try counter
    local TRIES = 0;

    // Loop till list count matches house count
    while(TOWN_HOUSE_LIST_COUNT < (TOWN_HOUSE_COUNT * HOUSE_COUNT_FACTOR) && TRIES < MAX_TRIES) {
        // Inc tries
        TRIES++;

        // Walk one tile
        SPIRAL_WALKER.Walk();
        // Get tile
        CURRENT_TILE = SPIRAL_WALKER.GetTile();

        // Debug sign
        if(GSGameSettings.GetValue("log_level") >= 4)GSSign.BuildSign(CURRENT_TILE,"" + TRIES);

        // Debug msgs
        if(GSGameSettings.GetValue("log_level") >= 4) GSLog.Info("---" + TRIES + "---");
        if(GSGameSettings.GetValue("log_level") >= 4) GSLog.Info("In current town inf: " + GSTile.IsWithinTownInfluence(CURRENT_TILE,TOWN_ID));
        if(GSGameSettings.GetValue("log_level") >= 4) GSLog.Info("Town authority id: " + GSTile.GetTownAuthority(CURRENT_TILE));
        if(GSGameSettings.GetValue("log_level") >= 4) GSLog.Info("Buildable: " + GSTile.IsBuildable(CURRENT_TILE));
        if(GSGameSettings.GetValue("log_level") >= 4) GSLog.Info("Owner id: " + GSTile.GetOwner(CURRENT_TILE));
        if(GSGameSettings.GetValue("log_level") >= 4) GSLog.Info("Station: " + GSTile.IsStationTile(CURRENT_TILE));
        if(GSGameSettings.GetValue("log_level") >= 4) GSLog.Info("Passenger acceptance: " + GSTile.GetCargoAcceptance(CURRENT_TILE, CARGO_PAXID,1,1,0));

        // If not the current town, continue
        if(GSGameSettings.GetValue("log_level") >= 4) if(GSTile.IsWithinTownInfluence(CURRENT_TILE,TOWN_ID) == false);
        // If not a ??? (non town center buildings are always 65535)
        if(GSTile.GetTownAuthority(CURRENT_TILE) != TOWN_ID) continue;
        // If buildable, continue
        if(GSTile.IsBuildable(CURRENT_TILE) != false) continue;
        // If owned by anyone, continue
        if(GSTile.GetOwner(CURRENT_TILE) != -1) continue;
        // If station, continue
        //if(GSTile.IsStationTile(CURRENT_TILE) != false) continue;
        // If industry, continue
        if(IsIndustry(CURRENT_TILE) != false) continue;

        // Get passenger acceptance
        CARGO_COUNTER = GSTile.GetCargoAcceptance(CURRENT_TILE, CARGO_PAXID,1,1,0);

        // If the current tile accepts passengers
        if(GSTile.GetCargoAcceptance(CURRENT_TILE, CARGO_PAXID,1,1,0) > 0) {
            // Add the tile
            TOWN_HOUSE_LIST.AddTile(CURRENT_TILE);

            // Inc counter
            TOWN_HOUSE_LIST_COUNT++;

            // Debug sign
            if(GSGameSettings.GetValue("log_level") >= 4) GSSign.BuildSign(CURRENT_TILE,"H: " + TOWN_HOUSE_LIST_COUNT);
            }
    }

    // Display status msg
    //GSLog.Info("Created list of " + TOWN_HOUSE_LIST.Count() + " of " + TOWN_HOUSE_COUNT + " houses in town " + GSTown.GetName(TOWN_ID));

    // Return the list
    return TOWN_HOUSE_LIST;
}

// Min/Max X/Y list function, returns a 4 tile list with X Max, X Min, Y Max, Y Min, or blank list on fail.
// If second param is == true, returns a 2 tile list with XY Min and XY Max, or blank list on fail.
function IndustryConstructor:: ListMinMaxXY(TILE_LIST, TWO_TILE_BOOL) {

    local LOCAL_LIST = GSList();

    local X_MAX_TILE = -1;
    local X_MIN_TILE = -1;
    local Y_MAX_TILE = -1;
    local Y_MIN_TILE = -1;

    // Add list
    LOCAL_LIST.AddList(TILE_LIST);

    // Remove invalid tiles
    LOCAL_LIST.Valuate(GSMap.IsValidTile);
    LOCAL_LIST.KeepValue(1);

    // If list is not empty
    if(!LOCAL_LIST.IsEmpty()) {
        // Valuate by x coord
        LOCAL_LIST.Valuate(GSMap.GetTileX);
        // Sort from highest to lowest
        LOCAL_LIST.Sort(GSList.SORT_BY_VALUE, false);
        // Assign highest
        X_MAX_TILE = LOCAL_LIST.Begin();
        // Sort from lowest to highest
        LOCAL_LIST.Sort(GSList.SORT_BY_VALUE, true);
        // Assign lowest
        X_MIN_TILE = LOCAL_LIST.Begin();
        // Valuate by y coord
        LOCAL_LIST.Valuate(GSMap.GetTileY);
        // Sort from highest to lowest
        LOCAL_LIST.Sort(GSList.SORT_BY_VALUE, false);
        Y_MAX_TILE = LOCAL_LIST.Begin();
        // Sort from lowest to highest
        LOCAL_LIST.Sort(GSList.SORT_BY_VALUE, true);
        // Assign lowest
        Y_MIN_TILE = LOCAL_LIST.Begin();

        // Debug sign
        if(GSGameSettings.GetValue("log_level") >= 4) GSSign.BuildSign(X_MAX_TILE,"X Max tile");
        if(GSGameSettings.GetValue("log_level") >= 4) GSSign.BuildSign(X_MIN_TILE,"X Min tile");
        if(GSGameSettings.GetValue("log_level") >= 4) GSSign.BuildSign(Y_MAX_TILE,"Y Max tile");
        if(GSGameSettings.GetValue("log_level") >= 4) GSSign.BuildSign(Y_MIN_TILE,"Y Min tile");

        // Debug msgs
        //GSLog.Info("X Max: " + X_MAX + " X Min: " + X_MIN + " Y Max: " + Y_MAX + " Y Min: ");

        //Create tile list
        local OUTPUT_TILE_LIST = GSTileList();

        if(TWO_TILE_BOOL == true) {
            // Get 2 max and min tiles
            local X_MIN = GSMap.GetTileX(X_MIN_TILE);
            local X_MAX = GSMap.GetTileX(X_MAX_TILE);
            local Y_MIN = GSMap.GetTileY(Y_MIN_TILE);
            local Y_MAX = GSMap.GetTileY(Y_MAX_TILE);

            local XY_MIN_TILE = GSMap.GetTileIndex(X_MIN, Y_MIN);
            local XY_MAX_TILE = GSMap.GetTileIndex(X_MAX, Y_MAX);

            //GSLog.Info(GSMap.IsValidTile(XY_MIN_TILE) + " " + GSMap.IsValidTile(XY_MAX_TILE));

            // Add tiles
            OUTPUT_TILE_LIST.AddTile(XY_MIN_TILE);
            OUTPUT_TILE_LIST.AddTile(XY_MAX_TILE);
        }
        else{
            // Add tiles
            OUTPUT_TILE_LIST.AddTile(X_MAX_TILE);
            OUTPUT_TILE_LIST.AddTile(X_MIN_TILE);
            OUTPUT_TILE_LIST.AddTile(Y_MAX_TILE);
            OUTPUT_TILE_LIST.AddTile(Y_MIN_TILE);
        }

        return OUTPUT_TILE_LIST;

    }
    else GSLog.Error("IndustryConstructor.ListMinMaxXY: List is Empty!");

    return LOCAL_LIST;
}

// Error handler function
function IndustryConstructor:: ErrorHandler() {
    // Get error
    local ERROR = GSError.GetLastError();

    // Check if error is not nothing
    if (ERROR == GSError.ERR_NONE) return;

    // Error category
        switch(GSError.GetErrorCategory()) {
    case GSError.ERR_CAT_NONE:
        GSLog.Error("Error not related to any category.")
        break;
    case GSError.ERR_CAT_GENERAL:
        GSLog.Error("Error related to general things.")
        break;
    case GSError.ERR_CAT_VEHICLE:
        GSLog.Error("Error related to building / maintaining vehicles.")
        break;
    case GSError.ERR_CAT_STATION:
        GSLog.Error("Error related to building / maintaining stations.")
        break;
    case GSError.ERR_CAT_BRIDGE:
        GSLog.Error("Error related to building / removing bridges.")
        reak;
    case GSError.ERR_CAT_TUNNEL:
        GSLog.Error("Error related to building / removing tunnels.")
        break;
    case GSError.ERR_CAT_TILE:
        GSLog.Error("Error related to raising / lowering and demolishing tiles.")
        break;
    case GSError.ERR_CAT_SIGN:
        GSLog.Error("Error related to building / removing signs.")
        break;
    case GSError.ERR_CAT_RAIL:
        GSLog.Error("Error related to building / maintaining rails.")
        break;
    case GSError.ERR_CAT_ROAD:
        GSLog.Error("Error related to building / maintaining roads.")
        break;
    case GSError.ERR_CAT_ORDER:
        GSLog.Error("Error related to managing orders.")
        break;
    case GSError.ERR_CAT_MARINE:
        GSLog.Error("Error related to building / removing ships, docks and channels.")
        break;
    case GSError.ERR_CAT_WAYPOINT:
        GSLog.Error("Error related to building / maintaining waypoints.")
        break;
        default:
    GSLog.Error("Unhandled error category!" + GSError.GetErrorCategory());
    break;
        }

    // Errors
        switch(ERROR) {
        case GSSign.ERR_SIGN_TOO_MANY_SIGNS:
        GSLog.Error("Too many signs!");
        break;

        default:
    GSLog.Error("Unhandled error: " + GSError.GetLastErrorString());
    break;
    }
}

// Function to check if tile is industry, returns true or false
function IsIndustry(TILE_ID) {return (GSIndustry.GetIndustryID(TILE_ID) != 65535); }

// Function to valuate town by dist from edge
function GetTownDistFromEdge(TOWN_ID) {
    return GSMap.DistanceFromEdge(GSTown.GetLocation(TOWN_ID));
}
