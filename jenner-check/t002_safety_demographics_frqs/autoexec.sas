/* cap input rows for the captured run */
options obs=100;

/* Bundle setup: stand in for the external `adam2` ADaM library with a small
   mock of ADSL (Safety Population). Built into a real libref so the program's
   own `proc datasets lib=work kill;` does not touch it, exactly as the source
   library was separate from WORK. Columns are the ones the program reads:
   USUBJID, SAFFL, TRT01A/TRT01AN, SEX, RACE, ETHNIC, AGE. TRT01AN is 1 for the
   active arm (100 MG BP3304) and 0 for PLACEBO, matching the _1/_0 transpose
   columns the program builds. */
libname adam2 './lib';

data adam2.adsl;
  length usubjid $20 saffl $1 trt01a $20 sex $1 race $12 ethnic $30;
  infile datalines dsd truncover;
  input usubjid $ saffl $ trt01a $ trt01an sex $ race $ ethnic $ age;
datalines;
BP3304-002-001,Y,100 MG BP3304,1,M,WHITE,NOT HISPANIC OR LATINO,54
BP3304-002-002,Y,100 MG BP3304,1,F,ASIAN,HISPANIC OR LATINO,61
BP3304-002-003,Y,100 MG BP3304,1,M,WHITE,NOT HISPANIC OR LATINO,47
BP3304-002-004,Y,PLACEBO,0,F,WHITE,NOT HISPANIC OR LATINO,58
BP3304-002-005,Y,PLACEBO,0,M,ASIAN,NOT HISPANIC OR LATINO,49
BP3304-002-006,Y,PLACEBO,0,F,WHITE,HISPANIC OR LATINO,66
;
run;
