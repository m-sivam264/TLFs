/* cap input rows for the captured run */
options obs=100;

/* Bundle setup: stand in for the external `adam` ADaM library with a small
   in-WORK mock of ADSL (columns the listing reads). Mirrors adsl_sm_mock. */
data adam_adsl_sm_mock;
  length usubjid $20 subjid $8 race $30 sex $1 trt01p $20;
  infile datalines dsd truncover;
  input usubjid $ subjid $ race $ age sex $ trt01p $ brthdt :date9. weightb heightb fasfl $;
  format brthdt date9.;
datalines;
STUDYX-01-001,01-001,WHITE,45,M,TRT A,12FEB1979,78.4,181.0,Y
STUDYX-01-002,01-002,BLACK OR AFRICAN AMERICAN,52,F,TRT A,03JUN1972,66.1,165.5,Y
STUDYX-01-003,01-003,ASIAN,38,F,TRT B,21NOV1985,54.2,158.0,Y
STUDYX-01-004,01-004,WHITE,61,M,TRT B,09MAR1963,90.7,176.2,Y
STUDYX-01-005,01-005,MULTIPLE,29,F,TRT A,15JUL1994,61.0,170.4,Y
STUDYX-01-006,01-006,UNKNOWN,47,M,TRT B,28SEP1976,,183.0,Y
STUDYX-01-007,01-007,ASIAN,55,M,TRT A,02JAN1969,72.5,,N
STUDYX-01-008,01-008,WHITE,40,F,TRT B,17APR1983,58.9,162.7,Y
;
run;
