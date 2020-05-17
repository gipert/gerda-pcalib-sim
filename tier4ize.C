#include <dirent.h>

using namespace gada;

// get raw-*.root files in directory
std::vector<std::string> readdir(std::string foldName) {

    std::vector<std::string> filelist;
    auto p = std::unique_ptr<DIR,std::function<int(DIR*)>>{opendir(foldName.c_str()), &closedir};
    if (!p) { std::cerr << "ERROR: invalid or empty directory path!\n"; return filelist; }
    dirent entry;
    for (auto* r = &entry; readdir_r(p.get(), &entry, &r) == 0 && r; ) {
        // this means "is a regular file", DT_REG = 8
        if (entry.d_type == 8 &&
            std::string(entry.d_name).find(".root") != std::string::npos) {
            filelist.push_back(foldName + "/" + std::string(entry.d_name));
        }
    }
    std::sort(filelist.begin(), filelist.end());
    std::cout << "sorted ROOT files:\n";
    for (const auto & f : filelist) std::cout << "  " << f << std::endl;
    return filelist;
};

void tier4ize(std::string dir, int run_id, std::string outname) {

    std::string kMappingFile          = "meta/mapping-spmMerged.json";
    std::string kResolutionFile       = "meta/ged-resolution-super-calib.json";
    std::string kEnergyReconstruction = "Zac";
    std::string kTransitionsFile      = "meta/ged-transition-linear-bjorn.json";
    std::string kGeometryFile         = "meta/ged-parameters.json";
    std::string kGedSettingsFile;
    ULong64_t kTimestamp;

    switch (run_id) {
        case 76 : {
            kGedSettingsFile      = "meta/ged-settings-run76pca.json";
            kTimestamp            = 1486293301;
            break;
        }
        case 68 : {
            kGedSettingsFile      = "meta/ged-settings-run68pca.json";
            kTimestamp            = 1468229805;
            break;
        }
    }

    std::cout << "Mapping                -> " << kMappingFile          << std::endl;
    std::cout << "Resolutions            -> " << kResolutionFile       << std::endl;
    std::cout << "Energy                 -> " << kEnergyReconstruction << std::endl;
    std::cout << "Transition/Dead layers -> " << kTransitionsFile      << std::endl;
    std::cout << "GeDet geometries       -> " << kGeometryFile         << std::endl;
    std::cout << "GeDet settings         -> " << kGedSettingsFile      << std::endl;
    std::cout << "Timestamp              -> " << kTimestamp            << std::endl;

    Long64_t primaries = 0;

    auto filelist = readdir(dir);
    if (filelist.empty()) {
        std::cerr << "ERROR: no ROOT files found in '" << dir << "', aborting" << std::endl;
        return;
    }

    TChain sim("fTree");

    TFile* tf;
    for (auto f : filelist) {
        tf = TFile::Open(f.c_str());
        auto obj = dynamic_cast<TParameter<long>*>(tf->Get("NumberOfPrimaries"));
        if (!obj) {
            std::cerr << "ERROR: could not find NumberOfPrimaries object in file '"
                      << f << "', it will not be processed" << std::endl;
            continue;
        }
        sim.Add(f.c_str());
        primaries += obj->GetVal();
        tf->Close();
    }

    setenv("MU_CAL", "meta/gerda-metadata/config/_aux/geruncfg", 1);

    T4SimConfig config;
    config.LoadMapping(kMappingFile);
    config.LoadGedSettings(kGedSettingsFile);
    config.LoadGedResolutions(kResolutionFile, kEnergyReconstruction);
    config.LoadGedTransitions(kTransitionsFile, kGeometryFile);
    config.LoadRunConfig(kTimestamp);

    T4SimHandler handler(&sim, &config, outname);
    handler.SetBranchAddresses();
    handler.RunProduction();

    // save number of primaries
    TFile fout(outname.c_str(), "UPDATE");
    TParameter<Long64_t> NumberOfPrimaries("NumberOfPrimaries", primaries);
    NumberOfPrimaries.Write();
    fout.Close();

    return;
}
