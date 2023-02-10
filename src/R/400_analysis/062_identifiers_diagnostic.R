library(dplyr)
library(data.table)
library(lubridate)
library(ggplot2)
library(readxl)
library(stringr)
library(here)
library(assertthat)
library(readr)
library(xtable)

source(here("src", "R", "000_constants.R"))
source(here("src", "R", "001_viz_utils.R"))
source(here("src", "R", "400_analysis", "060_clean_ntl_data.R"))

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


#############################################
#### Read in NTL data and summarize their identifier status
#############################################

ntl_participants <- read_ntl_data()

## create a crosstable with counts of id_status by group
table(ntl_participants$id_status, ntl_participants$dispo_broad) %>%
  xtable(
    caption = "Counts of participants with each identifier status",
    label = "tab:identifier_counts",
    align = c(
      "p{6cm}",
      "r",
      "r"
    )
  ) %>%
  print(
    caption.placement = "top",
    file = file.path(TABLES_DIR, "identifier_breakdown.tex"),
  )

## create similar crosstab with proportions
table(ntl_participants$id_status, ntl_participants$dispo_broad) %>%
  prop.table(2) %>%
  xtable(
    caption = "Proportion by treatment status of each identifier status",
    label = "tab:identifier_proportions",
    align = c("r", "r", "r")
  ) %>%
  print(
    caption.placement = "top",
    digits = 2,
    file = file.path(TABLES_DIR, "identifier_breakdown_propofgroup.tex")
  )

## subset to each group and breakdown by ambulance status
ntl_t <- ntl_participants %>%
  filter(dispo_broad == "NTL treatment")
ntl_c <- ntl_participants %>%
  filter(dispo_broad == "NTL control")

## breakdown of proportions by ambulance status
print.xtable(xtable(table(ntl_t$id_status, ntl_t$ambulance_summary)),
  file = file.path(TABLES_DIR, "t_counts_idvamb.tex")
)

print.xtable(xtable(prop.table(table(ntl_t$id_status, ntl_t$ambulance_summary), 2)),
  file = file.path(TABLES_DIR, "t_prop_idvamb.tex")
)

tmp <- ntl_c %>%
  transmute(
    ambulance_summary = case_when(
      ambulance_summary == "Amb. dispatched +\ntransported caller" ~ "Dispatch + transport",
      ambulance_summary == "No amb. dispatch\nor transport" ~ "No dispatch",
      TRUE ~ "Dispatch + no transport"
    ),
    id_status = id_status
  )
table(tmp$id_status, tmp$ambulance_summary) %>%
  xtable(
    caption = "Breakdown of identifiers by ambulance status",
    label = "tab:id_v_amb",
  ) %>%
  print(
    caption.placement = "top",
    file = file.path(TABLES_DIR, "c_counts_idvamb.tex")
  )

print.xtable(xtable(prop.table(table(ntl_c$id_status, ntl_c$ambulance_summary), 2)),
  file = file.path(TABLES_DIR, "c_prop_idvamb.tex")
)


## breakdown of medicaid matches by status
print.xtable(xtable(table(ntl_participants$has_medicaid_id, ntl_participants$dispo_broad)),
  file = file.path(TABLES_DIR, "medicaid_breakdown.tex")
)

tmp <- ntl_participants %>%
  transmute(
    has_medicaid_id = if_else(
      has_medicaid_id == "Has Medicaid ID",
      "Matched to Medicaid",
      "Not matched"
    ),
    dispo_broad = dispo_broad,
    id_status = id_status
  )
table(tmp$has_medicaid_id, tmp$dispo_broad) %>%
  prop.table(2) %>%
  xtable(
    caption = "Match rates by treatment group",
    label = "tab:prop_match_bygroup",
  ) %>%
  print(
    caption.placement = "top",
    digits = 2,
    file = file.path(TABLES_DIR, "medicaid_breakdown_propofgroup.tex")
  )

## breakdown by identifier status
table(tmp$id_status, tmp$has_medicaid_id) %>%
  xtable(
    caption = "Identifiers versus match status",
    label = "tab:id_v_match"
  ) %>%
  print(
    caption.placement = "top",
    file = file.path(TABLES_DIR, "medicaid_breakdown_vidstatus.tex")
  )

## read in static attributes
medicaid_staticatt <- read.csv(get_mostrec("Medicaid_staticattributes"))
table(medicaid_staticatt$enr_24h, useNA = "always")

## get participants first call (load clean_ntl_data from script 060)
participants_firstcall <- clean_ntl_data(ntl_participants)

## subset to matches and take tx status at time
## of first call
medicaid_staticatt_match <- medicaid_staticatt %>%
  mutate(MedicaidSystemID = as.character(MedicaidSystemID)) %>%
  inner_join(participants_firstcall %>%
    select(
      MedicaidSystemID,
      dispo_broad,
      id_status, has_medicaid_id
    ),
  by = "MedicaidSystemID"
  )

## create indicator flags and numeric age at time of start of study
medicaid_staticatt_match <- medicaid_staticatt_match %>%
  mutate(
    is_black = ifelse(MemberRaceDescription == "African American", TRUE, FALSE),
    is_hispanic = ifelse(MemberRaceDescription == "Hispanic", TRUE, FALSE),
    is_caucasion = ifelse(MemberRaceDescription == "Caucasian", TRUE, FALSE),
    is_unknown_raceeth = ifelse(MemberRaceDescription == "Unknown", TRUE, FALSE),
    is_female = ifelse(MemberGenderDescription == "Female", TRUE, FALSE),
    age_startstudy = as.numeric(difftime(
      as.Date("2018-04-01"),
      dmy(MemberDateofBirth)
    )) / 365,
    years_everenrolled_firstcall = total_days_precall / 365
  )


## summarize overall
vars_summarize <- c(
  "is_black", "is_hispanic", "is_caucasion", "is_unknown_raceeth", "is_female",
  "age_startstudy", "years_everenrolled_firstcall", "enr_24h",
  "enr_6mo"
)

### overall
vars_summarize_means <- lapply(medicaid_staticatt_match[, vars_summarize], function(x) mean(x, na.rm = TRUE))
vars_summarize_means_df <- data.frame(
  var = names(vars_summarize_means),
  prop_overall = unlist(vars_summarize_means)
)

## t only
vars_summarize_means_t <- lapply(medicaid_staticatt_match[
  medicaid_staticatt_match$dispo_broad == "NTL treatment",
  vars_summarize
], function(x) mean(x, na.rm = TRUE))
vars_summarize_means_t_df <- data.frame(
  var = names(vars_summarize_means_t),
  prop_overall = unlist(vars_summarize_means_t)
)

## c only
vars_summarize_means_c <- lapply(medicaid_staticatt_match[
  medicaid_staticatt_match$dispo_broad == "NTL control",
  vars_summarize
], function(x) mean(x, na.rm = TRUE))
vars_summarize_means_c_df <- data.frame(
  var = names(vars_summarize_means_c),
  prop_overall = unlist(vars_summarize_means_c)
)



## add ward by group
wards <- reshape2::melt(prop.table(table(medicaid_staticatt_match$MemberWardName, medicaid_staticatt_match$dispo_broad), 2))
colnames(wards) <- c("var", "group", "prop_overall")

## rowbind all and take the standardized difference in means
all_dem_compare <- rbind.data.frame(
  vars_summarize_means_c_df %>%
    mutate(group = "NTL control"),
  vars_summarize_means_t_df %>%
    mutate(group = "NTL treatment"),
  wards
)

## find standardized difference in means
all_dem_compare_wide <- reshape2::dcast(all_dem_compare, var ~ group, value.var = "prop_overall") %>%
  mutate(stdiff_mean = (`NTL treatment` - `NTL control`) / (`NTL treatment`^(1 / 2)))



## plot one: differences
all_dem_compare_wide <- all_dem_compare_wide %>%
  mutate(type_var = case_when(
    grepl("is", var) ~ "Race/eth",
    grepl("enr", var) ~ "Medicaid enrollment",
    grepl("Ward|Outside", var) ~ "Ward"
  ))

## first, reshape to long and plot attributes by roup
all_dem_compare_backlong <- reshape2::melt(all_dem_compare_wide, id.vars = c("var", "stdiff_mean", "type_var")) %>%
  arrange(type_var, var)

ggplot(all_dem_compare_backlong, aes(
  x = var, y = value, group = variable,
  fill = variable
)) +
  geom_bar(stat = "identity", position = position_dodge(width = 1)) +
  theme_new(base_size = 12) +
  facet_wrap(~var, scales = "free") +
  xlab("") +
  ylab("") +
  theme(
    strip.text.x = element_blank(),
    legend.position = c(0.9, 0.1),
    legend.background = element_blank()
  ) +
  scale_fill_manual(values = c(
    "NTL treatment" = TREATMENT_COLOR,
    "NTL control" = CONTROL_COLOR
  )) +
  labs(fill = "")

ggsave(file.path(FIGURE_DIR, "covar_balance_varbyvar.pdf"),
  plot = last_plot(),
  width = 12,
  height = 8
)

## balance plot
ggplot(all_dem_compare_wide, aes(
  x = var, y = stdiff_mean,
  group = type_var
)) +
  geom_point(size = 4) +
  theme_new() +
  coord_flip() +
  geom_hline(
    yintercept = 0, linetype = "dashed",
    color = "red"
  ) +
  ylab("Standardized difference in means\ntreatment - control") +
  xlab("")

ggsave(file.path(FIGURE_DIR, "covar_balance_overall.pdf"),
  plot = last_plot(),
  width = 12,
  height = 8
)
