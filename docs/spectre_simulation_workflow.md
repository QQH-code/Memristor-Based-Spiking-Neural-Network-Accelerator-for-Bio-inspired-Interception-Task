# Spectre Simulation Workflow

This repository includes sanitized Spectre workflow templates, but it does not include a runnable Cadence/Spectre environment. Spectre is external because it is a licensed EDA tool, and compatible 130 nm PDK/ODK model libraries are also external technology resources.

## Included Template Files

- `spectre_templates/README.md`
- `spectre_templates/netlist_templates/crossbar_neuron_template.scs`
- `spectre_templates/run_scripts/run_spectre_template.sh`

These files document the structure of the circuit-simulation workflow and provide a starting point for users who have their own authorized simulator and PDK/ODK setup.

## Placeholder Meanings

- `$SPECTRE_BIN`: path to the local Spectre executable or wrapper script.
- `$PDK_ROOT`: root directory of the user's local 130 nm PDK/ODK installation.
- `$SPECTRE_MODEL_DIR`: directory containing local simulator model files.
- `$CADENCE_HOME`: root of the local Cadence installation, if needed by user scripts.
- `$PROJECT_ROOT`: local path to this repository or to a configured working copy.

These placeholders intentionally replace private machine paths and server-specific configuration.

## What Users Must Supply

Users who want to adapt the circuit workflow must provide:

- a licensed Cadence/Spectre installation,
- a compatible 130 nm PDK/ODK,
- valid model-library paths,
- any generated circuit netlists required by their experiment,
- local simulation output directories,
- local environment setup compatible with their institution or tool installation.

## What Should Not Be Expected From GitHub

This repository does not provide:

- proprietary model libraries,
- PDK/ODK files,
- Cadence license files,
- simulator binaries,
- server setup scripts,
- raw simulator outputs,
- complete standalone circuit-level reproduction.

## How To Use the Templates

Treat the files under `spectre_templates/` as workflow documentation and starting templates. Before running them, replace placeholders with local environment variables and verify that all model includes and generated netlists point to files you are authorized to use.

The templates are intentionally conservative. They show the shape of the workflow without exposing private paths or licensed technology files.
