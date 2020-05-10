using namespace gada;

void tier4ize(std::string dir, int run_id, std::string outname) {

    std::string kMappingFile;
    std::string kResolutionFile;
    std::string kEnergyReconstruction;
    std::string kTransitionsFile;
    std::string kGeometryFile;
    std::string kGedSettingsFile;
    ULong64_t kTimestamp;

    switch (run_id) {
        case 76 : {
            kMappingFile          = "meta/mapping-spmMerged.json";
            kResolutionFile       = "meta/ged-resolution-super-calib.json";
            kEnergyReconstruction = "Zac";
            kTransitionsFile      = "meta/ged-transition-linear-bjorn.json";
            kGeometryFile         = "meta/ged-parameters.json";
            kGedSettingsFile      = "meta/ged-settings-run76pca.json";
            kTimestamp            = 1486293301;
            break;
        }
        case 68 : {
            kMappingFile          = "meta/mapping-spmMerged.json";
            kResolutionFile       = "meta/ged-resolution-super-calib.json";
            kEnergyReconstruction = "Zac";
            kTransitionsFile      = "meta/ged-transition-linear-bjorn.json";
            kGeometryFile         = "meta/ged-parameters.json";
            kGedSettingsFile      = "meta/ged-settings-run68pca.json";
            kTimestamp            = 1468229805;
            break;
        }
    }

    setenv("MU_CAL", "meta/gerda-metadata/config/_aux/geruncfg", 1);

    TChain* sim = new TChain("fTree");
    sim->Add((dir + "/*.root").c_str());

    T4SimConfig* config = new T4SimConfig();
    config->LoadMapping(kMappingFile);
    config->LoadGedSettings(kGedSettingsFile);
    config->LoadGedResolutions(kResolutionFile, kEnergyReconstruction);
    config->LoadGedTransitions(kTransitionsFile, kGeometryFile);
    config->LoadRunConfig(kTimestamp);

    T4SimHandler* handler = new T4SimHandler(sim, config, outname);
    handler->SetBranchAddresses();
    handler->RunProduction();

    delete handler;
    delete config;
    delete sim;
}
