*Lisiting 16.2.4.1 Demographic Baseline Data : Full Analysis Set";

ods listing;
ods html close;
/*proc datasets lib = work kill;*/

/* getting records from adsl fasfl data*/
proc sort data = adam.adsl_sm_mock out = adsl;
	by usubjid;
	where FASFL = 'Y';
run;


data adsl_vs;
	length col1 $ 100.;
	set adsl (in=a keep = usubjid subjid race age sex trt01p brthdt weightb heightb);
	*where weightb ne .;
	if race = "BLACK OR AFRICAN AMERICAN" then race1 = "B";
	else if race = "WHITE" then race1 = "W";
	if race = "ASIAN" then race1 = "A";
	if race = "MULTIPLE" then race1 = "W";
	if race = "UNKNOWN" then race1 = "U";

/*	if sex = 'F' then sex1 = 'Female';*/
/*	else if sex = 'M' then sex1 = 'Male';*/

	col1 = catx('/', subjid, put(age, best.), race1, Sex);
	col2 = BRTHDT;
	format col2 e8601da10.;
	col4 = put(weightb, 8.1);
	col5 = put(heightb, 8.1);
	if not missing(weightb) and not missing(heightb) then col6 = put((weightb/((heightb / 100)**2)), 8.2);
	drop usubjid subjid race age sex trt01p brthdt weightb heightb race1 sex1;
run;

data _null_;
  call symputx('gen_time', put(datetime(), e8601dt.));
run;

ods rtf close;
ods escapechar='^';
ods rtf file='D:\PROJECT_SDTM_20_09_2025\DATA\TLFs\16.2.4.1 Demographic Baseline Data - Full Analysis Set.rtf' style=journal;
options orientation=landscape;

proc report data=adsl_vs nowd headline headskip split="*" spacing=2 ls=100 ps=60 
  style(report)={frame=void cellspacing=3 cellpadding=2 width=100%}
  style(header)={background=white};

  /* Custom row above column headers */
  compute before _page_;
    line @1 "_______________________________________________________________________________________________________________________________________________________";
    line @1 "Randomized Treatment: TRT A & B.";
    line @1 "_______________________________________________________________________________________________________________________________________________________";
  endcomp;

  column col1 col2 col4 col5 col6;

  define col1 / style(header)=[just=left cellwidth=20% font_weight=bold font_style=normal]
                style(column)=[cellwidth=20% just=left asis=on font_style=normal]
                "Subject ID/Age/Race/Sex";

  define col2 / style(header)=[just=left cellwidth=10% font_weight=bold font_style=normal]
                style(column)=[cellwidth=10% just=left asis=on font_style=normal]
                "Date of Birth";

  define col4 / display
                style(header)=[just=center cellwidth=10% font_weight=bold font_style=normal]
                style(column)=[cellwidth=10% just=center font_style=normal]
                "Baseline*Weight (kg)";

  define col5 / display
                style(header)=[just=center cellwidth=10% font_weight=bold font_style=normal]
                style(column)=[cellwidth=10% just=center font_style=normal]
                "Baseline*Height (cm)";

  define col6 / display
                style(header)=[just=center cellwidth=20% font_weight=bold font_style=normal]
                style(column)=[cellwidth=10% just=center font_style=normal]
                "Baseline BMI*(kg/m^{super 2})";

  compute after _page_;
    line @1 "W = White; B = Black or African American; P = Native Hawaiian or other Pacific Islander; A = Asian; I = American Indian or Alaska Native M = Male; F = Female;";
    line @1 "[BSA = Body Surface Area and BMI = Body Mass Index]";
    line @1 "Source: Listing 16.1.4.2, Dataset: ADSL, Program: ADSL_SM.SAS, Output: Listing_16.1.4.2.rtf, Generated on: &gen_time";
  endcomp;

run;

ods rtf close;
