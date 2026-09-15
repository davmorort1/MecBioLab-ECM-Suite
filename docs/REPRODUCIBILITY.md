# Reproducibility and output management

The suite follows a traceability-oriented workflow. Every analysis run should be stored in a standardized output folder together with input metadata, parameter settings, numerical tables, figures and execution logs.

## 1. General principles

- Use a clean output folder outside the Git repository.
- Preserve raw data and complete generated outputs in the corresponding project data location.
- Record MATLAB version, operating system, Bio-Formats version when available and Git commit if available.
- Preserve input file identifiers, series/position numbers, selected channels and voxel calibration.
- Inspect review figures before interpreting quantitative tables.

## 2. Continuous ECM Density Mapping reproducibility

For each run, preserve:

- input `.lif` file name or internal dataset identifier;
- selected position/series;
- ECM channel assignment;
- voxel size and Z-step;
- density analysis parameters (Z-projection method, background subtract pct, denoise sigma, final smooth sigma);
- 2D/3D continuous density heatmaps;
- raw signal vs colormap QC overlays and Z-profile figures;
- CSV/XLSX/MAT tables containing Gini Density Coefficients and Densification Indices;
- execution log.

The key reproducible output is the combination of the normalized full-field density heatmaps, extracted metrics and run parameters.

## 3. SAM2-assisted Annotation reproducibility

For each run, preserve:

- input `.lif` file name or internal dataset identifier;
- selected position/series;
- ECM/cell channel assignments;
- reviewed raw planes;
- accepted binary masks;
- no-tunnel/no-degradation labels when applicable;
- multiclass semantic labels;
- 3D connected-object measurements;
- SAM2 configuration path, checkpoint identifier and prompts/reviewer choices when available;
- execution log.

The key reproducible output is the reviewed mask set plus the metadata describing how it was produced.

## 4. Repository-external assets

The public GitHub repository is kept lightweight and software-focused. Large microscopy acquisitions, exported image stacks, MATLAB workspaces, model weights, local Python environments and complete run-output folders are treated as external project assets.

This separation keeps the code release citable and easy to review while allowing full run outputs to be preserved in the appropriate laboratory or institutional data location.

## 5. Recommended release procedure

The public `v1.1.0` release has been archived in Zenodo:

<https://doi.org/10.5281/zenodo.20717656>

Recommended procedure for future releases:

1. verify that the GitHub repository contains the public workflows described in the manuscript;
2. run a clean test from a fresh folder;
3. check that environment-specific paths are not embedded in documentation or configuration files;
4. tag the release with a semantic version number;
5. archive the release in Zenodo and add the new DOI to the manuscript/repository metadata.