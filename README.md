# 911 Nurse Triage Line

This repository contains all the code related to the
[911 Nurse Triage Line](https://osf.io/t7nhj/) randomized controlled trial. It will
be updated as more analyses are done.

## Requirements

The code in this repository is written in Python and R. We used Python 3.8.6 and
R 4.1.2. We manage dependencies using [`poetry`](https://python-poetry.org) and
[`renv`](https://rstudio.github.io/renv/articles/renv.html). Once Python and R are
installed you should be able to download and install all requirements with the
following commands on Mac/Linux:

```bash
Rscript -e 'install.packages("renv")
curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3 -
```

Or alternatively on Windows:

```bash
Rscript -e 'install.packages("renv")
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py -UseBasicParsing).Content | python3 -
```

Once these dependency managers are installed, you can then run the following commands
to install all dependencies:

```bash
poetry install
Rscript -e 'renv::restore()'
```

## Running the Code

Once dependencies have been installed, then you can run the following command to perform
all analyses that went into the ultimate paper:

```bash
poetry run ntl run-all -s 3  # NOTE: This will take a _long_ time to run
poetry run ntl run-all -s 4
```

## Table of Contents

There are several computations that are performed in this repository. Here we index them.

### Pre-analysis plan analyses

#### Computing the dropped call rate in the study

The notebook `DroppedCalls.ipynb` corresponds to Appendix C of our Pre-analysis
Plan. It computes the proportion of calls which were assigned to the Nurse
Triage Line which will not be answered by the nurse due to all the nurses being
busy. This computation is based on historical data.

#### Power computations

The notebook `PowerCalculations.ipynb` computes the minimum detectable effect
based on a range of base rates and sample sizes which are plausible for our
study. It corresponds to Appendix G of our Pre-analysis Plan.

## data

The data contains PII and we do not include these data in the repo. Instead, one can reproduce using the following directory structure for internal files.

- `data`
  - `private_data`: contains raw form of files that we do not post publicly in the repo
  - `public_data`: contains some publicly-accessible files like mapping of ICD codes to likely emergent/non-emergent status
  - `intermediate_objects`: these are derived data produced by earlier scripts and read in by later scripts

## public_data

We also make available all calls for EMS service in the District during 2016. This csv
(`data/2016_EMS_Events.csv`) has only two columns: the time the call was received and
the classification of the call.

## Analysis code

### Utils and constants

- [000_constants.R](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/000_constants.R): defines base directories and names of data directories/data. Function `get_mostrec` gets the most recently modified version of a file with a given prefix.

- [001_viz_utils.R](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/001_viz_utils.R): data visualization utilities


### Data cleaning and merger (300)

1. [010_merge_CAD_safetyPAD.ipynb](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/010_merge_CAD_safetyPAD.ipynb)

  - Takes in:
    - Credentials to access Common Events Database (CAD)
    - .csv filed prepared by OCTO/OUC data scientist Nicole Donnelly (contains manually-fixed codes for what happens to calls or event codes)

  - What it does:
    1. If an argument to pull from the raw database is set to `True`, reads in raw data directly from the database and the OUC-cleaned data

    2. Performs a left join that retains all rows from the raw data and adds the reconciled event codes. The id in the raw database is called num_1; in the OUC-cleaned data is called agency_event-- output is called ntl_summary_eval

    3. Calculates descriptives statistics about the N of participants in each group over time

    4. Prints ids of NTL participants in the format needed for FEMS SafetyPAD user interface (i.e., F1.... F1.... etc.). User needs to log into the SafetyPAD user interface at: dcfems.safetypad.com to then export the safetyPAD data related to those ids. Note, we do in batches of 1000 IDs, since the safetyPAD data is longform (each ID can have multiple rows corresponding to updates like ambulance dispatched, ambulance sent, etc.). The SafetyPAD UI has a export limit of 10,000 rows so the batches of 1000 help us conservatively stay under that limit.

    5. After SafetyPAD data is exported and is saved using naming convention - `safetypad_idsearch_batch*.csv', reads in the safetyPAD files and rowbinds them

    6. Performs a left join that retains all rows from the ntl_summary_eval and merges with SafetyPAD data. Id for left dataset is num_1. ID for right dataset is eResponse_03_Incident_Number


  - Outputs:
    - `ntl_withsafetypad.[pkl|parquet]: result from left join in step 6; outputs in either pkl or parquet form depending on parameter

2.[011_merge_AMR.ipynb](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/011_merge_AMR.ipynb)

 - Takes in:
    - `ntl_withsafetypad` created in previous script
    - AMR data (`amr_df.xlsx`; see email re data sources for token)

  - What it does:
    1. Reads in each dataset

    2. Creates flags for which ids are in which dataset (for AMR data, FEMSID is the identifier)

    3. Renames AMR columns other than ID with amr prefix

    4. Left joins the NTL base data (output from previous notebook) to AMR data

  - Outputs:
    - ntl_withsafetypad_withamr.pkl: result from left join in step 4

3.[020_createidentifiers.ipynb](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/020_createidentifiers.ipynb)

 - Takes in:
    - `ntl_withsafetypad_withamr.pkl`: output from previous notebook
    - `dem_fromsafetyPAD.csv` and `dem_fromsafetyPAD_201911115.csv`: Pulls from SafetyPAD utilizing the scripts in Section 200.
      Note that these files contain an identical set of people. However, the latter contains more fields and was pulled at a later
      date. We utilize both because the former was used for matching and validation purposes and we wish to exactly preserve our
      process

 - What it does:
    1. Cleans names from SafetyPAD
    2. Cleans names from AMR
    3. Cleans addresses
    4. Cleans phone numbers
    5. Categorizes which people have different identifiers (names from either source; addresses; phone numbers)
    6. Creates a name string---FIRSTNAME_LASTNAME---and then does fuzzy matching to find high-probability matches of that string.

- Output:
  - `identifiers_fordhcr` and `df_fordhcr_DOBsadded`: this is data with cleaned identifiers for DC's DHCF to probabilistically match to Medicaid records
  - `df_forrepeatcalls`: data used for repeat calls analysis
  - `df_forambulanceuse`: this is data with cleaned identifiers to use for the ambulance use analysis in the script that follows
  - `df_forfuzzy`: For posterity, the data frame that feeds into the fuzzy matching analysis
  - `data_withmatches_amrupdates`: For posterity, the data frame that comes out of fuzzy matching analysis

### Acutal analysis (400)


4. [030_ambulance_analysis.Rmd](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/030_ambulance_analysis.Rmd)

 - Takes in:
    - `df_forambulanceuse`: output from previous script; contains all callers regardless of Medicaid match status

 - What it does:
    1. Since each call has multiple timestamped `status events` tied to the call (so the 6,053 calls are tied to 9,599 events), aggregates to the call level two definitions of ambulance sent: (1) an ambulance is sent at any point among the timestamped events, (2) an ambulance is the last timestamped event
    2. Plots descriptive rates between T and C of three categories: (1) an ambulance is sent/dispatched and it transports the caller, (2) an ambulance is sent/dispatched but it does not transport the caller, (3) an ambulance is neither sent/dispatched nor transports the caller. It also breaks these statuses down by the call response code (e.g., advanced life support (very few calls); basic life support; etc).
    3. Estimates regressions pooled across the entire period and separated by month of effect of randomization to treatment on: (1) whether ambulance is dispatched (significantly lower in treatment group) (2) whether ambulance transports an individual (significantly lower in treatment group)

- Output:
  - `callresponse_forposttx`: file used in later post-treatment bias diagnostic analyses that has detailed ambulance statuses that allow us to investigate extent to which failure to match to Medicaid records is differentially biased by treatment status

5. [050_medicaid_sample_characteristics.ipynb](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/050_medicaid_sample_characteristics.ipynb)

 - Takes in:
    - `Member_Matches_wDHCF.xlsx`: Medicaid beneficiary file that contains all matches
    - `MedicareEnrollmentForNTLMembersList.csv`: data on Medicare enrollment
    - `df_fordhcr_DOBsadded`: For reference, a file created in 020
    - `callresponse_forposttx.csv`: most recent ids and create_date variable (treatment statuses)
    - `df_forrepeatcalls.csv`: constructed IDs from fuzzy matching (treatment statuses)
    - Several hand reviewed matching files

 - What it does:
    1. Examines two types of matches: (1) cases where a single name_dob_id from the NTL call logs matches to multiple MedicaidSystemIDs from the beneficiary file, and (2) cases where a single MedicaidSystemID matches to multiple name_dob_ids. Indicators of matched first name, last name, and DOB are created to help adjudicate between cases that have multiple matches. The goal is deduplicate matches within the data.
    2. In the first case, in which one NTL ID matches with multiple Medicaid ID's, the goal is to deduplicate these matches since they are not due to repeated NTL calls. These matches are further examined and deduplicated depending on the nature of their match (case where there is no unique Medicaid ID for the top match value, cases where there is a unique Medicaid ID for the top match value and that Medicaid ID is the top match for only one NTL ID, and cases where there is a unique Medicaid ID but that unique Medicaid ID is the top match for multiple NTL IDs)
    3. In the second case, in which one Medicaid ID matches to multiple NTL ID's, there could be true matches due to repeat calls. Here, these matches are hand-coded and deduplicated accordingly.
    4. Deduplicated participants data from (2) and (3) are then merged into one file, which is then merged with treatment statuses received from FEMS.

 - Output:
    - `ntl_withmedicaidIDS_{}.csv`: final deduplicated, decorated NTL participants data, which is used in later script to construct outcomes.

6. [061_subset_medclaims_outcomeswindow.R](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/061_subset_medclaims_outcomeswindow.R) (relies on a function in [060_clean_ntl_data.R](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/061_subset_medclaims_outcomeswindow.R))

 - Takes in:
    - `claimsdata_2018031920190301.csv`: original claims data
    - `ClaimsDataWithAdditionalFields20170901_To_20190930.csv`: more fields for claims data
    - `ntl_withmedicaidIDS_{}.csv`: NTL participants data from previous script
    - `MedicaidEnrollmentForNTLMembersList.xlsx`: Medicaid spells data

 - What it does:
    1. Since the claims data is large, this script subsets it to a manageable size by reducing the number of fields, which is then dealt with in a subsequent script.
    2. The previous merging script also used the Medicare file but did NOT merge the Medicaid enrollment spells due to more complicated data structure. This is dealt with here; the main feature of that data is trying to get a measure of a person's length of time in Medicaid to adjust expenditures by.

 - Output:
    - `Medicaid_analytic_peoplewclaims_%s.csv`: the main outcomes data that includes beneficiaries with any claims within 6 months of call and assorted beneficiary information
    - `Medicaid_analytic_precallclaims_%s.csv`: second dataset with claims in 6 months before call (for heterogeneous effects analysis)
    - `Medicaid_staticattributes_%s.csv`: third dataset with beneficiary demographic information (regardless of whether had claims 6 months before or after call) and spell information. Note that since static attributes were provided alongside claims data, they are only observed for beneficiaries with claims
    - `all_analytic_firstcall_%s.csv`: dataset with participants' first call to use to filter

7. [070_medicaid_constructoutcomes.ipynb](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/src/notebooks/400_analysis/070_medicaid_constructoutcomes.ipynb)

 - Takes in:
    - `Medicaid_analytic_peoplewclaims_%s.csv`: main outcomes data created in previous script
    - `ntl_withmedicaidIDS_{}.csv`: NTL participants data from 050 script
    - `all_analytic_firstcall_%s.csv`: dataset from previous script with participants' first call to use to filter
    - `Medicaid_analytic_precallclaims_%s.csv`: beneficiary data from previous script with claims in 6 months before call
    - `Medicaid_staticattributes_%s.csv`: dataset from previous script with beneficiary demographic information (regardless of whether had claims 6 months before or after call)
    - `nyu_ed.xlsx`: public ED visit codes from NYU

 - What it does:
    1. Three analytical datasets are created: (1) people who matched to the beneficiaries file with claims within a 24-hour or 6-month window of their call, (2) people who matched to the beneficiaries file with no claims in either window, and (3) people who did not match to the beneficiaries file.
    2. Next, claims associated with an ED visit and a general care, non-ED use measure are coded. Then appropriateness of visit is coded using NYU ED codes.
    3. Aggregating up from visit level to the patient level, binary outcomes are coded for all three groups mentioned in (1). The three groups are then rowbound, summarized, and beneficiaries are merged on MedicaidSystemID.
    4. Same process of (2) and (3) is used to code whether each line item is a PCP visit.
    5. Expenditures are aggregated by beneficiary, information is added for beneficiaries with no claims, and the outcomes are rowbound and summarized. Indicators are created for different quantiles of pre-call expenditures.
    6. Finally, all outcomes are merged into one dataset (beneficiares with imputed values for non-matches).

 - Output:
    - `ptlevel_beneficonly.csv`: final outcome dataset (beneficiaries only)
    - `ptlevel_forrobust.csv`: final outcome dataset (beneficiaries with imputed values for non-matches)


8. [080_medicaid_analysis.R](https://github.com/thelabdc/FEMS-911NurseTriageLine-private/blob/master/code/080_medicaid_analysis.R)

 - Takes in:
    - `ptlevel_beneficonly.csv`: final outcome dataset from previous script (beneficiaries only; main analytic data)
    - `ptlevel_forrobust.csv`: final outcome dataset from previous script (beneficiaries with imputed values for non-matches; bounding data)

 - What it does:
    1. Cleans main analytic data and bounding data for binary outcomes
    2. Creates a basic descriptive plot of the joined data.
    3. Regressions are run per our specification on the formula: outcome ~ treatment. Regression is run with all binary outcomes, and then with continuous outcomes.
    4. Binary outcomes are plotted.


## Contributors

This code was written by Chrysanthi Hatzimasoura (chrysanthi.hatzimasoura@dc.gov), Rebecca Johnson (rebecca.johnson@dc.gov), and Ryan T. Moore (@rtm-dc), Kevin H. Wilson.

## License

See [LICENSE.md](https://github.com/thelabdc/FEMS-911NurseTriageLine-public/blob/master/LICENSE.md).
