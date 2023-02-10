#' Visualization utilities
#'
#' This file contains several visualation helper functions that ease our viz production


#' Create our standard theme. Returns a theme object
#'
#' @param base_size What should our base font size be for this theme?
#' @param base_family The base font family
#' @return The new theme. Apply via +
theme_new <- function(base_size = 24) {
  theme_bw(base_size = base_size) %+replace%
    theme(
      panel.grid = element_blank(),
      panel.border = element_rect(fill = NA, colour = "black", size = 1),
      panel.background = element_rect(fill = "white", colour = "black"),
      strip.background = element_rect(fill = NA),
      axis.text.x = element_text(color = "black"),
      axis.text.y = element_text(color = "black")
    )
}

#' A standardized plot of claims data by date
#'
#' @param claims_df The claims data to plot
#' @param xname A string version of the column name defining the x axis
#' @param yname A string version of the column name defining the y axis
#' @param vline_x The x-values at which to plot vertical lines
#' @return A plot object
plot_claims_data_by_date <- function(claims_df,
                                     xname = "fs_date",
                                     yname = "unique_claims",
                                     vline_x = c(
                                       as.numeric(as.Date("2018-04-19")),
                                       as.numeric(as.Date("2019-03-01"))
                                     ) # timestamp->numeric
) {
  sym_xname <- sym(xname)
  sym_yname <- sym(yname)

  ggplot(claims_df, aes(x = !!sym_xname, y = !!sym_yname)) +
    geom_line() +
    theme_new() +
    geom_vline(
      xintercept = vline_x,
      linetype = "dashed",
      color = "red",
      size = 2
    ) +
    scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b %Y"
    ) +
    coord_flip() +
    xlab("Month") +
    ylab("Unique Medicaid claims\n(before filtering)")
}

#' General function to save plots in pdf format (could generalize to png)
#' Defaults to saving in figure dir outlined in constants script
#'
#' @param plot_obj plot object
#' @param plot_name string with name of plot (without filetype suffix)
#' @return nothing
save_plot <- function(plot_obj, plot_name) {
  ggsave(file.path(FIGURE_DIR, sprintf("%s.pdf", plot_name)),
    plot = plot_obj,
    device = "pdf",
    width = 12,
    height = 8
  )
}
