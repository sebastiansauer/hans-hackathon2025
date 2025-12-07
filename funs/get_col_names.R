extract_cols <- function(data) {
  data |>
    get_vars(vars = c(
      "idvisit", "fingerprint",
      grep("actiondetails_", names(data), value = TRUE)
    ))
}
