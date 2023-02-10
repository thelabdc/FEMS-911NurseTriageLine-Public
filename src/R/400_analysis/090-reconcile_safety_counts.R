# Reconcile safety counts
# 2023-02-02

library(here)
library(janitor)
library(readxl)
library(tidyverse)

# Half sample:
# xl_path <- "MASTER_NTL_PAPER_TRANSFER_OUTCOMES.xlsx"
# df_safety_holman <- read_excel(xl_path)

# Full sample:

xl_path <- "FEMS DC 911 2018-2019 Year End Report Final v2.xlsx"
sheet_name <- "2018-2019 YTD Transaction Data"

df_safety_holman <- read_excel(xl_path,
                               sheet = sheet_name)
                                 
df_safety_holman <- df_safety_holman |> 
  clean_names() |> 
  filter(created_eastern_time > "2018-04-18" & 
           created_eastern_time < "2019-03-02")

# Get final_data from Box and read:

path_ntl_data <- here("final_data", "intermediate_objects", "ntl_withmedicaidIDS_06-25-22-18-13-04.csv")
df_ntl_medicaid <- read_csv(path_ntl_data)

df_ntl_medicaid <- df_ntl_medicaid |> clean_names()

ntl_ids <- df_ntl_medicaid |> 
  filter(dispo_broad == "NTL treatment") |>
  pull(num_1) 

ntl_ids %in% 
  df_safety_holman$femsid |>
  table()

df_safety_holman$femsid %in% ntl_ids |> table()

table(nchar(df_safety_holman$femsid))
