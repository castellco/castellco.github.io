bg <- "#efefef"
title_col <- "#bf0a30"
# title_font <- "American Typewriter Regular"
# font-weight: 400


ggplot2::ggplot() +
annotate("text",
         x = 0.5,
         y = 0.5,
         size = 14,
         label = "Carolina\nCornejo\nCastellano") + 
  theme_void() +
  theme(
    panel.background = element_rect(fill = bg)
  )

# change annotate color


