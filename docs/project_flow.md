# Project Flow

This document maps the public repository files to the research workflow. It is intentionally conservative: several scripts depend on generated simulator outputs or local tool setup that are not included in the public release.

## 1. Task Formulation

The task-level context is shown in:

- `figures/paper_figures/fig01_task_overview.png`
- `figures/paper_figures/fig03_system_level_result_1.png`
- `figures/paper_figures/fig04_system_level_result_2.png`

These figures illustrate the interception setting and representative trajectory-level results. The repository does not include the full private experiment workspace used to generate every task result.

## 2. SNN Software Modeling and Inference

Relevant public files include:

- `src/matlab/software_model/simulate_IF_neuron.m`
- `src/matlab/software_model/simulate_IF_neuron_v2.m`
- `src/matlab/software_model/whole_system_run.m`
- `src/matlab/software_model/run_sim_crossbar_infer_norm_mc.m`
- `src/matlab/software_model/run_spectre_crossbar_infer_norm.m`

These scripts appear to represent IF-neuron behavior, whole-system evaluation, crossbar-oriented inference, and Monte Carlo aware software/circuit workflow preparation. Some scripts expect generated data files that are excluded from the public release.

## 3. Weight Extraction and Hardware-Oriented Mapping

Relevant files include:

- `src/data_examples/fc1_weight.csv`
- `src/data_examples/fc2_weight.csv`
- `src/matlab/mapping/generate_spectre_crossbar_array.m`
- `src/matlab/mapping/sweep_synapse_R_for_41levels.m`

The CSV files provide small public example weight data. The MATLAB mapping scripts are intended for converting or organizing software-level values into circuit-oriented crossbar or resistance-level representations.

## 4. Memristor/RRAM Synaptic Representation

Relevant files include:

- `src/veriloga/RRAM_v_2_1_Beta.va`
- `src/veriloga/resistor_rand_min.va`
- `src/matlab/mapping/sweep_synapse_R_for_41levels.m`

These files document the Verilog-A/device-model side of the workflow and resistance-level handling used by the research code. They are provided without proprietary PDK or simulator environment files.

## 5. Verilog-A Device/Model Support

The public Verilog-A model files are stored in:

- `src/veriloga/`

These files are reference/model artifacts from the research workflow. They may require simulator-specific configuration and compatible model libraries to run in a real circuit environment.

## 6. Spectre-Based Neuron and Crossbar Workflow

Relevant files include:

- `spectre_templates/README.md`
- `spectre_templates/netlist_templates/crossbar_neuron_template.scs`
- `spectre_templates/run_scripts/run_spectre_template.sh`

These are sanitized templates. They use placeholders and environment variables instead of private paths. They are intended as workflow documentation and starting templates, not ready-to-run simulator decks.

Additional circuit-oriented workflow scripts include:

- `src/matlab/software_model/spectre_infer.m`
- `src/matlab/software_model/run_spectre_crossbar_infer_norm.m`
- `src/matlab/software_model/energy_per_neuron.m`
- `src/matlab/analysis/plot_integration.m`
- `src/matlab/analysis/counterpart_integration_plot.m`

These scripts appear to generate, run, or analyze circuit-level neuron/crossbar simulations. Full execution requires external Cadence/Spectre, a compatible 130 nm PDK/ODK, and generated simulator outputs that are intentionally not included.

## 7. MATLAB-Based Waveform Parsing and Analysis

Relevant files include:

- `src/matlab/analysis/find_spike_time_num.m`
- `src/matlab/analysis/find_missing_spike_time_num.m`
- `src/matlab/analysis/extract_mc_vout_rise_diff.m`
- `src/matlab/analysis/compare_two_print_membrane_shift.m`
- `src/matlab/analysis/collect_net6_slope_all_prints.m`
- `src/matlab/analysis/capture_summary.m`

These scripts are intended for parsing generated waveform or `.print` outputs, extracting spike timing, comparing membrane behavior, and summarizing simulation metrics.

## 8. System-Level Trajectory Evaluation

Representative public figures are stored in:

- `figures/paper_figures/fig03_system_level_result_1.png`
- `figures/paper_figures/fig04_system_level_result_2.png`

The repository includes selected public figures and workflow scripts, but not the full private dataset/run environment used for all trajectory evaluations.

## 9. Monte Carlo / Variation Analysis

Relevant files include:

- `src/matlab/analysis/monte_carlo_neuron.m`
- `src/matlab/analysis/monte_carlo_data_collect.m`
- `src/matlab/software_model/run_sim_crossbar_infer_norm_mc.m`

These files indicate Monte Carlo or variation-oriented analysis flows. Generated Monte Carlo outputs are not included.

## 10. Public Figures and Documentation

Public-facing documentation and figures are stored in:

- `README.md`
- `docs/`
- `figures/paper_figures/`
- `audit/figure_inventory.csv`

Internal release-curation records are stored under `audit/`.

## Boundary Between Included and External Components

Included:

- MATLAB workflow files
- Verilog-A model files
- sanitized Spectre templates
- small public CSV examples
- manually curated figures and documentation

External or omitted:

- Cadence/Spectre installation
- 130 nm PDK/ODK files
- license and environment files
- raw simulator outputs
- generated `.print`, `.mat`, `.fig`, and run directories
