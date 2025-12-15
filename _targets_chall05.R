# MASTER PIPELINE HANS LOG DATA ANALYSIS
# author: Sebastian Sauer

# setup -------------------------------------------------------------------
library("targets")
library("tarchetypes")

tar_option_set(
  packages = c(
    "data.table",
    "dplyr",
    "purrr",
    "readr",
    "tidyr",
    "collapse",
    "stringr",
    "lubridate"
  )
)

options(lubridate.week.start = 1)

tar_source("funs")

# START OF PIPELINE -------------------------------------------------------

## import data -------------------------------------------------------------
list(
  tar_target(config_file, "config.yaml", format = "file"),
  tar_target(config, read_yaml(config_file), packages = "yaml"),
  tar_target(data_files_list, find_data_files(config), format = "file"),
  tar_target(data_files_dupes_excluded, exclude_dupes(data_files_list)),
  tar_target(
    data_imported,
    data_files_dupes_excluded |>
      import_and_bind_data()
  ),

  ## prep data ---------------------------------------------------------------
  tar_target(data_prepped, data_imported |>
    prep_data(), packages = "janitor"),
  tar_target(data_all_fct,
    data_prepped |>
      mutate(across(everything(), as.factor)),
    packages = "collapse"
  ),
  tar_target(
    test_unique_idvisit,
    check_unique_ids(data_prepped)
  ),
  tar_target(
    data_wide_slim,
    data_all_fct |> extract_cols()
  ),
  tar_target(
    course_and_uni_per_visit,
    data_wide_slim |> extract_course_role_university_of_visit()
  ),


  ## pivot longer ------------------------------------------------------------
  tar_target(data_long,
    data_all_fct |> longify_data(),
    packages = c("data.table", "assertthat", "tibble")
  ),
  tar_target(data_separated,
    slimify_nona_data(data_long),
    packages = c("dplyr", "tidyr", "collapse")
  ),
  tar_target(
    data_separated_filtered,
    data_separated |>
      filter_column_type()
  ),

  ## count stuff per visit -------------------------------------------------
  # number of visits in total:
  tar_target(
    n_visits,
    data_long |>
      pull(idvisit) |>
      unique() |>
      length()
  ),
  # count number of actions per visit:
  tar_target(
    n_action,
    data_separated_filtered |>
      group_by(idvisit) |>
      summarise(nr_max = max(nr))
  ),
  # count number of action per unique visitor:
  tar_target(
    n_action_fingerprint,
    data_separated_filtered |>
      group_by(fingerprint) |>
      summarise(nr_max = max(nr))
  ),
  tar_target(
    n_action_lt_500,
    n_action |>
      filter(nr_max != 499)
  ),
  tar_target(
    n_action_lt_500_fingerprint,
    n_action_fingerprint |>
      filter(nr_max != 499)
  )


  # END OF PIPELINE ---------------------------------------------------------
)
