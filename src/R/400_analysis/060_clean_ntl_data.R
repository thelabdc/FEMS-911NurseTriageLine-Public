#' Take in the NTL data and:
#'   1. Clean some of its columns
#'   2. Double check that there are no Medicaid IDs with multiple constructed ids (there are)
#'   3. Clean those constructed ids
#'   4. Return the first call for each participant by time
#'
#' @param ntl_participants The data frame of ntl participants we'll manipulate
#' @return One row per participant with details about their _first_ call
clean_ntl_data <- function(ntl_participants) {
  participants_tomerge <- ntl_participants %>%
    mutate(date_ts = ymd_hms(date))

  # Those medicaid ids with more than one ntl id
  medids_repeated <- participants_tomerge %>%
    filter(!is.na(MedicaidSystemID)) %>%
    group_by(MedicaidSystemID) %>%
    summarise(distinct_ntlids = n_distinct(constructed_id), .groups = "drop") %>%
    filter(distinct_ntlids > 1) %>%
    select(MedicaidSystemID)

  ## from viewing, see that these are people we didnt catch as duplicates in
  ## construct id process but who seem to be correctly counted as duplicates base on medicaid id
  ## solution: in original data create a NEW constructed_id that reflects both duplicated people captured
  ## by our original method and duplicated as captured by the medicaid matching process

  # Those who either (a) didn't match to Medicaid or (b) didn't have a repeated id
  # Just retain old NTL id
  participants_notmatched_notrep <- participants_tomerge %>%
    filter(is.na(MedicaidSystemID) | !MedicaidSystemID %in% (medids_repeated %>% pull(MedicaidSystemID))) %>%
    mutate(constructed_id_new = sprintf("constructed_id_200%s", str_pad(constructed_id, 4, "left", 0)))

  assert_that(
    (participants_notmatched_notrep %>% pull(constructed_id_new) %>% n_distinct()) ==
      (participants_notmatched_notrep %>%
        pull(constructed_id) %>%
        n_distinct()),
    msg = "Created too many new constructed IDs"
  )

  # Those who matched to Medicaid _and_ had a repeated id: create a new ID!
  participants_rep <- participants_tomerge %>%
    inner_join(medids_repeated, by = "MedicaidSystemID") %>%
    inner_join(
      participants_tomerge %>%
        select(MedicaidSystemID) %>%
        distinct() %>%
        arrange(MedicaidSystemID) %>%
        mutate(tmp_group_id = row_number()),
      by = "MedicaidSystemID"
    ) %>%
    mutate(constructed_id_new = paste0("constructed_id_100", str_pad(tmp_group_id, 4, "left", 0))) %>%
    select(-tmp_group_id)

  assert_that(
    participants_rep %>% pull(constructed_id_new) %>% n_distinct() ==
      participants_rep %>%
        pull(MedicaidSystemID) %>%
        n_distinct(),
    msg = "Created the wrong number of new ids for those who had more than one NTL id"
  )

  participants_updateid <- bind_rows(
    participants_notmatched_notrep,
    participants_rep
  )

  # Finally, restrict to the first call, which reflects a mix of
  # repeat calls identified through fuzzy matching and repeats of Medicaid ids
  participants_firstcall <- participants_updateid %>%
    group_by(constructed_id_new) %>%
    arrange(date_ts, .by_group = TRUE) %>%
    filter(row_number() == 1) %>%
    ungroup()

  print(sprintf(
    paste0(
      "After restricting to first calls (among flagged repeat calls), ",
      "we go from %s to %s participants\n"
    ),
    nrow(participants_updateid),
    nrow(participants_firstcall)
  ))

  assert_that(
    participants_firstcall %>%
      group_by(constructed_id_new) %>%
      summarise(the_count = n(), .groups = "drop") %>%
      mutate(is_one = the_count == 1) %>%
      pull(is_one) %>%
      all(),
    msg = "Some id is repeated even after cleaning"
  )

  return(participants_firstcall)
}
