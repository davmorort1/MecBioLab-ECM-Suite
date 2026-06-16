# Manifest

This manifest describes the files included in the GitHub release.

## Root files

- `README.md`: repository overview and quick start.
- `LICENSE` / `LICENSE.txt`: MIT license.
- `CITATION.cff`: citation metadata, including the Zenodo DOI for v1.0.0.
- Zenodo archived release: <https://doi.org/10.5281/zenodo.20717656>.
- `CHANGELOG.md`: release notes.
- `MANIFEST.md`: this file.
- `.gitignore`: repository filter for local data, environment and generated-output formats.
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
- `docs/REPRODUCIBILITY.md`: reproducibility and output-management documentation.
- `docs/PUBLICATION_SCOPE.md`: description of the release scope.
- `docs/figures/`: lightweight representative figures.

## Supporting folders

- `data/README.md`: data-management note.
- `examples/README.md`: example-material note.
- `models/checkpoints/README.md`: SAM2 checkpoint note.
- `third_party/sam2/README.md`: external SAM2 dependency note.
- `results/.gitkeep`: keeps the local output folder available in the repository layout.

## Repository boundary

The release contains software, documentation, metadata and lightweight representative figures. Raw acquisitions, complete analysis outputs, model weights and local environment files are handled as external project assets.
