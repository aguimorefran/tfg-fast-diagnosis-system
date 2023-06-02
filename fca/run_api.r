install.packages("plumber", dependencies = TRUE, repos = "http://cran.us.r-project.org")
library(plumber)

r <- plumb("fca/service.r")
r$run(port=8005)
