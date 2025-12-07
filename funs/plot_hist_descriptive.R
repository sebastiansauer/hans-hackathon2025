# Custom histogram with descriptive stats
plot_hist_descriptive <- function(data, var, bins = 30, title = NULL) {
  # Make sure var is a string
  var <- rlang::ensym(var)

  # Compute descriptive statistics
  stats <- data %>%
    summarise(
      n = n(),
      mean = mean(!!var, na.rm = TRUE),
      median = median(!!var, na.rm = TRUE),
      sd = sd(!!var, na.rm = TRUE),
      min = min(!!var, na.rm = TRUE),
      max = max(!!var, na.rm = TRUE)
    )

  # Create annotation text
  stats_text <- paste0(
    "N = ", stats$n, "\n",
    "Mean = ", round(stats$mean, 2), "\n",
    "Median = ", round(stats$median, 2), "\n",
    "SD = ", round(stats$sd, 2), "\n",
    "Min = ", round(stats$min, 2), "\n",
    "Max = ", round(stats$max, 2)
  )

  # Plot histogram with annotation
  ggplot(data, aes(x = !!var)) +
    geom_histogram(aes(y = after_stat(density)), bins = bins, fill = "skyblue", color = "black") +
    geom_density(color = "red", size = 1) +
    annotate("text",
      x = Inf, y = Inf,
      label = stats_text,
      hjust = 1.1, vjust = 1.1,
      size = 4,
      color = "black"
    ) +
    labs(title = title, x = rlang::as_name(var), y = "Density") +
    theme_minimal()
}
