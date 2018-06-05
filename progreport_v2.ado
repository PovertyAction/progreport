
program progreport
	syntax [using/], ///
		Master(string) 			/// sample_dta
		Survey(string) 			/// questionnaire data
		ID(string) 				/// id variable from questionnaire data
		Comm(string) 			///	community variable
		VARlist(string)			/// sample variables
		[KEEPsurvey(string)]	/// keep from survey data
		[MID(string)] 			/// id variable from master data
		[VARiable]				/// default is to use variable labels
		[NOLabel]				/// default is to use value labels
		[FILEname(string)]		/// default is "Tracking Report"
		[Target(real 1)]		/// target rate

/* ------------------------------ Load Sample ------------------------------- */
if "`filename'" == "" {
	local filename "Progress Report"
}

* load the sample list
use "`master'", clear
if !mi("`mid'") {
	ren `mid' `id'
}

/* -------------------------- Merge Questionnaire --------------------------- */
qui {
	* merge completed questionnaire submissions 
	merge 1:1 `id' using "`survey'", ///
		keepusing(submissiondate `keepsurvey') ///
		gen(qmerge)

	ren submissiondate questionnaire_date
	replace questionnaire_date = dofc(questionnaire_date)
	format questionnaire_date %td

	lab def _merge 1 "Not submitted" 2 "Only in Questionnaire Data" 3 "Submitted", modify
	decode qmerge, gen(status)

	local allvars `id' `varlist' `keepsurvey' questionnaire_date status
	lab var status "Status"
	lab var questionnaire_date "Date Submitted"
	order `allvars' 
	gsort qmerge -questionnaire_date `id' `varlist'
	
	/* -------------------------- Create Summary Sheet -------------------------- */

	preserve
		gen completed = 1 if qmerge == 3
		gen total = 1 if qmerge != 2
		collapse (sum) completed total (min) first_submitted=questionnaire_date (max) last_submitted=questionnaire_date, by(`comm')
		gen pct_completed = completed/total, after(total)
		lab var completed "Submitted"
		lab var total "Total"
		lab var pct_completed "% Submitted"
		lab var first_submitted "First Submission"
		lab var last_submitted "Last Submission"

		sort pct_completed `comm'
		export excel using "`filename'.xlsx", ///
			firstrow(varl) sheet("Summary") cell(A2) replace
		local d $S_DATE
		qui count
		local N = `r(N)' + 2
		local all `comm' completed total pct_completed first_submitted last_submitted
		tostring `all', replace force
		foreach var in `all' {
			local len = strlen("`var'")
			local name_widths `name_widths' `len'
		}

		mata : create_summary_sheet("`filename'", tokens("`all'"), tokens("`name_widths'"), `N')
	restore

	/* ------------------------ Create Community Sheets ------------------------- */

	if mi("`variable'") {
		local variable = "varl"
	}

	foreach var in `allvars' {	
		if "`variable'" == "varl" {
			local lab : variable label `var'
			local len = strlen("`lab'")
		}
		if "`variable'" == "variable" | "`len'" == "0" {
			local len = strlen("`var'")
		}
		local varname_widths `varname_widths' `len' 
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

	local check `:type `comm''
	if substr("`check'", 1, 3) != "str" {
		tostring `comm', replace
	}

	levelsof `comm', local(comms)

	foreach community in `comms' {
		export excel `allvars' if `comm' == "`community'" using "`filename'.xlsx", ///
			firstrow(`variable') sheet("`community'") cell(A1) sheetreplace `nolabel'
			
		qui count if `comm' == "`community'"
		local N = `r(N)' + 1
		
		mata : create_tracking_sheet("`filename'.xlsx", "`community'", tokens("`allvars'"), tokens("`varname_widths'"), `N')
		local den = `N' - 1
		qui count if `comm' == "`community'" & qmerge==3
		local num = `r(N)'
		noi dis "Created sheet for `community': interviewed `num' out of `den'"
	}


	if !mi("`using'") {
		preserve
			keep if qmerge==1
			keep `id' `varlist'
			save "`using'", replace
	}
}

end

mata: 
mata clear

void create_summary_sheet(string scalar filename, string matrix allvars, string vector varname_widths, real scalar N) 
{
	class xl scalar b
	b = xl()
	string scalar date
	real scalar target

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
	for (i=1; i<=cols(column_widths); i++) {
		if	(column_widths[i] < strtoreal(varname_widths[i])) {
			column_widths[i] = strtoreal(varname_widths[i])
		}

		b.set_column_width(i, i, column_widths[i] + 2)
	}
	b.close_book()
}


void create_tracking_sheet(string scalar filename, string scalar community, string matrix allvars, string vector varname_widths, real scalar N) 
{
	class xl scalar b
	real scalar i
	real vector right, rows, status
	real vector column_widths
	string matrix comm
	string scalar test
	
	b = xl()
	
	b.load_book(filename)
	b.set_sheet(community)
	b.set_mode("open")
	
	r = length(varname_widths) - 2
	s = length(varname_widths)
	right = (r, s)
	for (i=1; i<=length(right); i++) {
		b.set_right_border((1,N), right[i], "thick")
	}
	
	b.set_left_border((1,N), 1, "thick")
	column_widths = colmax(strlen(st_sdata(., allvars)))

	for (i=1; i<=cols(column_widths); i++) {
		if	(column_widths[i] < strtoreal(varname_widths[i])) {
			column_widths[i] = strtoreal(varname_widths[i])
		}

		b.set_column_width(i, i, column_widths[i]+2)
	}	
	
	b.set_top_border(1, (1,s), "thick")
	b.set_bottom_border(1, (1,s), "thick")
	b.set_bottom_border(N, (1,s), "thick")

	b.set_font_bold((1), (1,s), "on")
	b.set_horizontal_align((1,N), (1,s), "center")
	
	test = st_local("comm")
	comm = st_sdata(., test)
	rows = selectindex(comm :== community)
	status = st_data(rows, "qmerge")
	for (i=1; i<=length(rows); i++) {
		
		if (status[i] == 1) {
			b.set_fill_pattern(i + 1, (s), "solid", "red")
		}
		else if (status[i] == 2) {
			b.set_fill_pattern(i + 1, (s), "solid", "yellow")
		}
		else if (status[i] == 3) {
			b.set_fill_pattern(i + 1, (s), "solid", "green")
		}
	}
	b.close_book()
}

end


