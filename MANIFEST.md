# Manifest

This manifest describes the files included in the GitHub release.

## Root files

- `README.md`: repository overview and quick start.
- `LICENSE` / `LICENSE.txt`: MIT license.
- `CITATION.cff`: citation metadata.
- `CHANGELOG.md`: release notes.
- `MANIFEST.md`: this file.
- `.gitignore`: repository filter for local data, environment and generated-output formats.
- `run_suite.m`: execution entry point.
- `startup.m`: path configuration.
- `codemeta.json` / `.zenodo.json`: software metadata and registry hooks.

## Source and tool directories

- `src/app_main.m`: graphical dashboard.
- `src/tools/density.m`: continuous density mapping workflow.
- `src/tools/degradation_tunnel_annotation.m`: SAM2-assisted annotation workflow.
- `src/tools/sam2_config.json`: Python environment configuration template.
- `tools/compile_standalone.m`: MATLAB Compiler build script.

## Documentation

- `docs/USER_GUIDE.md`: workflow logic and parameters.
- `docs/INSTALLATION.md`: requirements and dependencies.
- `docs/SAM2_SETUP.md`: Python and Segment Anything Model 2 configuration.
- `docs/OUTPUTS.md`: description of standardized exports.
- `docs/REPRODUCIBILITY.md`: parameters and data management.
- `docs/PUBLICATION_SCOPE.md`: relation to the SoftwareX manuscript.
- `docs/figures/`: representative lightweight UI and quality-control images.

## External data and models

The directories `data/`, `examples/` and `models/` contain placeholders (`README.md`). Full microscopy files, external scripts and local SAM2 model checkpoints are not archived in this codebase release.