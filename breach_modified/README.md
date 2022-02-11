# README #

Breach is a Matlab toolbox for time series analysis and simulation-based analysis of dynamical/CPS/Hybrid systems. It can be useful to the prospective user (you) in the following situations:
- You have **time series data** and wants to check whether it satisfies some property 
- You need **signal temporal logic (STL) monitoring capability**, e.g., to check formal requirements on your data
- You have a **Simulink models** and wants to perform **extensive testing** by running multiple simulations (e.g., parameter sweep) and quickly browse through the results, and/or assert whether some (STL) property is satisfied by simulations (random/Monte-Carlo testing) 
- You need to **falsify** an STL requirement using various optimization algorithm, i.e., find **test cases of interest** 
- You want to do some or all of the above to for a model implemented with **a  simulator other than Simulink**.

The following describes the initial steps to get started with the above tasks.

# First Steps

## Setup 
To setup and use Breach, start Matlab and run `InitBreach` from the main Breach folder. This needs only to be done once per Matlab session.

## Builtin Demos and Documentation
Type `BrDemo.` and `Tab` key to get a list of available scripts to run for testing and demoing the toolbox. E.g.,
```
>> BrDemo.AFC_1_Interface
```
Running ̀`GenDoc()` will run all demos and publish results into the `Doc/index.html` folder. It can take a while though. 

## Contact/Support
Contact info at decyphir dot com to report bugs, for help, complaints, support, etc.


# Importing time series data 

# Writing Signal Temporal Logic Formulas

# Simulink Model Testing and Falsification

# Interfacing a generic CPS simulator
