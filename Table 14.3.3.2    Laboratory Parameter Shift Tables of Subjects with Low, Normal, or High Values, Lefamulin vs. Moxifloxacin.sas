proc datasets lib = work kill nolist;

/*filename logfile "Z:\Cardio2026ZG\Code\Dev_Prod\Log\TLFs\Table\Table_14_3_3_2.log";*/
/*proc printto log = logfile new; run;*/

libname adam "Z:\Cardio2026ZG\Data\Dev_Prod\ADaM";
libname tlfs "Z:\Cardio2026ZG\Data\Dev_Prod\TLFs\Tables";

proc sort data = adam.adsl out = adsl; 
    by usubjid; 
    where saffl eq "Y"; 
run;

proc sql noprint;
    select count(usubjid) into :N1 trimmed from adsl where TRT01PN = 1;
    select count(usubjid) into :N2 trimmed from adsl where TRT01PN = 2;
quit;

%put &N1 &N2;

proc sort data = adam.adlb out = adlb;
    by TRT01A PARAM AVISIT;
    where SAFFL = 'Y' and ANL04FL = 'Y' or ANL07FL = 'Y';
run;

data miss;
    set adlb;
    if missing(anrind) then ANRIND = "Missing";
    if missing(bnrind) then BNRIND = "Missing";
    ANRIND = propcase(ANRIND);
    BNRIND = propcase(BNRIND);
    if not missing(AVISIT) and AVISIT ne "Unscheduled" and AVISIT ne "Day 6" and AVISIT ne "LFU" and not missing(TRT01A);
run;

proc freq data = miss noprint;
    by TRT01A PARAM AVISIT;
    table bnrind * anrind / out = shift_sum;
run;

data shift_pct;
    set shift_sum;
    if not missing(AVISIT) and TRT01A = "LEFAMULIN" then _count = put(count, best.) || " (" || strip(put(100 * count / &N1 , F8.1)) || ")";
    if not missing(AVISIT) and TRT01A = "MOXIFLOXACIN" then _count = put(count, best.) || " (" || strip(put(100 * count / &N2 , F8.1)) || ")";
    idVar = catx("_", TRT01A, ANRIND);
    if avisit ne "Baseline";
    drop percent count;
run;

proc sort data = shift_pct;
    by PARAM avisit bnrind;
run;

proc transpose data = shift_pct out = shift_tr;
    by PARAM avisit bnrind;
    var _count;
    id idVar;
run;

data skeleton;
    length bnrind $ 200.;
    input bnrind $ ord;
    datalines;
Low 3
Normal 4
High 5
Missing 6
;
run;

proc sql;
    create table skull as
    select distinct PARAM, AVISIT, propcase(AVISIT) as LABEL, 2 as ord 
    from shift_pct
    order by PARAM, AVISIT;
quit;

proc sql;
    create table skipping as
    select a.param, a.avisit, a.label as para_label, a.ord, b.bnrind as basecat, b.ord as baseord
    from skull as a, skeleton as b
    order by param, avisit, basecat;
quit;

proc sort data = shift_tr;
    by param avisit bnrind;
run;

proc sort data = skipping;
    by param avisit basecat;
run;

data match;
    merge skipping (in=a rename=(basecat=bnrind)) shift_tr (in=b);
    by param avisit bnrind;
    if a;
run;

proc sort data = match;
    by param avisit baseord;
run;

data image;
    set match;
    array mis(*) L: M:;
    do i = 1 to dim(mis);
        if mis(i) = "" then mis(i) = "0";
        mis(i) = left(mis(i));
    end;
run;

proc sql;
    create table fog as
    select distinct param, avisit,
        param as param_label length = 50, 1 as cat_ord
    from image
    union corr
    select distinct param, avisit,
        "  " || propcase(avisit) as param_label length = 50, 2 as cat_ord
    from image
    order by param, avisit, cat_ord;
quit;

data fog;
    set fog;
    if cat_ord = 1 then do;
        if AVISIT in ("Day 7", "EOT", "TOC") then param_label = "";
    end;
run;

data tsunami;
    set image fog (rename = (cat_ord = baseord));
    drop ord para_label i _name_;
run;

proc sort data = tsunami;
    by param avisit baseord;
run;

data tsunami;
    retain param_label baseord LEFAMULIN_Low LEFAMULIN_Normal LEFAMULIN_High LEFAMULIN_missing
           MOXIFLOXACIN_Low MOXIFLOXACIN_Normal MOXIFLOXACIN_High MOXIFLOXACIN_missing;
    set tsunami;
    if missing(param_label) then param_label = "  " || bnrind;
    baseord = _n_;
    drop param avisit bnrind;
run;

data dumb;
    do baseord = 24.2 to 792 by 24;
        output;
    end;
run;

data final;
    set tsunami dumb;
run;

data worst;
    set miss;
    where ABLFL ne "Y";
    ANRIND = propcase(ANRIND);
    BNRIND = propcase(BNRIND);

    if ANRIND = "Missing" then W_Cat = 0;
    if ANRIND = "Low" then W_Cat = 1;
    if ANRIND = "Normal" then W_Cat = 2;
    if ANRIND = "High" then W_Cat = 3;

    if BNRIND = "Missing" then B_Cat = 0;
    if BNRIND = "Low" then B_Cat = 1;
    if BNRIND = "Normal" then B_Cat = 2;
    if BNRIND = "High" then B_Cat = 3;

    keep usubjid trt01a PARAM BNRIND ANRIND W_Cat B_Cat;
run;

proc sort data = worst;
    by usubjid PARAM descending W_Cat;
run;

data worst_resp;
    set worst;
    by usubjid PARAM;
    if first.param;
run;

proc sort data = worst_resp;
    by trt01a PARAM;
run;

proc freq data = worst_resp noprint;
    by trt01a PARAM;
    table B_Cat * W_Cat / out = worst_freq;
run;

data worst_pct;
    set worst_freq;
    if TRT01A = "LEFAMULIN" then _count = left(put(count, best.)) || " (" || strip(put(100 * count / &N1 , F8.1)) || ")";
    if TRT01A = "MOXIFLOXACIN" then _count = left(put(count, best.)) || " (" || strip(put(100 * count / &N2 , F8.1)) || ")";

    if B_Cat = 0 then BNRIND = "Missing";
    if B_Cat = 1 then BNRIND = "Low";
    if B_Cat = 2 then BNRIND = "Normal";
    if B_Cat = 3 then BNRIND = "High";

    if W_Cat = 0 then ANRIND = "Missing";
    if W_Cat = 1 then ANRIND = "Low";
    if W_Cat = 2 then ANRIND = "Normal";
    if W_Cat = 3 then ANRIND = "High";

    idVar = catx(".", TRT01A, ANRIND);
    drop percent;
run;

proc sort data = worst_pct;
    by param B_Cat brnind;
run;

proc transpose data = worst_pct out = worst_tr;
    by param B_Cat brnind;
    var _count;
    id idVar;
run;

data worst_success;
    length param_label $50.;
    set worst_tr;
    array mis(*) L: M:;
    do i = 1 to dim(mis);
        if mis(i) = "" then mis(i) = "0";
        mis(i) = left(mis(i));
    end;
    param_label = "     " || brnind;
    if param_label = "     Missing" then ord = 4;
    if param_label = "     Low" then ord = 1;
    if param_label = "     Normal" then ord = 2;
    if param_label = "     High" then ord = 3;
    drop i _name_ B_Cat;
run;

proc sort data = worst_success;
    by param ord;
run;

data morning;
    set worst_success (drop = ord);
    original = param_label;
    group = floor((_n_ - 1)/4);
    
    if mod(_n_ -1, 4) = 0 then do;
        baseord = 24.01 + group * 24;
        param_label = "";
        output;
        
        baseord = 24.02 + group * 24;
        param_label = "Worst Post - Baseline";
        output;
    end;
    
    baseord = 24.1 + group * 24;
    param_label = original;
    output;
drop param brnind original group;
run;

data Uturn;
    set final morning;
    if param_label = "" or param_label = "Worst Post - Baseline" then do;
        array chars(*) L: M:;
        do i = 1 to dim(chars); chars(i)=''; end;
    end;
    drop i;
run;

proc sort data = uturn; by baseord; run;
/**/
/*data tlfs.Table_l4_3_3_2;*/
/*    set uturn;*/
/*    ord=_n_;*/
/*run;*/
/**/
/*ods rtf close;*/
/**/
/*ods rtf file="Z:\Cardio2026JVG\outputs\Dev_Prod\Tables\Table_14_3_3_2.rtf" style=journal;*/
/*ods escapechar='^';*/
/*options orientation=landscape nodate nonumber*/
/*    rightmargin=0.5in topmargin=0.5in ps=30 ls=100;*/
/**/
/*title1 font='Arial' color=black bold j=l "Table 14.3.3.2    Laboratory Parameter Shift Tables of Subjects with Low, Normal, or High Values, Lefamulin vs. Moxifloxacin (Safety Analysis Set)";*/
/*title2 font='Arial' color=black bold j=l "(Safety Analysis Set)";*/
/**/
/*proc report data=tlfss.Table_14_3_3_2 nowd headskip headline missing spacing=10 split='*' spanrows*/
/*    style(report)={just=center protectspecialchars=off asis=on cellpadding=0 cellspacing=1 width=100% rules=groups frame=void*/
/*    bordertopwidth=1 borderbottomwidth=1 bordertopcolor=black}*/
/*    style(header)={just=center background=white font=fonts('headingfont') protectspecialchars=off asis=on}*/
/*    style(column)={asis=on just=center protectspecialchars=off};*/
/**/
/*    column param_label ord ("Lefamulin* (N=&N1.)*n(%)" LEFAMULIN_Low LEFAMULIN_Normal LEFAMULIN_High LEFAMULIN_missing)*/
/*    ("Moxifloxacin* (N=&N2.)*n(%)" MOXIFLOXACIN_Low MOXIFLOXACIN_Normal MOXIFLOXACIN_High MOXIFLOXACIN_missing);*/
/**/
/*    define ord/ order noprint;*/
/**/
/*    define param_label/display "Parameter (unit)*   Visit*   Baseline   AD"*/
/*    style(header)={just=l}*/
/*    style(column)={cellwidth=15% just=l};*/
/**/
/*    define LEFAMULIN_Low/display 'Low' center width=5*/
/*    style(header)={just =l}*/
/*    style(column)={cellwidth=4.5% just=l};*/
/**/
/*    define LEFAMULIN_Normal/display 'Normal' center width=5*/
/*    style(header)={just =l}*/
/*    style(column)={cellwidth=4.5% just=l};*/
/**/
/*    define LEFAMULIN_High/display 'High' center width=5*/
/*    style(header)={just =l}*/
/*    style(column)={cellwidth=4.5% just=l};*/
/*define LEFAMULIN_missing/display 'Missing' center width=10*/
/*    style(header)=[just =l]*/
/*    style(column)=[cellwidth=8.5% just=l];*/
/**/
/*define MOXIFLOXACIN_Low/display 'Low' center width=5*/
/*    style(header)=[just =l]*/
/*    style(column)=[cellwidth=4.5% just=l];*/
/**/
/*define MOXIFLOXACIN_Normal/display 'Normal' center width=5*/
/*    style(header)=[just =l]*/
/*    style(column)=[cellwidth=4.5% just=l];*/
/**/
/*define MOXIFLOXACIN_High/display 'High' center width=5*/
/*    style(header)=[just =l]*/
/*    style(column)=[cellwidth=4.5% just=l];*/
/**/
/*define MOXIFLOXACIN_missing/display 'Missing' center width=5*/
/*    style(header)=[just =l]*/
/*    style(column)=[cellwidth=4.5% just=l];*/
/**/
/*/*compute before baseord;*/*/
/*/*line " ";*/*/
/*/*endcomp;*/*/
/**/
/**break after baseord/page;*/
/**/
/*footnote1 j=l 'Source : Listing 16.2.8.1–8.3.3.';*/
/*footnote2 j=l 'Notes: Low: < LLN, Normal: >= LLN and <= ULN, High: > ULN. LLN: lower limit of normal, ULN: upper limit of normal.';*/
/*footnote3 j=l '        Percentages are based on number of subjects with a baseline and post-baseline value for the specific laboratory test.';*/
/*footnote4 j=l '        Only Subjects receiving 10 days of study drug were required to collect Day 7 safety labs.';*/
/*footnote5 j=l '        Missing includes both subjects expected and not expected to have a laboratory assessment (e.g., Subjects not on a 10 day course).';*/
/*footnote6 j=l 'drug are not expected to have Day 7 labs). ';*/
/**/
/*run;*/
/*ods rtf close;*/
/**/
/*proc printto;*/
/*run;*/
