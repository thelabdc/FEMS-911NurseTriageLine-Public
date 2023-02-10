#' Constants that are used throughout our scripts. Mostly file names
#'
library(here)

# Directions
BASE_DIR <- here("data")
PRIVATE_DATA_DIR <- file.path(BASE_DIR, "private_data")
INTERMEDIATE_DATA_DIR <- file.path(BASE_DIR, "intermediate_objects")
FIGURE_DIR <- here("output", "figures")
TABLES_DIR <- here("output", "tables")


#' For processed outputs (mainly the post-mega merge file),
#' get most recently created file with that prefix in directory
#'
#' @param prefix string with general name of file before timestamp and file extension
#' @param subdir what directory stored in within data dir; usually intermediate
#' @return
get_mostrec <- function(prefix = "ntl_withmedicaidIDS", subdir = INTERMEDIATE_DATA_DIR) {
  paths <- grep(prefix, dir(subdir, full.names = TRUE), value = TRUE)
  mostrec_path <- paths[file.info(paths)$mtime == max(file.info(paths)$mtime)]
  print(sprintf("Reading file: %s", mostrec_path))
  return(mostrec_path)
}

#' Add timeestamps for intermediate files
timestamp_suffix <- gsub("\\-|\\s+|\\:", "_", Sys.time())

# Raw data
ORIGINAL_CLAIMS_DATA <- file.path(PRIVATE_DATA_DIR, "claimsdata_2018031920190301.csv")
MORE_FIELDS_FOR_CLAIMS_DATA <- file.path(PRIVATE_DATA_DIR, "ClaimsDataWithAdditionalFields20170901_To_20190930.csv")
MEDICAID_SPELLS_DATA <- file.path(PRIVATE_DATA_DIR, "MedicaidEnrollmentForNTLMembersList.xlsx")

# Processed data
NTL_PARTICIPANTS_DATA <- get_mostrec()
MEDICAID_PARTICIPANTS_CLAIMS_FINAL_DATA <- file.path(INTERMEDIATE_DATA_DIR, sprintf("Medicaid_analytic_peoplewclaims_%s.csv", timestamp_suffix))
ALL_PARTICIPANTS_FIRSTCALL <- file.path(INTERMEDIATE_DATA_DIR, sprintf(
  "all_analytic_firstcall_%s.csv",
  timestamp_suffix
))
MEDICAID_PARTICIPANTS_CLAIMS_PRECALL <- file.path(INTERMEDIATE_DATA_DIR, sprintf("Medicaid_analytic_precallclaims_%s.csv", timestamp_suffix))
MEDICAID_STATICATTRIBUTES <- file.path(INTERMEDIATE_DATA_DIR, sprintf("Medicaid_staticattributes_%s.csv", timestamp_suffix))

PRE_PREPROCESSED_DATA_FOR_TARIQ <- file.path(INTERMEDIATE_DATA_DIR, "multiple_topmatch_init_fortariq.xlsx")
PREPROCESSED_DATA_FOR_TARIQ <- file.path(INTERMEDIATE_DATA_DIR, "medicaid_multmatch_fortariq.xlsx")

PT_LEVEL_BENEFICIARY <- file.path(INTERMEDIATE_DATA_DIR, "ptlevel_beneficonly.csv")
PT_LEVEL_WBOUNDS <- file.path(INTERMEDIATE_DATA_DIR, "ptlevel_forrobust.csv")

# Color choices
TREATMENT_COLOR <- "#ffa600"
CONTROL_COLOR <- "#003f5c"
