# progreport


<pre>
<b><u>Title</u></b>
<p>
    <b>progreport</b> -- Compares master and survey datasets to create a progress
        report of completion rates and optionally creates a dataset of those
        who have not been interviewed
<p>
<a name="syntax"></a><b><u>Syntax</u></b>
<p>
        <b>progreport,</b> <b><u>m</u></b><b>aster(</b><i>filename</i><b>)</b> <b><u>s</u></b><b>urvey(</b><i>filename</i><b>)</b> <b>id(</b><i>varname</i><b>)</b> <b><u>sort</u></b><b>by(</b>
          <i>varname</i><b>)</b> <b><u>keepm</u></b><b>aster(</b><i>varlist</i><b>)</b> [<i>options</i>]
<p>
    <i>options</i>               Description
    -------------------------------------------------------------------------
    Main
    * <b><u>m</u></b><b>aster(</b><i>filename</i><b>)</b>    master dataset
    * <b><u>s</u></b><b>urvey(</b><i>filename</i><b>)</b>    survey dataset
    * <b>id(</b><i>varname</i><b>)</b>         ID variable from survey
    * <b><u>sort</u></b><b>by(</b><i>varname</i><b>)</b>     variable to stratify progress report from master
                            dataset
    * <b><u>keepm</u></b><b>aster(</b><i>varlist</i><b>)</b> variables to keep from master dataset; ID variable
                            and sortby variable already included
<p>
<p>
    Specifications
      <b>mid(</b><i>varname</i><b>)</b>        ID variable from master dataset if different from
                            survey dataset ID variable name
      <b><u>keeps</u></b><b>urvey(</b><i>varlist</i><b>)</b> variables to keep from survey dataset; ID variable
                            and sortby variable already included
      <b>dta(</b><i>filename</i><b>)</b>       creates a dta file of those who have not been
                            interviewed from master dataset
      <b><u>file</u></b><b>name(</b><i>filename</i><b>)</b>  specifies the name of the progress report file;
                            default is <i>Progress Report.xlsx</i>
      <b><u>t</u></b><b>arget(</b><i>#</i><b>)</b>           target completion rate between 0 and 1; default is
                            1 (100% or all master dataset respondents
                            interviewed)
      <b><u>var</u></b><b>iable</b>            specifies that variable names should be used as
                            column headers instead of variable labels
      <b><u>nolab</u></b><b>el</b>             export variable values instead of value labels
      <b>clear</b>               clears current memory and replaces with merged
                            datasets
      <b>surveyok</b>            allows observations that only appear in survey data
                            instead of only those that match across master
                            and survey data.
      <b><u>work</u></b><b>books</b>           creates workbooks of completion rates for each
                            value of sortby variable instead of sheets. If
                            there are over 20 values of the sortby variable,
                            warning will suggest using this option.
<p>
    -------------------------------------------------------------------------
    * <b>master()</b>, <b>survey()</b>, <b>id()</b>, <b>sortby()</b>, and <b>keepmaster()</b> are required.
<p>
<p>
<b><u>Description</u></b>
<p>
    <b>progreport</b> merges the master dataset and survey dataset to track the
    progress of data collection and reports completion rates by the sortby
    variable.
<p>
    Progress Report.xlsx is created and includes a summary sheet of
    completion rate by the sortby variable, as well as a sheet for each value
    of the sortby variable.  This includes a status for each observation in
    the master dataset and a submission date for those that have been
    interviewed. If specified, <b>progreport</b> can also create a dataset only
    including those who have not been interviewed.
<p>
<p>
<a name="remarks"></a><b><u>Remarks</u></b>
<p>
    <b>progreport</b> reduces time spent tracking survey progress by clearly
    reporting progress across all data collection and broken down by a
    sorting variable.
<p>
<p>
<a name="examples"></a><b><u>Examples</u></b>
<p>
    Create progress report for survey_data.dta from master dataset
    master_data.dta
        <b>. progreport, master("master_data.dta") survey("survey_data.dta")</b>
            <b>id(respondent_id) keepmaster(treatment contact1 contact2)</b>
            <b>keepsurvey(phone_1 phone_2) sortby(comm_live)</b>
<p>
    Create progress report and create dataset of those not yet interviewed
    named "need_to_interview.dta"
        <b>. progreport, master("master_data.dta") survey("survey_data.dta")</b>
            <b>dta("need_to_interview.dta") id(respondent_id)</b>
            <b>keepmaster(treatment contact1 contact2) keepsurvey(phone_1</b>
            <b>phone_2) sortby(comm_live)</b>
<p>
<p>
<a name="authors"></a><b><u>Authors</u></b>
<p>
    Rosemarie Sandino
    Christopher Boyer
<p>
    For questions or suggestions, submit a GitHub issue or e-mail
    researchsupport@poverty-action.org.
<p>
</pre>
