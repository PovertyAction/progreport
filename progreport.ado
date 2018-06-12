*! version 1.0.0 Rosemarie Sandino 12jun2018

program progreport
	syntax, 	/// 
		Master(string) 			/// sample_dta
		Survey(string) 			/// questionnaire data
		ID(string) 				/// id variable from questionnaire data
		SORTby(string) 			///	sorting variable
		KEEPmaster(string)		/// sample variables
		[KEEPSurvey(string)]	/// keep from survey data
		[MID(string)] 			/// id variable from master data
		[FILEname(string)]		/// default is "Progress Report"
		[Target(real 1)]		/// target rate
		[DTA(string)] 			///	if you want an output file of those not interviewed yet
		[VARiable]				/// default is to use variable labels
		[NOLabel]				//  default is to use value labels

	version 13

/* ------------------------------ Load Sample ------------------------------- */
* load the sample list
use "`master'", clear

if !mi("`mid'") {
	ren `mid' `id'
}

if "`filename'" == "" {
	local filename "Progress Report"
}

if regexm("`filename'", ".xls") {
	local filename = substr("`filename'", 1, strpos("`filename'", ".xl")-1) 
}

/* -------------------------- Merge Questionnaire --------------------------- */
qui {

	merge 1:1 `id' using "`survey'", ///
		keepusing(submissiondate `keepsurvey') ///
		gen(qmerge)

	ren submissiondate questionnaire_date
	replace questionnaire_date = dofc(questionnaire_date)
	format questionnaire_date %td

	lab def _merge 1 "Not submitted" 2 "Only in Questionnaire Data" 3 "Submitted", modify
	decode qmerge, gen(status)

	local allvars `id' `keepmaster' `keepsurvey' questionnaire_date status
	lab var status "Status"
	lab var questionnaire_date "Date Submitted"
	order `allvars' 
	gsort qmerge -questionnaire_date `id' `keepmaster'
	
	/* -------------------------- Create Summary Sheet -------------------------- */

	preserve
		gen completed = 1 if qmerge == 3
		gen total = 1 if qmerge != 2
		collapse (sum) completed total (min) first_submitted=questionnaire_date (max) last_submitted=questionnaire_date, by(`sortby')
		gen pct_completed = completed/total, after(total)
		lab var completed "Submitted"
		lab var total "Total"
		lab var pct_completed "% Submitted"
		lab var first_submitted "First Submission"
		lab var last_submitted "Last Submission"

		sort pct_completed `sortby'
		export excel using "`filename'.xlsx", ///
			firstrow(varl) sheet("Summary") cell(A2) replace
		local d $S_DATE
		qui count
		local N = `r(N)' + 2
		local all `sortby' completed total pct_completed first_submitted last_submitted
		tostring `all', replace force

		mata : create_summary_sheet("`filename'", tokens("`all'"), `N')
	restore

	/* --------------------------- Create Sheets ---------------------------- */

	if mi("`variable'") {
		local variable = "varl"
	}

	*If want value labels, encode variable so those are used as colwidth
	if "`nolabel'" == "" {
		ds `allvars', has(vallab)
		foreach var in `r(varlist)' {
			decode `var', gen(`var'_new)
			drop `var'
			ren `var'_new `var'
		}
	}

	local check `:type `sortby''
	if substr("`check'", 1, 3) != "str" {
		tostring `sortby', replace
	}

	levelsof `sortby', local(byvalues)

	foreach sortval in `byvalues' {
		export excel `allvars' if `sortby' == "`sortval'" using "`filename'.xlsx", ///
			firstrow(`variable') sheet("`sortval'") cell(A1) sheetreplace `nolabel'
			
		qui count if `sortby' == "`sortval'"
		local N = `r(N)' + 1
		
		mata : create_progress_report("`filename'.xlsx", "`sortval'", tokens("`allvars'"), `N')
		local den = `N' - 1
		qui count if `sortby' == "`sortval'" & qmerge == 3
		local num = `r(N)'
		noi dis "Created sheet for `sortval': interviewed `num' out of `den'"
	}


	if !mi("`dta'") {	
		preserve
			keep if qmerge == 1
			keep `id' `keepmaster'
			save "`dta'", replace
			noi dis "Saved remaining respondents to `dta'."
		restore

	}
drop qmerge
}

end

mata: 
mata clear

void create_summary_sheet(string scalar filename, string matrix allvars, real scalar N) 
{
	class xl scalar b
	b = xl()
	string scalar date
	real scalar target
	real vector varname_widths

	b.load_book(filename)
	b.set_sheet("Summary")
	b.set_mode("open")
	date = st_local("d")

	b.set_top_border(1, (1,	6), "thick")
	b.set_bottom_border((1,2), (1,6), "thick")
	b.set_bottom_border(N, (1,6), "thick")
	b.set_left_border((1, N), 1, "thick")
	b.set_left_border((1, N), 7, "thick")

	b.set_font_bold((1,2), (1,6), "on")
	b.set_horizontal_align((1, N),(1,6), "center")
	b.put_string(1, 1, "Tracking Summary: " + date)
	b.set_horizontal_align(1, (1,6), "merge")
	b.set_number_format((3,N), 4, "percent")
	
	stat = st_sdata(., "pct_completed")
	target = strtoreal(st_local("target"))-0.005

	for (i=1; i<=length(stat); i++) {
		
		if (strtoreal(stat[i]) == 0) {
			b.set_fill_pattern(i + 2, (4), "solid", "red")
		}

		else if (strtoreal(stat[i]) >= target) {
			b.set_fill_pattern(i + 2, (4), "solid", "green")
		}
		else {
			b.set_fill_pattern(i + 2, (4), "solid", "yellow")
		}
		
	}
	
	column_widths = colmax(strlen(st_sdata(., allvars)))	
	varname_widths = strlen(allvars)
	
	for (i=1; i<=cols(column_widths); i++) {
		if	(column_widths[i] < varname_widths[i]) {
			column_widths[i] = varname_widths[i]
		}

		b.set_column_width(i, i, column_widths[i] + 2)
	}
	b.close_book()
}


void create_progress_report(string scalar filename, string scalar sortval, string matrix allvars, real scalar N) 
{
	class xl scalar b
	real scalar i
	real vector rows, status
	real vector column_widths, varname_widths
	string matrix sortvar
	
	b = xl()
	
	b.load_book(filename)
	b.set_sheet(sortval)
	b.set_mode("open")

	varname_widths = strlen(allvars)
	column_widths = colmax(strlen(st_sdata(., allvars)))

	for (i=1; i<=cols(column_widths); i++) {
		if (st_local("variable") == "varl") {
			varlabel = st_varlabel(allvars[i])
			if (varname_widths[i] < strlen(varlabel)) {
				varname_widths[i] = strlen(varlabel)
			}
		}
		if	(column_widths[i] < (varname_widths[i])) {
			column_widths[i] = (varname_widths[i])
		}

		b.set_column_width(i, i, column_widths[i]+2)
	}
	
	b.set_right_border((1,N), length(varname_widths)-2, "thick")
	b.set_right_border((1,N), length(varname_widths), "thick")
	b.set_left_border((1,N), 1, "thick")
	b.set_top_border(1, (1,length(varname_widths)), "thick")
	b.set_bottom_border(1, (1,length(varname_widths)), "thick")
	b.set_bottom_border(N, (1,length(varname_widths)), "thick")
	b.set_font_bold((1), (1,length(varname_widths)), "on")
	b.set_horizontal_align((1,N), (1,length(varname_widths)), "center")
	
	sortvar = st_sdata(., st_local("sortby"))
	rows = selectindex(sortvar :== sortval)
	status = st_data(rows, "qmerge")
	for (i=1; i<=length(rows); i++) {
		if (status[i] == 1) {
			b.set_fill_pattern(i + 1, (length(varname_widths)), "solid", "red")
		}
		else if (status[i] == 2) {
			b.set_fill_pattern(i + 1, (length(varname_widths)), "solid", "yellow")
		}
		else if (status[i] == 3) {
			b.set_fill_pattern(i + 1, (length(varname_widths)), "solid", "green")
		}
	}
	b.close_book()
}

end


