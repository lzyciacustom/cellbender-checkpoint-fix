# CellBender Checkpoint Bug Fix

A complete setup script that fixes the PyTorch pickle error in CellBender 0.3.2 and runs ambient RNA removal on single-cell RNA-seq data.

## Problem

CellBender 0.3.2 encounters a checkpoint saving error with PyTorch 2.x:

```
TypeError: cannot pickle 'weakref.ReferenceType' object
AssertionError: Checkpoint file ckpt.tar.gz does not exist
```

This bug prevents CellBender from completing successfully, even though the training finishes correctly.

## Solution

This script automatically:
1. Sets up a clean Python 3.10 environment
2. Installs CellBender 0.3.2 from GitHub
3. Applies runtime patches to bypass checkpoint pickling issues
4. Runs CellBender on multiple samples with customizable parameters

## Requirements

- Python 3.10
- CUDA-capable GPU (tested on RTX 3090)
- Linux/WSL environment
- Input: CellRanger raw_feature_bc_matrix.h5 files

## Installation & Usage

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/cellbender-fix/main/complete_cellbender_setup.sh

# Make executable
chmod +x complete_cellbender_setup.sh

# Edit sample paths and parameters in the script
nano complete_cellbender_setup.sh

# Run
./complete_cellbender_setup.sh
```

## Configuration

Edit these variables in the script:

```bash
BASE_DIR="/mnt/g/ZL_colon"  # Your data directory

# Format: "FOLDER:EXPECTED_CELLS:TOTAL_DROPLETS:FPR"
SAMPLES=(
  "01_WT1_colon:16000:35000:0.01"
  "02_WT2_colon:12000:30000:0.01"
  "04_KO1_colon:8000:20000:0.05"   # Higher FPR for damaged samples
)
```

### Parameter Guide

- **EXPECTED_CELLS**: Approximate number of real cells (check knee plot)
- **TOTAL_DROPLETS**: Number of droplets to include (typically 2-3x expected cells)
- **FPR**: False positive rate
  - `0.01` = Strict filtering (recommended for healthy samples)
  - `0.05` = Gentler filtering (recommended for low-quality/damaged samples)
  - `0.10` = Very permissive (use with caution)

## Output Files

For each sample, the script generates:
- `*_filtered.h5` - Filtered count matrix (use this for downstream analysis)
- `*.h5` - Raw output with all droplets
- `*_cell_barcodes.csv` - List of cell barcodes
- `*_metrics.csv` - QC metrics
- `*.pdf` - Quality control plots (if successful)

## Technical Details

### What the patches do:

1. **checkpoint.py**: Replaces `save_checkpoint()` with a no-op function to avoid pickle errors
2. **posterior.py**: Safely handles missing checkpoints without crashing

These patches don't affect the quality of results - they only disable intermediate checkpoint saving. The final outputs are still generated correctly.

### Why different FPR for different samples?

Biologically damaged samples (e.g., knockout models with tissue damage) may have:
- Fewer viable cells
- Lower RNA content per cell
- More ambient RNA contamination

Using a higher FPR (0.05 vs 0.01) helps retain more real cells while still removing background, which is crucial for accurate downstream analysis of these samples.

## Downstream QC Recommendations

After CellBender, apply additional quality control:

```r
# In Seurat/Scanpy
- Remove cells with >15-20% mitochondrial reads
- Remove cells with <500-1000 UMIs
- Remove cells with <200-500 detected genes
- Run doublet detection (DoubletFinder, Scrublet)
```

## Troubleshooting

### "CUDA out of memory"
Reduce `--total-droplets-included` or process samples one at a time

### "No filtered output produced"
Check the log file in `cellbender_out/SAMPLE_cellbender.log`

### Different CellBender version needed
Modify line 32 to install a specific version:
```bash
pip install cellbender==0.3.0
```

## Citation

If you use this script, please cite the original CellBender paper:

```
Fleming, S.J., Chaffin, M.D., Arduini, A. et al. 
Unsupervised removal of systematic background noise from droplet-based single-cell experiments using CellBender. 
Nat Methods 20, 1323–1335 (2023). 
https://doi.org/10.1038/s41592-023-01943-7
```

## Contributing

Issues and pull requests welcome! This is a community solution to a known bug.

## License

MIT License - feel free to use and modify

## Acknowledgments

- CellBender team at Broad Institute
- Solution developed through collaborative debugging

---

**Note**: This is a workaround for a known bug. Future versions of CellBender may fix this issue natively.
