# External Dependencies

## Repository Utilities

The public Python utilities are limited to release curation and integrity checks. Install the lightweight dependency set with:

```bash
pip install -r requirements.txt
```

or:

```bash
conda env create -f environment.yml
conda activate memristive-snn-vlsi-release
```

## MATLAB

Most included research scripts are MATLAB files. Users need their own MATLAB installation to run or adapt them.

## Circuit Simulation

Full circuit-level simulation requires external tools and files that are not distributed here:

- Cadence Spectre
- a valid Cadence license
- a configured 130 nm PDK/ODK environment
- local model-library paths
- local simulator run directories

The placeholders `$SPECTRE_BIN`, `$PDK_ROOT`, `$SPECTRE_MODEL_DIR`, and `$CADENCE_HOME` are used in documentation/templates to avoid private paths.

