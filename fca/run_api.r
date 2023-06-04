install.packages("plumber")
library(plumber)

r <- plumb("fca/FDS_api.r")
r$run(port=8005)
