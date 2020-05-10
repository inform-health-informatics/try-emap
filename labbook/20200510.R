# 2020-05-10
# Steve Harris
# Trying out Plotly

library(plotly)
fig <- plot_ly(midwest, x = ~percollege, color = ~state, type = "box")
# FIXME: 2020-05-10 this does not work; renders from r studio only the first time and then nothing
fig

# dash dependencies
install.packages(c("fiery", "routr", "reqres", "htmltools", "base64enc", "plotly", "mime", "crayon", "devtools"))

# as per instructions
# https://github.com/plotly/dashR
library(remotes)
remotes::install_github("plotly/dashR")

library(dash)
library(dashCoreComponents)
library(dashHtmlComponents)
library(dashTable)

app <- Dash$new()
app$layout(
  htmlDiv(
    list(
      # note that you are still using the same plot created and saved as fig
      dccGraph(figure=fig) 
    )
  )
)

# this more manual version seems to work
app$run_server(debug=TRUE, dev_tools_hot_reload=FALSE)
