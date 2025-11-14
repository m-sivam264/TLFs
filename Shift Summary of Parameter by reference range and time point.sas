
proc datasets lib=work kill nolist;
run;

libname adam "D:\PROJECT_SDTM_20_09_2025\DATA\ADaM";

/*proc contents data = adam.adlb_f_lvs; run;*/

/* ADSL */
proc sort data=adam.adsl_sm_mock(where=(saffl='Y')) out=adsl;
  by usubjid;
run;

/* ADLB */
proc sort data=adam.adlb_f_tulasi out=adlb;
  by usubjid;
run;

data adlb;
  set adlb;
  usubjid = substr(usubjid, 1, 8) || substr(usubjid, 10);
  studyid = substr(studyid, 1, 8);
run;

/* Merge Safety Population */
data adlb2;
  merge adlb(in=a) adsl(in=b);
  by usubjid;
  if a and saffl ne '';
run;

/* Baseline and Postbaseline */

data base post;
	length basecat postcat $ 10.;
  set adlb2;
  if ABLFL='Y' then basecat=anrind;
  else if ABLFL='' and BASE ne . then postcat=anrind;
run;

/*proc sql;*/
/*  create table shift as*/
/*  select a.usubjid, a.param, a.basecat, b.postcat, b.avisit, b.trt01a*/
/*  from base a*/
/*  inner join post b*/
/*  on a.usubjid=b.usubjid and a.paramcd=b.paramcd;*/
/*quit;*/

proc sql;
  create table shift as
  select a.usubjid, a.param, a.basecat, b.postcat, b.avisit, b.trt01a
  from base a
  inner join post b
    on a.usubjid = b.usubjid and a.paramcd = b.paramcd and a.trt01a = b.trt01a;
quit;



data shift_base;
  set shift;
  if missing(basecat) then basecat = 'Missing';
  if missing(postcat) then postcat = 'Missing';
  *if avisit eq '' then avisit = post_visit;
run;

/* Frequency Count of Base × Post Categories */
proc sort data=shift_base;
  by param avisit trt01a;
run;

proc freq data=shift_base noprint;
  by param avisit trt01a;
  tables basecat*postcat / out=shift_counts;
run;

proc sort data=shift_counts;
  by param avisit trt01a basecat;
run;

/*Row Totals for Percent */
proc summary data=shift_counts nway;
  by param avisit trt01a basecat;
  var count;
  output out=rowtotals(drop=_:) sum=row_total;
run;


data shift_pct;
  merge shift_counts rowtotals;
  by param avisit trt01a basecat;

  pct = 100 * count / row_total;
  format pct 6.1;
  cntpct = catx(' ', put(count, 3.), '(', put(pct, 5.1), ')');
run;

proc sort data=shift_pct;
  by param avisit trt01a basecat postcat;
run;

/*Transpose Post Categories into Columns */
proc transpose data=shift_pct out=shift_table(drop=_name_) prefix=post_;
  by param avisit trt01a basecat;
  id postcat;
  var cntpct;
run;

data shift_table2;
	set shift_table;
/*	if upcase(basecat) ne "MISSING" then do;*/
/*	array cols{3} post_LOW post_NORMAL post_HIGH;*/
/*	Total = 0;*/
/*	do i= 1 to 3;*/
/*		if not missing (cols[i]) then Total = Total + input(scan(cols[i], 1, '('), best.);*/
/*	end;*/
/*	end;*/
run;

data new;
	set shift_table2;
	*Total1 = put(Total, best.);
	basecat = upcase(basecat);
	*drop i total; 
run;


/*Build skeleton block*/
proc sql;
  create table dummy as
/*  select distinct param, avisit,*/
/*         param as label length=40, 1 as order*/
/*  from shift_table*/
/*  union corr*/
  select distinct param, avisit, trt01a,
         "    Time Point: " || propcase(strip(avisit)) as label, 2 as order
  from shift_table
  order by param, avisit, trt01a, order;
quit;

/* Category Labels */
data categories;
  length cat $8;
  input cat $ order;
  datalines;
Low 3
Normal 4
High 5
Total 6
Missing 7
;
run;

proc sql;
  create table skeleton as
  select 
      a.param,
      a.avisit, trt01a,
      a.label as param_label,
      upcase(b.cat) as cat,
      b.order as cat_order
  from dummy as a,
       categories as b
  order by param, avisit, trt01a, cat_order;
quit;

proc sql;
  create table dummy2 as
  select distinct param, avisit, trt01a,
         param as param_label length=40, 1 as cat_order
  from shift_table
  union corr
  select distinct param, avisit, trt01a,
         "    Time Point: " || propcase(strip(avisit)) as param_label, 2 as cat_order
  from shift_table
  order by param, avisit, trt01a, cat_order;
quit;

/*final skeleton*/
data sk;
	set dummy2 skeleton;
run;

proc sort data = sk; by param avisit cat_order; run;

/* Merge Labels with skeleton */
proc sort data=new; by param avisit trt01a basecat; run;
proc sort data=sk; by param avisit trt01a cat; run;

data wwww;
	merge sk (in=a) new (in=b rename=(basecat=cat /*total1 = total*/));
	by param avisit trt01a cat;
	*if trt01a = 'TTB';
run;

proc sort data = wwww; by param avisit cat_order; run;

/* total rows - counting*/
data new_nomissings;
  set new;
  if basecat not in ("MISSING", "Missing");
run;

proc sql;
  create table total_rows as
  select 
      param,
      avisit,
      trt01a,
      put(sum(input(scan(post_low,1,'('),best.)), best.)     as post_low,
      put(sum(input(scan(post_normal,1,'('),best.)), best.)  as post_normal,
      put(sum(input(scan(post_high,1,'('),best.)), best.)    as post_high,
      "TOTAL"  as basecat length=8,
      6        as cat_order
  from new_nomissings
  group by param, avisit, trt01a;
quit;

proc sort data=wwww; by param avisit trt01a cat; run;
proc sort data=total_rows; by param avisit trt01a basecat; run;

data nnnn;
	retain param_label post_low post_normal post_high Total post_Missing;
	merge wwww (in=a) total_rows (in=b rename=(basecat=cat));
	by param avisit trt01a cat;
	if cat ne '' then param_label = "        " || cat;
	avisitn = input(compress(avisit,,'kd'), best.);
	*if trt01a = 'TTB';
	*drop param trt01a cat cat_order avisit;
run;

data final;
	set nnnn;
	post_LOW = left(post_LOW);
	post_NORMAL = left(post_NORMAL);
	post_High = left(post_high);
/*	Total = left(total);*/
	if index(post_missing, '(') then post_missing = left(scan(post_missing, 1, '(')); else post_missing = left(post_missing);
	
	if upcase(CAT) ne "MISSING" then do;
	    array col{3} post_LOW post_NORMAL post_HIGH;
	    Total1 = 0;
	    do i = 1 to 3;
	        temp = scan(col[i], 1, '(');
	        if not missing(temp) and compress(temp, '0123456789.') = '' then 
	            Total1 + input(temp, best.);
	    end;
	end;
run;

data final_order;
	set final;
	TOTAL = put(Total1, best.);
	if strip(param_label) in ("LOW", "NORMAL", "HIGH", "TOTAL", "MISSING") then do;
		array cols{5} post_LOW post_NORMAL post_HIGH Total post_Missing;
		do i= 1 to 5;
			if missing (cols[i]) or cols[i] eq '.' then cols[i] = "0";
		end;
	end;

	if post_LOW eq '' then Total = '';
run;

proc sql;
  create table latest_visits as
  select param, trt01a, max(avisitn) as latest_avisitn
  from final_order
  group by param, trt01a;
quit;

proc sql;
  create table final_latest as
  select f.*
  from final_order as f
  inner join latest_visits as l
    on f.param = l.param and f.trt01a = l.trt01a and f.avisitn = l.latest_avisitn;
quit;


data final_para;
	retain param_label post_low post_normal post_high Total post_Missing;
	set final_latest;
	*if param = "Hemoglobin(g/L)" and trt01a = 'TTA'; /* select parameter and TReatment Arm you want to look for*/
	*i = _n_;
run;

proc sort data = final_para; by param; run;
proc sort data = adlb (keep = param parcat1) out = parcats; by param; run;

data new_origin;
	merge final_para (in=a) parcats(in=b);
	by param;
	if a;
	if parcat1 = "HEMATOLOGY" and trt01a = 'TTA'; /* select parameter and TReatment Arm you want to look for*/
run;

proc sort data = new_origin; by param avisit cat_order; run;

data _null_;
  call symputx('gen_time', put(datetime(), e8601dt.));
run;

ods rtf close;
ods escapechar='^';

ods rtf file="D:\PROJECT_SDTM_20_09_2025\DATA\TLFs\Shift Summary of Parameter by reference range and time point.rtf"
        style=journal;
options orientation=landscape;

footnote1 j=left "^S={font_size=8pt}__________________________________________________________________________________________________________________________________________________________________________________";
footnote2 j=left "^S={font_size=8pt color=black}Source: Table 14.3.2.4  |  Dataset: ADAE";
footnote3 j=left "^S={font_size=8pt color=black}Program: TABLE 14.3.3.1.1 LAB RESULTS RESULTS BY TIMEPOINT.sas  |  Output: TABLE 14.3.3.1.1 LAB RESULTS RESULTS BY TIMEPOINT.rtf";
footnote4 j=left "^S={font_size=8pt color=black}Generated on: &gen_time";

options nodate nonumber;

proc report data = new_origin nowd headline headskip split="*" spacing=2
    style(report)={frame=void cellspacing=3 cellpadding=2 width=100%}
    style(header)={background=white};
  column param_label post_low post_normal post_high Total post_Missing;

  define param_label / "Lab Parameter (Unit)*Time Point*Baseline Value * [n (%)]"
                 style(header)=[just=center cellwidth=20% font_weight=bold]
                 style(column)=[cellwidth=20% just=left asis=on];

  define post_low / display "Low"
                style(header)=[just=left cellwidth=10% font_weight=bold]
                style(column)=[cellwidth=10% just=left];

  define post_normal / display "Normal"
                style(header)=[just=left cellwidth=10% font_weight=bold]
                style(column)=[cellwidth=10% just=left];

  define post_high / display "High"
                 style(header)=[just=left cellwidth=10% font_weight=bold]
                 style(column)=[cellwidth=10% just=left];

  define Total / display "Total"
                style(header)=[just=left cellwidth=10% font_weight=bold]
                style(column)=[cellwidth=10% just=left];

  define post_Missing / display "Missing"
                 style(header)=[just=left cellwidth=10% font_weight=bold]
                 style(column)=[cellwidth=10% just=left];

  title1 j=left height=2 color=black bold "Output ID: PRA-STD-T-016-ADSL-001"
         j=right height=2 color=black bold "Output Name: AE by SOC/PT/Severity";
  title2 j=center height=3 color=black bold "Table 14.3.2.4 Shift Summary by Reference Range";
  title3 j=center height=3 color=black bold "(Safety Set)";

  compute before _page_;
     line @1 151*'_';
  endcomp;

run;

footnote;
ods rtf close;
