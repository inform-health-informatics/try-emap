# Example .Rprofile file
# Created 2020-04-29


# .Rprofile: save this file in your Documents folder 
# the documents folder is visible from a terminal in a number of different places
# depending on your terminal and your drive mapping
#
# e.g.
# MobaXterm
# /home/USER/MyDocuments
# Git Bash
# //UCLCMDDPRAFSS21/Home/sharris9/Documents
# R terminal
# //UCLCMDDPRAFSS21/Home/USER/Documents

# obviously replace USER with your username and 
# similarly the drive (e) or the network share (UCLCMDDPRAFSS21)

# You can get the path your Documents folder (HOME) in R using
# Sys.getenv('HOME')


message("Welcome ...")
message(paste(c("Loaded your .Rprofile from ", Sys.getenv("HOME"))))

# Set the CRAN mirror
# `local` creates a new, empty environment
# This avoids polluting .GlobalEnv with the object r
local({
  r = getOption("repos")             
  r["CRAN"] = "https://cran.rstudio.com/"
  options(repos = r)
})

# Set libpaths to include a directory in Documents

# NOTE: 2020-04-30 networked drives don't work with R CMD.exe; needs to be mounted so use latter location
.libPaths(c(file.path(Sys.getenv("HOME"), 'config','R') , .libPaths() ))

# UPDATE: 2020-05-05 now seems to work so commenting out this alternative path 
.libPaths(c(file.path('B:', 'config','R') , .libPaths() ))

message("Library paths .libPaths() are ")
.libPaths()
