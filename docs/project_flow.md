# Project Flow

The public repository documents the original research workflow at a code-and-template level:

1. MATLAB scripts represent software/circuit analysis tasks, including IF-neuron simulation, crossbar-oriented workflows, waveform parsing, Monte Carlo analysis, spike-time extraction, and plotting.
2. Verilog-A files provide public model references used in the research workflow.
3. Mapping and analysis scripts connect software-level SNN behavior to memristive/RRAM-oriented circuit experiments.
4. Spectre templates show how circuit simulation jobs are structured after users configure their own licensed simulator and PDK/ODK paths.
5. Audit files document which source files were copied, which manually curated figures were included, and which private or generated artifacts were excluded.

Several MATLAB scripts expect generated `.print` or MATLAB data files from external simulations. Those generated artifacts are not included in the public release because they are large, local, or tied to licensed tool environments.
