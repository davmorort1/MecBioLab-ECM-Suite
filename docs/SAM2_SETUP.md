# SAM2 setup guide

The degradation/tunnel annotation workflow uses SAM2 as a prompt-assisted segmentation backend. The MATLAB application remains the reviewer-facing interface, while SAM2 is called through a local Python installation.

## 1. Install Python environment

Create a Python environment suitable for SAM2. The exact commands depend on your Python distribution and GPU setup. A typical Conda-based workflow is:

```bash
conda create -n sam2 python=3.10
conda activate sam2
```

Then install SAM2 following the official instructions of the SAM2 repository used in your laboratory setup.

## 2. Download a SAM2 checkpoint

Place the checkpoint outside this repository, for example:

```text
D:/models/sam2/checkpoints/sam2.1_b.pt
```

Do not commit checkpoints to GitHub. They are excluded by `.gitignore`.

## 3. Configure MATLAB-side JSON file

Copy or edit:

```text
src/tools/sam2_config.json
```

Example:

```json
{
  "pythonExe": "C:/Users/<user>/miniconda3/envs/sam2/python.exe",
  "repoRoot": "D:/tools/sam2",
  "checkpoint": "D:/models/sam2/checkpoints/sam2.1_b.pt",
  "config": "configs/sam2.1/sam2.1_hiera_b+.yaml"
}
```

Use forward slashes or escaped backslashes in JSON paths.

## 4. Test the environment

From a terminal:

```bash
conda activate sam2
python --version
```

Then test the SAM2 installation according to the official SAM2 documentation.

## 5. Run the annotation workflow

In MATLAB:

```matlab
run_suite
```

Launch **Degradation/Tunnel Annotation** and load a `.lif` file. The user remains responsible for reviewing masks, accepting valid annotations and rejecting incorrect masks.

## 6. Output policy

The workflow exports reviewed masks, labels and metadata. Treat these outputs as expert-reviewed annotations, not as fully automatic ground truth. They are suitable for downstream review, object quantification and future supervised segmentation model development.
