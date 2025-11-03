proc datasets lib = work kill;
/*libname adam "D:\PROJECT_SDTM_20_09_2025\DATA\ADaM";*/

/*Safety population */
proc sort data = adam.adsl_sm_mock (where = (saffl = "Y")) out = adsl;
  by usubjid;
run;

data adsl2;
  set adsl;
  output;
  trt01a = "Total";
  output;
run;

/*Treatment emergent from ADAE*/
proc sort data = adam.adae_sm_mock (where = (trtemfl = "Y")) out = adae;
  by usubjid;
run;
/* merge TRTEMFL SAFFL*/
data adae;
  merge adae(in = a) adsl(in = b keep = usubjid saffl trt01a subjid);
  by usubjid;
  if a and saffl = "Y";
run;

/* for Total column*/
data adae2;
  set adae;
  output;
  trt01a = "Total";
  output;
run;

/* AE-level counts for All AEs */
proc freq data = adae2 order = freq noprint; 
   tables trt01a * aesev / out = freq_allaes; 
run;

data any_ae;
    length label $200 aesoc $60 aedecod $60 aesev $40;
    set freq_allaes;
    aesoc = "";
    aedecod = "";
    n = count;
    ord = 1;
    label = "Any Adverse Events";
    aesev = propcase(aesev);
	drop count percent;
run;

/* SOC-level counts */
proc freq data = adae2 order = freq noprint; 
   tables trt01a * aesoc * aesev / out = freq_socae ;
run;
data soc_ae;
    length label $200 aesoc $60 aedecod $60 aesev $40;
    set freq_socae;
    aedecod = "";
	n = count;
    ord = 2;
    label = propcase(aesoc);
    aesev = propcase(aesev);
	drop count percent;
run;

/*PT-level counts */
proc freq data = adae2 order = freq noprint; 
   tables trt01a * aesoc * aedecod * aesev / out = freq_ptaes ;
run;
data pt_ae;
    length label $200 aesoc $60 aedecod $60 aesev $40;
    set freq_ptaes;
	n = count;
    ord = 3;
    label = "      " || propcase(aedecod);
    aesev = propcase(aesev);
	drop count percent;
run;

/*Stack all */
data all_together;
    length label $200 aesoc $60 aedecod $60 aesev $40;
    set any_ae soc_ae pt_ae;
run;

/*proc sort data = all_together;*/
/*    by trt01a ord aesoc aedecod aesev;*/
/*run;*/

/* bringing all severity terms */

data severity;
  length AESEV $40 ORD 8;
  AESEV = 'Mild'; ORD1 = 1.1; output;
  AESEV = 'Moderate'; ORD1 = 1.2; output;
  AESEV = 'Severe'; ORD1 = 1.3; output;
  AESEV = '[Fatal]'; ORD1 = 1.4; output;
  AESEV = '[Life Threatening]'; ORD1 = 1.5; output;
run;


proc sql;
  create table ae_expand_sev as
  select distinct a.trt01a, a.label, a.aesoc, a.aedecod, a.n, a.aesev, a.ord, b.aesev as sev1, b.ord1
  from all_together as a, severity as b;
quit;

data for_n;
	set ae_expand_sev;

	if aesev ne sev1 then n = 0;
	drop aesev;
run;
/* Add % values (denominator per trt) */
proc sql;
	create table arm_counts as
	select trt01a, count(distinct usubjid) as count_1
	from adsl2
	group by trt01a;
quit;

data val;
	length value $ 10.;
	merge arm_counts for_n;
	by trt01a;
	if n > 0 then value = strip(put(n, best.))||' ('||strip(put(n/count_1*100, 4.1))||')';
	else value = '0';
run;

/*Transpose for report */
proc sort data = val out = ordered_ae; 
  by aesoc aedecod ord label sev1;
run;


proc sort data = ordered_ae out = extracted_ae nodupkey;
	by trt01a label aesoc aedecod sev1 ord descending n;
run;

data hi;
	set extracted_ae;
	by trt01a label aesoc aedecod sev1;

	if first.sev1;
run;

proc sort data = hi out = hi_ae;
	by label aesoc aedecod sev1 ord;
run;

proc transpose data = hi_ae out = trans_ae;
	by label aesoc aedecod sev1 ord ord1;
	id trt01a;
	var value;
run;

proc sort data = trans_ae out = ordered;
	by aesoc aedecod ord;
run;

data ordered_table;
	set ordered;
	ord = _n_;
run;

data final_table(drop=_name_ aedecod aesoc);
	set ordered_table;
	array terms tta ttb total;
	do over terms;
		if missing(terms) then terms='0';
	end;
run;

/*Dummy rows if needed */
data dummy;
	retain ord;
	do ord = 5.1 to 54 by 5;
		output;
	end;
run;

/*Final sort & label formatting */
proc sort data = final_table; by label ord; run;

data table2;
	set final_table;
	by label;
	if first.label then label = label;
	else label = '';
run;

data final;
	set table2 dummy;
run;

proc sort data = final; by ord; run;

ods rtf close;
ods rtf file ="D:\PROJECT_SDTM_20_09_2025\DATA\TLFs\Table_14.3.2.4_TRTEMFL_AE_BySOC_PT_Severity.rtf"
  style=journal;
options orientation=landscape;

proc report data = final nowd headline headskip split = "*" spacing=2 
	style(report)={frame=void cellspacing=3 cellpadding=2 width=100%}
	style(header)={background=white};
	column (label sev1 tta ttb total);

	define label / style(header)=[just=left cellwidth=20% font_weight=bold] 
	               "System Organ Class*Preferred Term [n (%)]"
	               style(column)=[cellwidth=20% just=left asis=on];
	define sev1 / style(header)=[just=left cellwidth=20% font_weight=bold]
	               "Maximum*Severity"
	               style(column)=[cellwidth=20% just=left asis=on];
	define tta /display "Trt A*(N=2)" 
	            style(column)=[cellwidth=10% just=center]
	            style(header)=[just=center cellwidth=10% font_weight=bold];
	define ttb /display "Trt B*(N=2)"
	            style(column)=[cellwidth=10% just=center]
	            style(header)=[just=center cellwidth=10% font_weight=bold];
	define total /display "Total*(N=4)"
	              style(column)=[cellwidth=10% just=center]
	              style(header)=[just=center cellwidth=10% font_weight=bold];

title1 j=left height=2 color=black bold "Output ID: PRA-STD-T-016-ADSL-001"
       j=right height=2 color=black bold "Output Name: AE by SOC/PT/Severity";
title2 j=center height=4 color=black bold "Table 14.3.2.4 [Treatment-Emergent] Adverse Events by System Organ Class, Preferred Term, and Maximum Severity";
title3 j=center height=4 color=black bold "(Safety Set)";

compute after _page_;
line @1"Source: Table 14.3.2.4, Dataset: ADAE, Program: Table 14.3.2.4 [Treatment-Emergent] Adverse Events By System Organ Class, Preferred Term and Maximum Severity - Option 1.sas, Output: Table_14.3.2.4_TRTEMFL_AE_BySOC_PT_Severity.rtf, Generated on: &gen_time";
endcomp;
run;

ods rtf close;
