##Simulation Tests and Results

The tests cover the system at the chosen steady-state and several deviations from the steady-state.   

###Tests at the steady-state
The steady-state is defined by the file SystemSS.json   
Tests A are at the steady-state for variables.   

Test | Fraction of ynom | Tax percentage | Agents | K Periods   
---- | ---------------- | -------------- | ------ | ---------   
A0 | 1 | 1 | All | 5
A1 | 1 | 0.9 | All | 5

###Perturbations in ynom
Tests B simulate unit impulse perturbations in ynom.   

Test | Fraction of ynom | Tax percentage | Agents | K Periods   
---- | ---------------- | -------------- | ------ | ---------   
B1 | 0.5 | 1 | 1 | 5

###Perturbations in the initial state of input stores
Tests C simulate impulse perturbations in the initial state of the input stores.

Test | Agent | Product | Fraction of SS value for production | K Periods   
---- | ----- | ------- | ----------------------------------- | ---------   
C1 | 2<br/>3<br/>3<br/>3<br/>5 | E<br/>E<br/>A<br/>B<br/>E | 0.5(45+2)<br/>0.5(20+2)<br/>0.5(10)<br/>0.5(15)<br/>0.5(20+2) | 5
C1.1 | 2<br/>3<br/>3<br/>3 | E<br/>E<br/>A<br/>B | 0.5(45+2)<br/>0.5(20+2)<br/>0.5(10)<br/>0.5(15) | 5
C2 | 2<br/>3<br/>3<br/>3 | E<br/>E<br/>A<br/>B | 1.5(135+2)<br/>1.5(60+2)<br/>1.5(30)<br/>1.5(45) | 5
C3 | 5 | E | 1.5(60+2) | 5
C4 | 2<br/>3<br/>3<br/>3<br/>5 | E<br/>E<br/>A<br/>B<br/>E | 1.5(135+2)<br/>1.5(60+2)<br/>1.5(30)<br/>1.5(45)<br/>1.5(60+2) | 5

