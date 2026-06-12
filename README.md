# Memristor-Based Spiking Neural Network Accelerator

This repository is a curated public research-code release for a memristor-based spiking neural network accelerator designed around a bio-inspired interception task. It includes selected MATLAB workflow scripts, Verilog-A model files, sanitized Spectre workflow templates, public figures, and documentation associated with the related papers.

Repository URL:

<https://github.com/QQH-code/Memristor-Based-Spiking-Neural-Network-Accelerator-for-Bio-inspired-Interception-Task>

## Motivation

This project studies a bio-inspired interception task in which a predator-like agent uses motion-related information to predict and respond to a moving target. The task provides a compact benchmark for evaluating event-driven neural computation, closed-loop trajectory behavior, and hardware-aware implementation of spiking neural networks.

Rather than treating the SNN only as a software model, this work explores how the network can be mapped toward memristor/RRAM-based synaptic hardware and neuron-level VLSI circuits. The goal is to connect task-level behavior, SNN computation, device/circuit modeling, and system-level evaluation in a single research workflow.

## Technical Approach

The workflow combines software-level SNN modeling with hardware-oriented mapping and circuit simulation:

1. Formulate the bio-inspired interception task using predator/prey position and motion variables.
2. Use an SNN model to process task-related inputs and generate prediction or control outputs.
3. Map trained or selected weights into hardware-oriented representations.
4. Represent synaptic computation using memristor/RRAM-inspired crossbar structures.
5. Use Verilog-A model files and Spectre workflow templates to support circuit-level evaluation.
6. Analyze trajectory behavior, waveform-level results, and variation effects through MATLAB-based scripts.

The full circuit-level workflow depends on licensed Cadence/Spectre tools and a compatible 130 nm PDK/ODK environment. These resources are not included in this public repository.

## Research Context

This repository sits at the intersection of spiking neural networks, memristor-based computing, neuromorphic circuits, and VLSI implementation. It is intended as a curated public release of selected code, model files, workflow templates, figures, and citation metadata associated with the related papers.

## Project Overview Figures

### 1. Bio-inspired interception task

![Bio-inspired interception task overview](figures/paper_figures/fig01_task_overview.png)

### 2. Memristor-based SNN accelerator architecture

![Memristor-based SNN accelerator architecture](figures/paper_figures/fig02_accelerator_architecture.png)

### 3. Representative system-level interception trajectories

![Representative system-level interception trajectories](figures/paper_figures/fig03_system_level_result_1.png)

### 4. Additional system-level trajectory behavior

![Additional system-level trajectory behavior](figures/paper_figures/fig04_system_level_result_2.png)

### 5. Neuron layout for VLSI implementation

![Neuron layout for VLSI implementation](figures/paper_figures/fig05_neuron_layout.png)

## Associated Papers

Please cite the related papers if you use this repository, its workflow templates, figures, or ideas:

- Qianhou Qu, Sheng Lu, Sungyong Jung, Qilian Liang, and Chenyun Pan, "Compact and Energy-Efficient Memristive Spiking Neuromorphic Accelerator for Bio-inspired Interception Tasks," arXiv:2605.31141, 2026.
- Qianhou Qu, Sheng Lu, Liuting Shang, Jaihan Utailawon, Sungyong Jung, Qilian Liang, and Chenyun Pan, "Memristor-Based Spiking Neural Network Accelerator for Bio-inspired Interception Task," arXiv:2605.31299, 2026.

Machine-readable citation metadata is provided in [CITATION.cff](CITATION.cff).

## Repository Contents

```text
src/matlab/
  MATLAB scripts used for SNN, crossbar, neuron, mapping, waveform-processing,
  and result-analysis workflows.

src/veriloga/
  Verilog-A model files used in the research workflow. These files are provided
  for reference and simulation-template purposes.

src/data_examples/
  Small public CSV/data examples that are safe to include.

spectre_templates/
  Sanitized Spectre netlist and run-script templates. These require an external
  Cadence/Spectre installation and a properly configured 130 nm PDK/ODK environment.

figures/paper_figures/
  Manually curated public figures associated with the project. Private notes,
  local paths, and unrelated project figures are excluded.

docs/
  Documentation explaining the project flow, external dependencies, Spectre workflow,
  figure descriptions, and citation information.

audit/
  Source-to-public file map, figure inventory, release-curation notes, and public
  repository audit records.
```

## How to Read This Repository

Start with:

- [docs/overview.md](docs/overview.md) for the high-level project scope.
- [docs/project_flow.md](docs/project_flow.md) for how the MATLAB, Verilog-A, and Spectre workflow pieces relate.
- [docs/spectre_simulation_workflow.md](docs/spectre_simulation_workflow.md) for external circuit-simulation requirements.
- [docs/figure_description.md](docs/figure_description.md) for the included public figure inventory.

Internal release-curation and privacy-audit records are stored under `audit/`.

The MATLAB and Spectre-related files reflect the original research workflow, but some scripts expect generated simulator outputs or local tool configuration that are not part of this public repository.

## External Cadence/Spectre and PDK/ODK Requirements

Full circuit-level simulation requires external resources that are not included:

- Cadence Spectre
- a valid Cadence license
- a properly configured 130 nm PDK/ODK environment
- local model-library paths
- generated netlists and simulator output directories

The public templates use placeholders such as `$SPECTRE_BIN`, `$PDK_ROOT`, `$SPECTRE_MODEL_DIR`, and `$CADENCE_HOME`.

## What Is Included

- Selected MATLAB scripts for software/circuit workflow analysis.
- Verilog-A device/model files used by the research flow.
- Small public CSV examples.
- Sanitized Spectre templates with placeholders instead of private paths.
- Manually curated public figures associated with the project.
- Documentation and audit files for public release preparation.

## What Is Not Included

- Full paper PDF.
- Full PowerPoint slide deck.
- PDK/ODK technology files.
- Cadence installation files, license files, or environment files.
- Raw Spectre outputs, logs, `.print` files, or simulator run directories.
- MATLAB binary artifacts such as `.mat` and `.fig`.
- Private paths, server paths, personal emails, or local setup files.

## License

This repository is released under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer

This repository is a curated public code/documentation release associated with the related research papers. It is not a complete end-to-end circuit reproduction package. Proprietary simulator files, PDK/ODK files, and licensed Cadence/Spectre resources must be supplied by users through their own authorized environment.
