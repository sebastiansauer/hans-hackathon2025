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
  # DATA IS EXPECTED TO RESIDE IN THIS FOLDER: "data/data-raw/SoSe25"
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
  tar_target(data_prepped,
    data_imported |>
      prep_data(),
    packages = "janitor"
  ),
  tar_target(data_all_fct,
    data_prepped |>
      mutate(across(everything(), as.factor)), # refactor into previous step
    packages = "collapse"
  ),
  tar_target( # refactor into previous step
    visitduration,
    data_prepped |>
      select(visitduration, idvisit, fingerprint) |>
      mutate(visitduration = as.duration(as.integer(visitduration)))
  ),
  tar_target(
    test_unique_idvisit,
    check_unique_ids(data_prepped)
  ),
  # select only id cols plus "actiondetails:"
  tar_target(
    data_wide_slim,
    data_all_fct |> extract_cols()
  ),
  # add uni and course to wide data:
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
  tar_target(
    data_separated_filtered_date_uni_course,
    add_date_uni_course_to_long_data(
      data_separated_filtered,
      course_and_uni_per_visit
    )
  ),
  # compute how much time was spent per visit:
  tar_target(
    time_spent,
    data_separated_filtered |> diff_time()
  ),
  tar_target(
    time_spent_fingerprint,
    data_separated_filtered |> diff_time(idvar = fingerprint)
  ),

  # compute when the site was visited:
  tar_target(
    time_visit_wday,
    data_separated_filtered |> when_visited()
  ),
  tar_target(
    time_visit_wday_fingerprint,
    when_visited_fingerprint(data = data_separated_filtered)
  ),


  # compute how much time was spent per course/per university and date:
  # one row is one visit
  tar_target(
    time_spent_w_course_university,
    compute_time_per_course_uni(
      data = time_spent,
      course_and_uni = course_and_uni_per_visit,
      idvar = idvisit
    )
  ),
  tar_target(
    time_spent_w_course_university_fingerprint,
    compute_time_per_course_uni(
      data = time_spent_fingerprint,
      course_and_uni = course_and_uni_per_visit,
      idvar = fingerprint
    )
  ),

  # count number of actions per visit and adds date of visit:
  tar_target(
    n_action_w_date,
    data_separated_filtered |> # one row is one visit
      count_action_w_date()
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
  ),


  # Challenge 07
  ## prompt length ----------------------------------------------------------
  # compute prompt length in tokens:
  # token itself is not saved, only length
  tar_target(
    prompt_length,
    data_separated_filtered |>
      compute_prompt_length(),
    packages = c("tokenizers", "stringr")
  ),
  tar_target(
    prompt_length_date_uni_course,
    time_spent_w_course_university |>
      mutate(idvisit = as.integer(idvisit)) |>
      left_join(prompt_length, by = "idvisit") |>
      select(-any_of(c("type", "value"))),
    packages = c("dplyr", "lubridate")
  ),
  tar_target(
    prompts_texts_date_course_uni,
    data_separated_filtered |>
      compute_prompt_length(no_prompt_text = FALSE) |>
      left_join(time_spent_w_course_university |> mutate(idvisit = as.integer(idvisit)),
        by = "idvisit"
      ),
    packages = c("tokenizers", "stringr")
  ),
  tar_target(
    n_interactions_w_llm_course_date_course_uni,
    count_llm_interactions_add_context(
      data_separated_filtered,
      time_spent_w_course_university
    )
  )


  # END OF PIPELINE ---------------------------------------------------------
)
