#Sys.setenv(TAR_PROJECT = "challenge06")


library(targets)
library(tarchetypes)  # Extention to "targets", eg watching source data files
library(quarto)  # Quarto reports



# packages available for all targets:
tar_option_set(
  packages = c("dplyr", "purrr", "readr", "tidyr")
)

# set options:
options(lubridate.week.start = 1)



# targets, ie., steps to be computed:
list(
  # read data:
  tar_target(data_files_list, 
             list.files(path = paste0(here::here(),"/data-processed/data-raw-no-sensitive"),  # MY path to the data
                        full.names = TRUE,
                        pattern = "*.csv$",
                        recursive = TRUE), 
             format = "file"),  # watch data source files
  
  # bind all csv files into one long dataframe:
  tar_target(one_df,
             data_files_list |> 
               map(~ fread(.x, fill = TRUE)) |> 
               rbindlist(fill = TRUE, idcol = "file", use.names = TRUE),
             packages = "data.table"),
  
  # remove empty cols and rows:
  tar_target(rm_empty,
             one_df |> 
               remove_empty(which = c("rows", "cols")), packages = "janitor"),
  
  # remove constant cols:
  tar_target(rm_constants,
             rm_empty |> 
               remove_constant(), packages = "janitor"),
  
  # select only subtitles and timestamps:
  tar_target(df_subtitles_timestamps,
             rm_constants |> 
               select(idVisit, contains("subtitle"), contains("timestamp"))),
  
  # repair date-time cols:
  tar_target(repair_dttm,
              df_subtitles_timestamps |> 
                mutate(across(contains("timestamp"), ~ as_datetime(as.numeric(.x)))),
              packages = "lubridate"),
  
  # exclude developers, lecturers and admins:
  tar_target(rm_lecturers_admins,
              repair_dttm |> 
                filter(!str_detect(actionDetails_0_subtitle, "developer|lecturer|admin")),
             packages = "stringr"),
  
  # pivot longer:
  tar_target(d_long,
             rm_lecturers_admins |> 
               select(idVisit, contains("subtitle")) |> 
               mutate(across(everything(), as.character)) |> 
               pivot_longer(-idVisit) ),
  
  # add id col:
  tar_target(add_id_col,
             d_long |> 
               rename(id = name) |> 
               mutate(id = str_extract(id, "\\d+")), packages = "stringr"),
  
  
  # count actions per visit:
  tar_target(actions_per_visit,
             add_id_col |>
               group_by(idVisit) |>
               # "nr" is the id of the action of this visit:
               summarise(nr_max = max(id)))
  
  
  # render report in Quarto:
  
# tar_quarto(challenge06_report, "challenges_solutions/challenge06.qmd")
  
)
