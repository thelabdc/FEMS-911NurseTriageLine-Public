#' Subsetting Medicaid claims to a manageable size
#'
#' Steps of the script
#' 1. claims data is large so subset to manageable size to deal with in subsequent script by reducing # of fields
#' 2. Previous merging script also used Medicare file but did NOT merge the Medicaid enrollment spells due to
#'    more complicated data structure; so dealing with that here; the main feature of that data is trying to
#'    get a measure of a person's length of time in medicaid to adjust expenditures by
#'
#' INPUTS (see 00_constants.R):
#'   * ORIGINAL_CLAIMS_DATA
#'   * MORE_FIELDS_FOR_CLAIMS_DATA
#'   * NTL_PARTICIPANTS_DATA
#'   * MEDICAID_SPELLS_DATA
#'
#' OUTPUTS:
#'   * MEDICAID_PARTICIPANTS_CLAIMS_FINAL_DATA
#'   * MEDICAID_PARTICIPANTS_WITH_CLAIMS_STATUS_DATA
#'
#'  Other notes: if working in Rstudio, make sure there's an R project tied to the base
#'  GH directory (FEMS-911NurseTriageLine-private) for here to point to correct dir

library(assertthat)
library(data.table)
library(dplyr)
library(ggplot2)
library(here)
library(lubridate)
library(readxl)
library(readr)
library(stringr)

source(here("src", "R", "000_constants.R"))
source(here("src", "R", "001_viz_utils.R"))
source(here("src", "R", "400_analysis", "060_clean_ntl_data.R"))

################################
### Functions for computing time
################################

#' function to calculate the number of days a person
#' is enrolled in medicaid (can come from multiple spells)
#' before the their calls to ntl.
#'
#' Assumes the data passed is the merger of enrollment data and the calls data.
#' Also assumes _one call per id_
#' Also uses EnrollmentEndDate_study call that truncates peoples enrollment
#' end date, which shows up as 9999 in the df if they were enrolled at the time
#' of the data pull, to 6 months post study
#'
#'
#' @param data The dataframe on which we'll perform our computation
#' @return A data frame with two columns: MedicaidSystemID and total_days_precall
compute_medicaid_enrollment_precall <- function(data) {
  data %>%
    mutate(
      total_days_precall = pmax(
        as.numeric(difftime(
          pmin(call_date_dt, EnrollmentEndDate_study) + days(1),
          EnrollmentStartDate
        ), units = "days"),
        0
      )
    ) %>%
    group_by(MedicaidSystemID) %>%
    summarise(total_days_precall = sum(total_days_precall), .groups = "drop") %>%
    ungroup() %>%
    inner_join(data, by = "MedicaidSystemID")
}

#' function to calculate the number of days a person
#' is enrolled in medicaid (can come from multiple spells)
#' *after* the their calls to ntl.
#'
#' Assumes the data passed is the merger of enrollment data and the calls data.
#' Also assumes _one call per id_
#' Also uses same col as above that truncates enrollment end date to 6 months
#' post call
#'
#' @param data The dataframe on which we'll perform our computation
#' @return A data frame with three columns: MedicaidSystemID, enr_24h, and enr_6mo
compute_medicaid_enrollment_postcall <- function(data) {
  data %>%
    mutate(
      daysenr_24h = if_else(
        EnrollmentStartDate <= call_date_dt & one_day_postcall <= EnrollmentEndDate_study, 1, 0
      ),
      daysenr_6mo = pmax(
        as.numeric(difftime(
          EnrollmentEndDate_study + days(1),
          pmax(call_date_dt, EnrollmentStartDate),
          units = "days"
        )),
        0
      )
    ) %>%
    group_by(MedicaidSystemID) %>%
    summarise(
      enr_24h = sum(daysenr_24h),
      enr_6mo = sum(daysenr_6mo),
      .groups = "drop"
    ) %>%
    ungroup() %>%
    inner_join(data, by = "MedicaidSystemID")
}


################################################
#### Functions for reading data and gut checking
################################################

#' Read in full claims data
#'
#' @return Full claims data files
read_claims_data <- function() {
  claims_orig <- fread(
    ORIGINAL_CLAIMS_DATA,
    colClasses = c("MedicaidSystemID" = "character")
  )
  print(sprintf("Cols in original claims data: %s", paste(colnames(claims_orig),
    collapse = ";"
  )))

  claims_morefields <- fread(MORE_FIELDS_FOR_CLAIMS_DATA)
  print(sprintf("Cols in more fields claims data: %s", paste(colnames(claims_morefields),
    collapse = ";"
  )))

  ## join cols as specified by dhcf
  join_cols <- intersect(
    colnames(claims_orig),
    colnames(claims_morefields)
  )

  ## join to make claims_all
  claims_all <- claims_morefields[
    claims_orig,
    on = join_cols
  ]

  return(claims_all)
}

#' Read NTL Data
#'
#' @return A data.table with NTL data
read_ntl_data <- function() {
  ntl_participants <- fread(NTL_PARTICIPANTS_DATA,
    colClasses = c("MedicaidSystemID" = "character"),
    na.strings = ""
  ) %>% distinct()

  assert_that(
    table(ntl_participants$dispo_broad)["NTL control"] == 3023 &
      table(ntl_participants$dispo_broad)["NTL treatment"] == 3030,
    msg = "Check for duplication in ntl participant file"
  )

  return(ntl_participants)
}

plot_claims_by_date <- function(claims_all) {
  claims_bydate <- claims_all %>%
    mutate(fs_date = as.Date(FirstServiceCalendarDate,
      format = "%d%b%Y:%H:%M:%S"
    )) %>%
    group_by(fs_date) %>%
    summarise(unique_claims = length(unique(ClaimTCNText)), .groups = "drop")
  plot_claims_data_by_date(claims_bydate)
}

claims_all <- read_claims_data()
ntl_participants <- read_ntl_data()


ret_plot <- plot_claims_by_date(claims_all)
save_plot(ret_plot, "medicaidclaims_overtime")

#############################################
#### Clean NTL Data: One row per _first_ call
#############################################

participants_firstcall <- clean_ntl_data(ntl_participants)

####################################
#### Attach time on Medicaid
####################################

medicaid_spells <- read_excel(
  MEDICAID_SPELLS_DATA,
  col_types = c("text", "text", "guess", "guess")
)
sprintf(
  "The %s beneficiaries have %s enrollment spells",
  medicaid_spells %>% pull(MedicaidSystemID) %>% n_distinct(),
  medicaid_spells %>% nrow()
)

### first, restrict to enrollment spells within the study period + 6 months
### since we have a placebo test with pre-call claims and also look at
### claims up to 6 months after the last call
max_claimsdate <- max(participants_firstcall$date_ts) %m+% months(6)
medicaid_spells_overlapstudy <- medicaid_spells %>%
  filter(EnrollmentStartDate <= max_claimsdate) # can start enrollment prior to study but need to be enrolled by end of study
# dont filter by enrollment end date since we want to know about earlier medicaid spells



####################################
#### Merge both input files
####################################

# Here we perform `participants LEFT JOIN claims`
participants_wallclaims <- participants_firstcall %>%
  left_join(claims_all %>% dplyr::select(
    -MemberFullName,
    -MemberDateofBirth
  ),
  by = "MedicaidSystemID"
  )

sprintf(
  "There are %s unique NTL participants when restricted to the first call",
  participants_firstcall %>% pull(constructed_id) %>% n_distinct()
)

########################################################
#### Notate which claims occur in different time windows
########################################################

# Here we decorate our claims data frame with notes about which claims occurred:
#   1. w/i 24 hours of call
#   2. w/i 6 months of call
#   3. w/i the 6 months _before_ call
#   4. Otherwise

participants_wallclaims <- participants_wallclaims %>%
  mutate(
    call_date_dt = as.Date(date_ts),
    call_date_dt_ymd = ymd(call_date_dt),

    # orig date format examples;
    # "01MAY2018:00:00:00.000" "29MAR2018:00:00:00.000"
    # character class and timestamps are all 00:00:00.000
    FirstServiceCalendarDate_dt = date(dmy_hms(FirstServiceCalendarDate)),
    one_day_postcall = call_date_dt_ymd + days(1),
    six_months_postcall = call_date_dt_ymd %m+% months(6), # rj note: seems like na were caused by this rollover stuff (https://lubridate.tidyverse.org/reference/mplus.html)
    six_months_precall = call_date_dt_ymd %m-% months(6), # since 6-months is arbitrary cutoff i think ok to use workaround

    is_after_first_service_date = FirstServiceCalendarDate_dt >= call_date_dt,
    is_within_6_months_before_call = !is_after_first_service_date & FirstServiceCalendarDate_dt >= six_months_precall,
    is_within_24_hours = is_after_first_service_date & FirstServiceCalendarDate_dt <= one_day_postcall,
    # Exclusive version (days (1, 180]):
    is_within_6_months = is_after_first_service_date & !is_within_24_hours &
      (FirstServiceCalendarDate_dt <= six_months_postcall),
    # Inclusive version (days [1, 180]):
    # is_within_6_months = is_after_first_service_date & FirstServiceCalendarDate_dt <= six_months_postcall,
    is_after_six_months = is_after_first_service_date & !is_within_6_months
  )

# For sanity, make sure missing data is handled appropriately
assert_that(
  participants_wallclaims %>%
    mutate(should_be_true = is.na(ClaimTCNText) == is.na(is_within_6_months)) %>%
    pull(should_be_true) %>%
    all(),
  msg = "Some participants don't have claims, and this should match our date computations"
)

sprintf(
  "There are %s unique medicaid beneficiaries after left joining claims onto participants' first call",
  participants_wallclaims %>% pull(MedicaidSystemID) %>% n_distinct()
)

# TODO(rj): FIGURE OUT WHY WE LOSE 6 when we go to all ids

# Create final data set
claims_analytic <- participants_wallclaims %>%
  filter(is_within_6_months)

claims_precall <- participants_wallclaims %>%
  filter(is_within_6_months_before_call)

sprintf(
  "After subsetting to claims within 24 hours or 6 months, end up with %s unique claims",
  claims_analytic %>% pull(ClaimTCNText) %>% n_distinct()
)

sprintf(
  "There are %s unique medicaid beneficiaries after restricting to ppl with claims in first 6 months of call",
  claims_analytic %>% pull(MedicaidSystemID) %>% n_distinct()
)




###########################################################
#### Notate length of time participant enrolled in medicaid
###########################################################

# We focus on three distinct time windows: Time on Medicaid:
#   1. Before call,
#   2. Within 24 hours of the call,
#   3. Within 6 months of the call

spells_and_claims <- participants_wallclaims %>%
  # Get list of participants
  select(
    num_1,
    MedicaidSystemID,
    call_date_dt,
    one_day_postcall,
    six_months_postcall,
    six_months_precall
  ) %>%
  distinct() %>%
  # Join onto the enrollment spells data. Note that we do an inner join
  # as our pull of enrollment spells was based on the beneficiaries we thought
  # matched, so this will help weed out false matches
  inner_join(
    medicaid_spells_overlapstudy,
    by = "MedicaidSystemID"
  ) %>%
  # Restrict to those claims w/i six months of the call
  mutate(
    length_spell = as.numeric(difftime(EnrollmentEndDate, EnrollmentStartDate), units = "days"),
  ) %>%
  inner_join(
    claims_analytic %>% select(MedicaidSystemID) %>% distinct(),
    by = "MedicaidSystemID"
  )

# All claims we pulled should have at least one spell based on how we pulled this data
# TODO(rj): There are actually four missing spells. We return to this below
# assert_that(
#   length(setdiff(claims_analytic$MedicaidSystemID, spells_and_claims$MedicaidSystemID)) == 0,
#   msg = "There are claims with no spell data"
# )

# Annotate with time on Medicaid pre/post call
spells_and_claims <- spells_and_claims %>%
  ## for this, use "study" enrollment end date,
  ## since people still enrolled in medicaid at time
  ## of data pull are coded as enrollment end date 9999-12-31
  ## so we create an effective end date of their six months post call
  mutate(
    EnrollmentEndDate_study =
      case_when(
        EnrollmentEndDate >= as.POSIXct(six_months_postcall) ~ as.POSIXct(six_months_postcall),
        TRUE ~ EnrollmentEndDate
      )
  ) %>%
  compute_medicaid_enrollment_precall() %>%
  compute_medicaid_enrollment_postcall()



##########################################
#### Write out data
##########################################

# Write the main outcomes data that includes beneficiaries
# with any claims w/in 6 months of call and assorted beneficiary information
claims_analytic %>%
  write_csv(MEDICAID_PARTICIPANTS_CLAIMS_FINAL_DATA)


# Create a second dataset with claims in 6 months before call (for heterogeneous effects analysis)
claims_precall %>%
  write_csv(MEDICAID_PARTICIPANTS_CLAIMS_PRECALL)


# Create a third dataset with beneficiary demographic information (regardless of whether had claims 6 months before or after call)
# and spell information (keeps the 4 with claims missing from spell)
# note that since static attributes were provided alongside claims data,
# they are only observed for beneficiaries with claims
claims_all %>%
  dplyr::select(
    MedicaidSystemID,
    MemberDateofBirth,
    MemberGenderDescription,
    MemberRaceDescription,
    MemberWardName
  ) %>%
  distinct() %>% # since attributes are repeated across claims
  left_join( # add spells onto anyone with attributes
    spells_and_claims %>%
      select(
        MedicaidSystemID,
        total_days_precall,
        enr_24h,
        enr_6mo
      ),
    by = "MedicaidSystemID"
  ) %>%
  distinct() %>%
  write_csv(MEDICAID_STATICATTRIBUTES)

# Finally, write a dataset with participants
# first call to use to filter
participants_firstcall %>%
  select(
    MedicaidSystemID, constructed_id_new, num_1, event_status, dispo_broad,
    contains("ambulanceuse")
  ) %>%
  write_csv(ALL_PARTICIPANTS_FIRSTCALL)
