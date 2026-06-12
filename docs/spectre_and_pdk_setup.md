# Spectre and PDK Setup

This repository does not include Cadence/Spectre tools, foundry PDK/ODK files, license files, or private model-library paths.

To adapt the Spectre templates, configure local environment variables such as:

```bash
export SPECTRE_BIN=/path/to/spectre
export PDK_MODEL_FILE=/path/to/130nm/models.scs
export RRAM_MODEL_FILE=$PWD/src/veriloga/RRAM_v_2_1_Beta.va
```

Then edit the template files under `spectre_templates/` for your own authorized environment.

