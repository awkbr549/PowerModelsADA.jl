# Quick Start Guide

To solve the OPF problem using the ADMM use the solve function `run_dopf_admm`. The solve function stores the result in a data dictionary contains subsystems information.

```julia
using PowerModelsADA
using Ipopt

model_type = ACPPowerModel
result = run_dopf_admm("test/data/case_RTS.m", model_type, Ipopt.Optimizer; print_level=1)
```
