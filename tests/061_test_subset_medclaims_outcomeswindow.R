#' Test the functions in the 06 file
library(tidyverse)
library(lubridate)
library(testthat)


test_that("Enrollment is correctly computed pre-call", {
  data <- tribble(
    ~MedicaidSystemID, ~EnrollmentStartDate, ~EnrollmentEndDate, ~length_spell, ~call_date_dt,
    # Call is in the middle of a spell
    "123", as.Date("2020-01-01"), as.Date("2020-01-31"), 31, as.Date("2020-01-15"),

    # Call is after a spell and in the middle of one
    "456", as.Date("2020-01-01"), as.Date("2020-01-31"), 31, as.Date("2020-03-01"),
    "456", as.Date("2020-02-15"), as.Date("2020-03-15"), 31, as.Date("2020-03-01"),

    # Call is before, after, and in the middle of a spell
    "abc", as.Date("2020-01-01"), as.Date("2020-01-31"), 31, as.Date("2020-03-01"),
    "abc", as.Date("2020-02-15"), as.Date("2020-03-15"), 30, as.Date("2020-03-01"),
    "abc", as.Date("2020-04-01"), as.Date("2020-04-30"), 30, as.Date("2020-03-01")
  )

  expected <- tribble(
    ~MedicaidSystemID, ~total_days_precall,
    "123", 15,
    "456", 47,
    "abc", 47
  )

  expect_equal(expected, compute_medicaid_enrollment_precall(data))
})
