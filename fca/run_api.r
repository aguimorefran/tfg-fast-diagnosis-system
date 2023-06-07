if (!is.element("plumber", installed.packages()[, 1])) {
    install.packages("plumber")
}
library(plumber)


r <- plumb("FDS_api.r")
r$run(
    host = "0.0.0.0",
    port = 8005
)
