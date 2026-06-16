# Manifest

This manifest describes the files intentionally included in the GitHub release.

## Root files

- `README.md`: repository overview and quick start.
- `LICENSE` / `LICENSE.txt`: MIT license.
- `CITATION.cff`: citation metadata.
- `CHANGELOG.md`: release notes.
- `MANIFEST.md`: this file.
- `.gitignore`: protects against accidental upload of raw microscopy data, heavy outputs and model checkpoints.
- `run_suite.m`: MATLAB entry point.
- `startup.m`: optional MATLAB path helper.

## Source code

- `src/app_main.m`: graphical launcher.
- `src/tools/geodesic_tract_analysis.m`: geodesic ECM tract workflow.
- `src/tools/degradation_tunnel_annotation.m`: SAM2-assisted degradation/tunnel annotation workflow.
- `src/tools/sam2_config.example.json`: example SAM2 configuration file.
- `src/tools/sam2_config.json`: empty local SAM2 configuration template.

## Documentation

- `docs/INSTALLATION.md`: installation guide.
- `docs/USER_GUIDE.md`: practical usage guide.
- `docs/SAM2_SETUP.md`: SAM2 configuration instructions.
- `docs/OUTPUTS.md`: workflow output definitions.
- `docs/REPRODUCIBILITY.md`: reproducibility and output policy.
- `docs/PUBLICATION_SCOPE.md`: description of included/excluded workflows.
- `docs/figures/`: lightweight representative figures.

## Placeholders

- `data/README.md`: explains that raw data are not stored in GitHub.
- `examples/README.md`: explains expected example-data policy.
- `models/checkpoints/README.md`: explains checkpoint policy.
- `third_party/sam2/README.md`: explains external SAM2 installation policy.
- `results/.gitkeep`: keeps the results folder visible without committing outputs.

## Excluded files

The repository intentionally excludes raw `.lif` files, TIFF stacks, `.mat` outputs, HDF5 files, SAM2 checkpoints, Python environments and large result folders.
