# Reproducibility and output policy

The suite follows a traceability-oriented workflow. Every analysis run should be stored in a standardized output folder together with input metadata, parameter settings, numerical tables, figures and execution logs.

## 1. General principles

- Use a clean output folder outside the Git repository.
- Keep raw data and heavy outputs outside GitHub.
- Record MATLAB version, operating system, Bio-Formats version when available and Git commit if available.
- Preserve input file identifiers, series/position numbers, selected channels and voxel calibration.
- Inspect review figures before interpreting quantitative tables.

## 2. Geodesic Tract Analysis reproducibility

For each run, preserve:

- input `.lif` file name or internal dataset identifier;
- selected position/series;
- ECM and cell channel assignments;
- voxel size and Z-step;
- geodesic parameters;
- path coordinate files;
- tract-level CSV/XLSX/MAT tables;
- 3D tract renderings;
- inertia maps/path-overlaid QC figures;
- execution log.

The key reproducible output is the combination of calibrated path coordinates, tract metrics and run parameters.

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

## 4. Files excluded from GitHub

The `.gitignore` is configured to prevent accidental upload of heavy or private data formats, including:

- `.lif`, `.czi`, `.nd2`, `.ims` microscopy files;
- `.tif`/`.tiff` stacks;
- `.mat`, `.h5`, `.hdf5` result arrays;
- `.pt`, `.pth`, `.ckpt` model checkpoints;
- Python environments and caches;
- complete local result folders.

## 5. Recommended release procedure

Before journal submission:

1. verify that the GitHub repository contains only the two public workflows;
2. run a clean test from a fresh folder;
3. check that no private paths or raw datasets are committed;
4. tag the release as `v1.0.0`;
5. archive the release in Zenodo and add the DOI to the manuscript metadata.
