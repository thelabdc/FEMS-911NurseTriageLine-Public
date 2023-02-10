from plotnine import (
    aes,
    element_blank,
    element_text,
    geom_line,
    geom_point,
    ggplot,
    ggsave,
    labs,
    scale_color_manual,
    theme,
    xlab,
    ylab,
)

standard_background = theme(
    panel_background=element_blank(),
    panel_grid_major_y=element_blank(),
    axis_text_x=element_text(color="black", hjust=1, size=24),
    axis_text_y=element_text(color="black", size=24),
    legend_text=element_text(color="black", size=24),
    legend_title=element_text(color="black", size=24),
    axis_title=element_text(size=24),
    strip_text_x=element_text(size=12),
    legend_background=element_blank(),
    legend_key=element_blank(),
    panel_grid_major=element_blank(),
    panel_grid_minor=element_blank(),
    axis_ticks=element_blank(),
)

## fill colors
TREATMENT_COLOR = "#ffa600"
CONTROL_COLOR = "#003f5c"
