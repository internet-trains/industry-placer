SELF_VERSION <- 1;

class IndustryPlacer extends GSInfo
{
    function GetAuthor() { return "larry"; }
    function GetName() { return "Industry Placer"; }
    function GetDescription() { return "Places industries"; }
    function GetVersion() { return SELF_VERSION; }
    function GetDate() { return "2019-07-25"; }
    function CreateInstance() { return "IndustryPlacer"; }
    function GetShortName() { return "INDP"; }
    function GetAPIVersion() { return "1.3"; }
    function GetUrl() { return ""; }
    function GetSettings() {
        AddSetting({
            name = "industry_newgrf",
            description = "Which industry NewGRF are you using?",
            flags = CONFIG_INGAME,
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            min_value = 0,
            max_value = 10
        });
        AddLabels("industry_newgrf", {
            _0 = "None",
            _1 = "North American FIRS",
            _2 = "FIRS Temperate Basic",
            _3 = "FIRS Arctic Basic",
            _4 = "FIRS Tropic Basic",
            _5 = "FIRS Steeltown",
            _6 = "FIRS In A Hot Country",
            _7 = "FIRS Extreme"
        });
        AddSetting({
            name = "town_industry_limit",
            description = "Max industries per town",
            flags = CONFIG_INGAME,
            easy_value = 5,
            medium_value = 5,
            hard_value = 5,
            custom_value = 5,
            min_value = 0,
            max_value = 100,
            step_size = 1
        });
        AddSetting({
            name = "town_radius",
            description = "Tertiary industry distance from town limit",
            flags = CONFIG_INGAME,
            easy_value = 20,
            medium_value = 20,
            hard_value = 20,
            custom_value = 20,
            min_value = 0,
            max_value = 200,
            step_size = 10
        });
        AddSetting({
            name = "town_long_radius",
            description = "Primary industry distance from town limit",
            flags = CONFIG_INGAME,
            easy_value = 70,
            medium_value = 70,
            hard_value = 70,
            custom_value = 70,
            min_value = 10,
            max_value = 1000,
            step_size = 10
        });
        AddSetting({
            name = "cluster_radius",
            description = "Cluster footprint radius",
            flags = CONFIG_INGAME,
            easy_value = 10,
            medium_value = 10,
            hard_value = 10,
            custom_value = 10,
            min_value = 0,
            max_value = 50,
            step_size = 10
        });
        AddSetting({
            name = "cluster_occ_pct",
            description = "Percent available space for cluster siting required",
            flags = CONFIG_INGAME,
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            min_value = 0,
            max_value = 100,
            step_size = 10
        });
        AddSetting({
            name = "cluster_industry_limit",
            description = "Max industries per cluster",
            flags = CONFIG_INGAME,
            easy_value = 100,
            medium_value = 100,
            hard_value = 100,
            custom_value = 100,
            min_value = 0,
            max_value = 100,
            step_size = 10
        });
        AddSetting({
            name = "cluster_spacing",
            description = "Space between cluster zones",
            flags = CONFIG_INGAME,
            easy_value = 50,
            medium_value = 50,
            hard_value = 50,
            custom_value = 50,
            min_value = 0,
            max_value = 100,
            step_size = 10
        });
        AddSetting({
            name = "industry_spacing",
            description = "Space between any two industries",
            flags = CONFIG_INGAME,
            easy_value = 5,
            medium_value = 5,
            hard_value = 5,
            custom_value = 5,
            min_value = 0,
            max_value = 100,
            step_size = 10
        });
        AddSetting({
            name = "large_town_cutoff",
            description = "Clusters avoid towns above this size",
            flags = CONFIG_INGAME,
            easy_value = 600,
            medium_value = 600,
            hard_value = 600,
            custom_value = 600,
            min_value = 0,
            max_value = 10000,
            step_size = 100
        });
        AddSetting({
            name = "large_town_spacing",
            description = "Clusters stay this far away from towns above large town cutoff",
            flags = CONFIG_INGAME,
            easy_value = 100,
            medium_value = 100,
            hard_value = 100,
            custom_value = 100,
            min_value = 0,
            max_value = 1000,
            step_size = 50
        });
        AddSetting({
            name = "farm_spacing",
            description = "Spacing between farm fill",
            flags = CONFIG_INGAME,
            easy_value = 40,
            medium_value = 40,
            hard_value = 40,
            custom_value = 40,
            min_value = 0,
            max_value = 500,
            step_size = 10
        });
        AddSetting({
            name = "raw_industry_min",
            description = "Attempt to build this many clusters of raw industry",
            flags = CONFIG_INGAME,
            easy_value = 5000,
            medium_value = 5000,
            hard_value = 5000,
            custom_value = 5000,
            min_value = 0,
            max_value = 5000,
            step_size = 10
        });
        AddSetting({
            name = "proc_industry_min",
            description = "Attempt to build this many processing industries",
            flags = CONFIG_INGAME,
            easy_value = 10,
            medium_value = 10,
            hard_value = 10,
            custom_value = 10,
            min_value = 0,
            max_value = 5000,
            step_size = 10
        });
        AddSetting({
            name = "tertiary_industry_min",
            description = "Attempt to build this many tertiary industries",
            flags = CONFIG_INGAME,
            easy_value = 5000,
            medium_value = 5000,
            hard_value = 5000,
            custom_value = 5000,
            min_value = 0,
            max_value = 5000,
            step_size = 10
        });
        AddSetting({
            name = "debug_level",
            description = "Debug log level - 3 for most verbose",
            flags = CONFIG_INGAME,
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            min_value = 0,
            max_value = 3,
            step_size = 1
        });
    }
}

RegisterGS(IndustryPlacer());
