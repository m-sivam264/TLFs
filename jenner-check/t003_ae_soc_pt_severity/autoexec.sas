/* cap input rows for the captured run */
options obs=100;

/* Bundle setup: stand in for the external `adam` ADaM library with small mocks
   of ADSL (Safety Population) and ADAE (treatment-emergent AEs). Built into a
   real libref so the program's own `proc datasets lib=work kill;` does not
   touch them, exactly as the source library was separate from WORK.
   ADSL columns read: usubjid, saffl, trt01a, subjid.
   ADAE columns read: usubjid, trtemfl, aesoc, aedecod, aesev.
   trt01a values TTA/TTB match the tta/ttb report columns the program builds; a
   Total column is added by the program's double OUTPUT. */
libname adam './lib';

data adam.adsl_sm_mock;
  length usubjid $20 subjid $8 saffl $1 trt01a $10;
  infile datalines dsd truncover;
  input usubjid $ subjid $ saffl $ trt01a $;
datalines;
STUDYX-01-001,01-001,Y,TTA
STUDYX-01-002,01-002,Y,TTA
STUDYX-01-003,01-003,Y,TTB
STUDYX-01-004,01-004,Y,TTB
;
run;

data adam.adae_sm_mock;
  length usubjid $20 trtemfl $1 aesoc $60 aedecod $60 aesev $10;
  infile datalines dsd truncover;
  input usubjid $ trtemfl $ aesoc $ aedecod $ aesev $;
datalines;
STUDYX-01-001,Y,GASTROINTESTINAL DISORDERS,NAUSEA,MILD
STUDYX-01-001,Y,NERVOUS SYSTEM DISORDERS,HEADACHE,MODERATE
STUDYX-01-002,Y,GASTROINTESTINAL DISORDERS,NAUSEA,MODERATE
STUDYX-01-002,Y,GASTROINTESTINAL DISORDERS,DIARRHOEA,MILD
STUDYX-01-003,Y,NERVOUS SYSTEM DISORDERS,HEADACHE,SEVERE
STUDYX-01-003,Y,GASTROINTESTINAL DISORDERS,NAUSEA,MILD
STUDYX-01-004,Y,NERVOUS SYSTEM DISORDERS,DIZZINESS,MILD
;
run;
