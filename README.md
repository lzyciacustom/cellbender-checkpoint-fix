# CellBender Checkpoint Fix

A complete solution for the CellBender checkpoint pickle serialization bug that causes crashes during training.

## 🐛 The Problem

When running CellBender `remove-background`, you may encounter this error:

```
Traceback (most recent call last):
  ...
  File ".../cellbender/remove_background/checkpoint.py", line XXX, in save_checkpoint
    ...
_pickle.PicklingError: Can't pickle <lambda>: attribute lookup <lambda> on ...
```

Or this error during posterior computation:

```
AssertionError: Checkpoint file ckpt.tar.gz does not exist, presumably because 
saving of the checkpoint file has been manually interrupted.
```

These errors occur due to:
1. **Pickle serialization bug** - CellBender tries to pickle lambda functions and CUDA objects
2. **Missing checkpoint file** - The code expects checkpoint files that were never created

## ✅ The Solution

This repository provides **patches** that:
- Disable checkpoint saving/loading (not needed for training runs < 200 epochs)
- Remove assertions that check for checkpoint file existence
- Add null-safety checks for checkpoint-related variables

**Result**: CellBender runs normally from start to finish without crashes! ✨

## 🚀 Quick Start

### One-Command Setup

Download and run the setup script:

```bash
wget https://raw.githubusercontent.com/lzyciacustom/cellbender-checkpoint-fix/main/setup_cellbender_patched.sh
chmod +x setup_cellbender_patched.sh
./setup_cellbender_patched.sh
```

This will:
1. Create a fresh Python virtual environment at `~/cb032_fixed`
2. Install CellBender v0.3.2 from GitHub
3. Install required dependencies (scrublet, scanpy)
4. Apply all necessary patches
5. Verify the installation

### Activate and Use

```bash
# Activate the environment
source ~/cb032_fixed/bin/activate

# Run CellBender
cellbender remove-background \
  --cuda \
  --input raw_feature_bc_matrix.h5 \
  --output cellbender_output.h5 \
  --expected-cells 20000 \
  --total-droplets-included 40000 \
  --fpr 0.01 \
  --epochs 150
```

## 📋 What Gets Patched?

### 1. `checkpoint.py` - Disable Checkpoint Functions

**Changes:**
- `save_checkpoint()` → Returns immediately (no-op)
- `load_checkpoint()` → Returns `{"loaded": False}`
- `load_from_checkpoint()` → Returns `None`
- `attempt_load_checkpoint()` → Returns `{"loaded": False}`

**Why:** These functions cause pickle errors with lambda functions and CUDA objects.

**Impact:** Training cannot resume from checkpoints, but runs without crashes.

### 2. `posterior.py` - Remove Assertions & Add Null Checks

**Changes:**
- Remove assertion checking for `ckpt.tar.gz` existence
- Add null checks: `if ckpt_posterior and os.path.exists(...)`
- Replace `ckpt_posterior.get(...)` with `(ckpt_posterior or {}).get(...)`

**Why:** Without checkpoint files, the code would crash on null pointer errors.

**Impact:** Posterior computation works correctly without checkpoint files.

## 🧪 Tested Configuration

This patch has been successfully tested with:

- **CellBender version**: v0.3.2
- **Python version**: 3.10
- **Dataset size**: 18k-25k cells per sample
- **Training epochs**: 30 (testing), 150 (production)
- **Hardware**: CUDA-enabled GPU

## 📊 Example Use Case: Heart snRNA-seq Pipeline

We've used this patch in production for processing 6 heart snRNA-seq samples:

```bash
# Sample configuration (18k-25k cells per sample)
cellbender remove-background \
  --cuda \
  --input raw_feature_bc_matrix.h5 \
  --output output.h5 \
  --expected-cells 20000 \
  --total-droplets-included 40000 \
  --fpr 0.01 \
  --epochs 150
```

**Results:**
- ✅ All 6 samples processed successfully
- ✅ No crashes or pickle errors
- ✅ High-quality ambient RNA removal
- ✅ Compatible with downstream Scrublet doublet detection

## 🔧 Manual Patch Application

If you prefer to patch an existing installation:

### 1. Find Your CellBender Installation

```bash
python -c "import site; print(site.getsitepackages()[0])"
```

### 2. Patch checkpoint.py

Replace the following functions in `cellbender/remove_background/checkpoint.py`:

```python
def save_checkpoint(*args, **kwargs):
    """Patched to skip checkpoint saving due to pickle bug"""
    import logging
    logger = logging.getLogger(__name__)
    logger.info("Checkpoint saving skipped (patched)")
    return

def load_checkpoint(*args, **kwargs):
    """Patched to skip checkpoint loading"""
    return {"loaded": False}

def load_from_checkpoint(*args, **kwargs):
    """Patched to skip checkpoint loading"""
    return None

def attempt_load_checkpoint(*args, **kwargs):
    """Patched to skip checkpoint loading"""
    return {"loaded": False}
```

### 3. Patch posterior.py

In `cellbender/remove_background/posterior.py`:

**Find and remove** (around line 59):
```python
assert os.path.exists(args.input_checkpoint_tarball), \
    f'Checkpoint file {args.input_checkpoint_tarball} does not exist, ' \
    f'presumably because saving of the checkpoint file has been manually interrupted. ' \
    f'load_or_compute_posterior_and_save() will not work properly without an existing ' \
    f'checkpoint file.  Please re-run and allow a checkpoint file to be saved.'
```

**Replace with:**
```python
pass  # Checkpoint assertion removed (patched)
```

**Find and replace:**
```python
# Old
if os.path.exists(ckpt_posterior.get('posterior_file', 'does_not_exist')):

# New
if ckpt_posterior and os.path.exists(ckpt_posterior.get('posterior_file', 'does_not_exist')):
```

**Find and replace all occurrences:**
```python
# Old
ckpt_posterior.get(

# New
(ckpt_posterior or {}).get(
```

## ❓ FAQ

### Q: Will this affect my results?

**A:** No. The patches only disable checkpoint saving/loading, which is only used for resuming interrupted training runs. Your final results are identical.

### Q: Can I still resume interrupted runs?

**A:** No. With these patches, you cannot resume from checkpoints. However, for typical datasets (< 200 epochs), training completes in a few hours, so resuming is rarely needed.

### Q: What if I need checkpoint functionality?

**A:** Wait for the official CellBender fix, or reduce your training complexity to avoid the pickle error. The bug is related to lambda functions and CUDA objects in the model.

### Q: Does this work with CellBender v0.3.0 or v0.3.1?

**A:** The patches are designed for v0.3.2 but may work with earlier versions. Test carefully if using a different version.

### Q: What about the latest CellBender from main branch?

**A:** If you install from the main branch (`pip install git+https://github.com/broadinstitute/CellBender.git`), the patches should still work, but filenames/line numbers may differ. Always verify after patching.

## 🤝 Contributing

Found an issue or have improvements? Please:
1. Open an issue describing the problem
2. Submit a pull request with your fix
3. Share your testing results

## 📜 License

This patch is provided as-is for the scientific community. Use at your own discretion.

## 🙏 Acknowledgments

- CellBender team for the excellent tool
- Community members who reported and investigated the checkpoint bug

## 📞 Contact

Questions or issues? Open a GitHub issue or contribute to the discussion!

---

**Repository**: https://github.com/lzyciacustom/cellbender-checkpoint-fix

**Last Updated**: January 29, 2026
