library(assertthat)
library(data.table)
library(dplyr)
library(ggplot2)
library(here)
library(lubridate)
library(readr)
library(reshape2)
library(stargazer)
library(xtable)

source(here("src", "R", "000_constants.R"))
source(here("src", "R", "001_viz_utils.R"))


###############################
#### Read and clean data
###############################

ptlevel_benefic_only <- read_csv(PT_LEVEL_BENEFICIARY)
ptlevel_benefic_wbound <- read_csv(PT_LEVEL_WBOUNDS)

#'
#'
#' @param data The Medicaid file to manipulate
#' @return The cleaned dataframe
#' rj note: since these analyses dont include the full analytic sample,
#' I removed the joins with ntl_participants otherwise the denominators
#' get thrown off
clean_medicaid_data <- function(data, include_expend = TRUE) {
  if (include_expend) {
    data_clean <- data %>%
      mutate(
        is_treatment = dispo_broad == "NTL treatment",
        logged_expenditures_24 = log(total_expenditures_24ho + 1), # NOTE(khw): Typically you take log(1 + x); rj: sounds good!
        logged_expenditures_6 = log(total_expenditures_6mo + 1)
      )
  } else {
    data_clean <- data %>%
      mutate(
        is_treatment = dispo_broad == "NTL treatment"
      )
  }

  return(data_clean)
}


## first clean main analytic data
ptlevel_benefic_clean <- clean_medicaid_data(ptlevel_benefic_only)

## then clean bounding data for binary outcomes; doesnt have expenditure vars
ptlevel_bounds_clean <- clean_medicaid_data(ptlevel_benefic_wbound,
  include_expend = FALSE
)

#' Create a basic descriptive plot of the joined data
#'
#' @param data The dataframe to describe
#' @return A ggplot object
basic_descriptives <- function(data, which_outcome) {

  # Pivot table (probably can do with pivot_wider, but it's inscrutible)
  numerator <- data %>%
    group_by(dispo_broad, !!sym(which_outcome)) %>%
    summarize(numer = n(), .groups = "drop") %>%
    ungroup()

  denominator <- data %>%
    group_by(dispo_broad) %>%
    summarize(denom = n(), .groups = "drop") %>%
    ungroup()

  prop_use <- numerator %>%
    inner_join(denominator, by = "dispo_broad") %>%
    mutate(
      proportion = numer / denom,
      percent = numer / denom * 100
    ) %>%
    select(dispo_broad, all_of(which_outcome), proportion, percent)

  prop_use <- rename(prop_use, c("outcome" = which_outcome))

  return(prop_use) # rj: returning to have more control over graph aesthetics/combining outcomes
}

## run with prespec outcomes
### observed outcomes (suffix is irrelevant)
outcomes_tosummarize_obs <- sprintf(
  "%s_%s",
  rep(c(
    "is_unnecessary_ED_1ormore_optimistic",
    "is_PCP_oneormore_optimistic"
  ), each = 2),
  c("24ho", "6mo")
)

tables_obs_outcomes <- lapply(outcomes_tosummarize_obs,
  basic_descriptives,
  data = ptlevel_benefic_clean
)
names(tables_obs_outcomes) <- outcomes_tosummarize_obs

## rbind the descriptives and add outcomes as a col
tables_obs_outcomes_df <- rbindlist(tables_obs_outcomes, idcol = TRUE) %>%
  mutate(
    time_horizon = case_when(
      grepl("24ho", .id) ~ "24 hours",
      TRUE ~ "6 months"
    ),
    outcome_clean =
      case_when(
        grepl("ED", .id) ~ sprintf("ED visit\n(non-emergent;\n%s)", time_horizon),
        grepl("PCP", .id) ~ sprintf("Primary care visit\n(%s)", time_horizon)
      )
  )


###############################
#### Run regressions
###############################


#' Run regressions per our specification. The formula is::
#'
#'    outcome ~ treatment
#'
#' @param data The data frame on which to run the regressions
#' @param outcome The outcome variable name
#' @param treatment The treatment variable name
#' @param outcome_type The type of the outcome. Must be either "binary" or "continuous"
#' @return A regresion object
run_regression <- function(data, outcome, treatment = "is_treatment", outcome_type = "binary") {
  assert_that(
    outcome_type == "binary" | outcome_type == "continuous",
    msg = "outcome_type must be either 'binary' or 'continuous'"
  )

  f <- formula(sprintf("%s ~ %s", outcome, treatment))
  if (outcome_type == "binary") {
    return(glm(f, data = data, family = "binomial"))
  } else {
    return(lm(f, data = data))
  }
}

## run with all the binary outcomes
results_binary <- lapply(outcomes_tosummarize_obs, run_regression,
  data = ptlevel_benefic_clean
)
names(results_binary) <- outcomes_tosummarize_obs
lapply(results_binary, summary)

## run with continous outcomes
cont_vars <- grep("logged_expenditures", colnames(ptlevel_benefic_clean),
  value = TRUE
)

## first, for those 2, NA are expenditures of 0
ptlevel_benefic_clean[, cont_vars][is.na(ptlevel_benefic_clean[
  ,
  cont_vars
])] <- 0


results_cont <- lapply(cont_vars, run_regression,
  data = ptlevel_benefic_clean,
  outcome_type = "continuous"
)
names(results_cont) <- cont_vars
lapply(results_cont, summary)

tables_obs_outcomes_df %>%
  filter(outcome == TRUE) %>%
  select(outcome_clean, time_horizon, dispo_broad, percent) %>%
  rename(
    Outcome = outcome_clean,
    `Time horizon` = time_horizon,
    Disposition = dispo_broad,
    Percent = percent
  ) %>%
  xtable(
    caption = "Exact rates and proportions: ED visits and PCP visits",
    label = "tab:exact_rates",
    digits = 2
  ) %>%
  print(
    include.rownames = FALSE,
    caption.placement = "top",
    file = file.path(TABLES_DIR, "ed_versus_pcp_vists.tex")
  )

stargazer(
  results_cont,
  title = "Regression results: logged healthcare expenditures in 24 hours and six months after call",
  label = "tab:reg_exp",
  dep.var.labels = c("Logged expenditure w/i 24 hours", "Logged expenditure w/i 6 months"),
  covariate.labels = c("treatment", "constant"),
  digits = 3,
  font.size = "scriptsize",
  out = file.path(TABLES_DIR, "results_continuous.tex")
)
stargazer(
  results_binary,
  title = "Regression results: emergency department and primary care physician utilization",
  label = "tab:reg_binary",
  column.labels = c("Unnecessary ED", "Primary care physician"),
  column.separate = c(2, 2),
  dep.var.labels = c("24 hours post-call", "Six months post-call", "24 hours post-call", "Six months post-call"),
  digits = 3,
  font.size = "scriptsize",
  out = file.path(TABLES_DIR, "results_binary.tex")
)

###############################
#### Plot results
###############################

## Binary outcomes
### todo: add p value for ones < 0.001
ggplot(
  tables_obs_outcomes_df %>% filter(outcome),
  aes(
    x = factor(outcome_clean), y = percent, fill = dispo_broad,
    group = dispo_broad
  )
) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_manual(values = c(
    "NTL treatment" = TREATMENT_COLOR,
    "NTL control" = CONTROL_COLOR
  )) +
  theme_new() +
  xlab("") +
  ylab("Percentage of group") +
  theme(
    legend.position = "bottom",
    legend.background = element_blank()
  ) +
  labs(fill = "") +
  annotate("text",
    x = c(1.21, 3.2),
    y = c(28, 11),
    label = "p<0.001", # rj note: hard coded but easier to do manually
    size = 6
  )

ggsave(file.path(FIGURE_DIR, "ed_pcp.pdf"),
  plot = last_plot(),
  device = "pdf",
  width = 12,
  height = 8
)


###############################
#### Pending discussion: bounding
###############################
