proc datasets lib = work kill;

libname adam2 'C:\Users\sivam\Downloads\tables_sru\tables_sru\Adam Data';
libname tlfs 'C:\Users\sivam\Downloads\tables_sru\tables_sru\Adam Data\SIVA_07_10_2025';

proc sort data = adam2.adsl out = adsl;
	by USUBJID;
	where SAFFL = 'Y';
run;

data ads;
	set adsl;
	output;
	TRT01A = 'OVERALL';
	TRT01AN = 99;
	output;
run;

proc sql;
	select count(USUBJID) into : N1 from ads where TRT01A = 'PLACEBO';
	select count(USUBJID) into : N2 from ads where TRT01A = '100 MG BP3304';
	select count(USUBJID) into : N3 from ads where TRT01A = 'OVERALL';
quit;

%put &N1 &N2 &N3;

/*CATEGORY*/

%macro frqs(var=, out=);
	proc freq data = ads noprint;
		table TRT01AN * &var. / out = &out.;
	run;

	proc sort data = &out.;
		by &var.;
	run;

	proc transpose data = &out. out = &out.1;
		id TRT01AN;
		var count;
		by &var.;
	run;
%mend frqs;

%frqs (var=SEX, out = se);
%frqs (var=RACE, out = RC);
%frqs (var=ETHNIC, out = ET);

data all;
	length new $ 50.;
	set se1 rc1 et1;

	if SEX = 'M' then do; NEW = '  Male'; order = 2.1; end;
	else if SEX = 'F' then do; NEW = '  Female'; order = 2.2; end;

	if ETHNIC = 'HISPANIC OR LATINO' then do; NEW = "  Hispanic or Latino"; order = 3.1; end;
	else if ETHNIC = 'NOT HISPANIC OR LATINO' then do; NEW = '  Not Hispanic or Latino'; order = 3.2; end;

	if RACE = 'ASIAN' then do; NEW = '  Asian'; order = 4.3; end;
	else if RACE = 'WHITE' then do; NEW = '  White'; order = 4.1; end;

	keep _1 _0 _99 NEW order;
run;

data dummy;
	order = 4.2; NEW = '  Black or African American';output;
	order = 4.4; NEW = '  American Indian or Alaskan Native';output;
	order = 4.5; NEW = '  Native Hawaiian or Other Pacific Islander';output;
	order = 4.6; NEW = '  Other';output;
run;

data all2;
	set all dummy;

	if not missing(_1) then _1c = strip(put(_1, best.)) || ' (' || strip(put(100*_1 / &N1, 5.1)) || ')'; else _1c = '0';
	if not missing(_0) then _0c = strip(put(_0, best.)) || ' (' || strip(put(100*_0 / &N2, 5.1)) || ')'; else _0c = '0';
	if not missing(_99) then _99c = strip(put(_99, best.)) || ' (' || strip(put(100*_99 / &N1, 5.1)) || ')'; else _99c = '0';

	drop _1 _0 _99;
run;

/********************************************************************************/
data dumm2;
	length new $ 50.;
	new = 'Age (years)'; order = 1.0; output;
	new = 'Gender [n (%)]a'; order = 2.0; output;
	new = 'Ethnicity [n (%)]a'; order = 3.0; output;
	new = 'Race [n (%)]a'; order = 4.0; output;
run;

data all3;
	set dumm2 all2;
run;

proc means data = ads noprint;
	class TRT01AN;
	var AGE;
	output out = age_st n = N1 mean = MEAN1 MIN = MIN1 MAX = MAX1 STD = SD MEDIAN = MED;
run;

data ag;
	set age_st;
	where not missing(TRT01AN);
	N_ = strip(put(N1, best.));
	MEAN_SD = strip(put(MEAN1, 5.1)) || ' (' || strip(put(SD, 5.2)) || ')';
	MED_ = strip(put(MED, 5.1));
	MIX_MAX = strip(put(MIN1, best.)) || ', ' || strip(put(MAX1, best.));

	drop N1 MEAN1 MIN1 MAX1 SD MED _TYPE_ _FREQ_ ;
run;
	
proc transpose data = ag out = age_trns;
	id TRT01AN;
	var N_ MEAN_SD MED_ MIX_MAX;
run;

data age;
	length new $ 50.;
	set age_trns (rename = (_NAME_ = new));
	_1c = _1;
	_0c = _0;
	_99c = _99;

	if new = 'N_' then do; new = '  N'; order = 1.1; end;
	else if new = 'MEAN_SD' then do; new = '  Mean (SD)'; order = 1.2; end;
	else if new = 'MED_' then do; new = '  Median'; order = 1.3; end;
	else if new = 'MIX_MAX' then do; new = '  Min, Max'; order = 1.4; end;
	drop _1 _0 _99;
run;

data space;
order = 1.5;output;
order = 2.3;output;
order = 3.3;output;

/*order = 4.7;output;*/
run;

data all4;
	set all3 age space;
	BP3304 = _1c;
	Placebo = _0c;
	Overall = _99c;

	drop _1c _0c _99c;
run;

proc sort data = all4 out = table;
	by order;
run;

ods rtf file="D:\PROJECT_SDTM_20_09_2025\demographics_safety.rtf" style=journal ;
options orientation = protrait;
title1 j = l 'Bigg Pharmaceutical Company'  j=r 'Date: ddMONyyyy';
title2 j = l 'BP3304-002' j = r 'Program xxxxxxxx.SAS';
title3 j = r 'Page X of Y';

title4 j = c '14.1.2.1  Subject Demographics and Baseline Characteristics';
title5 j = c 'Safety Population';

footnote1 j = c 'Reference: Listing 16.2.4.1';
footnote2 j = c 'Percentages are based on the number of subjects in the population.';
footnote3 j = c 'Note:  SD = standard deviation, Min = Minimum, Max = Maximum.';

proc report data = table nowd style(header)=[font_weight=bold];
  columns new BP3304 Placebo Overall;

  define new  / display '';
  define BP3304    / display "BP3304/N=03";
  define Placebo   / display "Placebo/N=03";
  define Overall   / display "Overall/N=06";
run;

ods rtf close;

/***********************************************************************************************/

ods rtf file="D:\PROJECT_SDTM_20_09_2025\14_1_2_1_Demographics.rtf" style=journal bodytitle;
options orientation = landscape;
title1 j = l 'Bigg Pharmaceutical Company'  j = r 'Date: ddMONyyyy';
title2 j = l 'BP3304-002' j = r 'Program xxxxxxxx.SAS';
title3 j = r 'Page X of Y';

title4 j = c '14.1.2.1  Subject Demographics and Baseline Characteristics';
title5 j = c 'Safety Population';

proc report data = table nowd style(header)=[font_weight=bold] style(column)=[cellheight=0.2in];
  columns new order bp3304 placebo overall;

/*  define order / group noprint;*/
  
  define new / display " " style(column)=[asis = on cellwidth = 2.5in];
  define bp3304 / display "BP3304/N=03" style(column)=[cellwidth=1.2in just=center];
  define placebo / display "Placebo/N=03" style(column)=[cellwidth=1.2in just=center];
  define overall / display "Overall/N=06" style(column)=[cellwidth=1.2in just=center];
  
  compute new;
  		if new in ("Age (years)", "Gender [n (%)]a", "Ethnicity [n (%)]a", "Race [n (%)]a") then
  		call define(_col_, "style", "style=[font_weight=bold]");
  endcomp;

/*  define new / display style(header)=[font_weight=bold];*/
/*  break after order / skip;*/
run;

footnote1 j = l "         Reference: Listing 16.2.4.1";
footnote2 j = l "         Note: SD = standard deviation, Min = Minimum, Max = Maximum.";
footnote3 j = l "         Percentages are based on the number of subjects in the population.";


ods rtf close;
/***********************************************************************************************/
 
