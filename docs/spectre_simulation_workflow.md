# Spectre Simulation Workflow

The `spectre_templates/` folder contains sanitized workflow templates only.

Users must configure their own environment, for example:

```bash
export SPECTRE_BIN=/path/to/spectre
export PDK_MODEL_FILE=/path/to/130nm/models.scs
export RRAM_MODEL_FILE=$PWD/src/veriloga/RRAM_v_2_1_Beta.va
```

The templates intentionally avoid private paths and licensed technology files. They are provided to document the structure of the workflow and help users adapt the setup to their own authorized environment.

Required external resources:

- Cadence Spectre
- a valid Cadence license
- a configured 130 nm PDK/ODK model environment
- local generated netlists or simulator input data
- writable local run directories

This repository does not include simulator binaries, license files, PDK/ODK model libraries, raw waveform outputs, or private server configuration.

