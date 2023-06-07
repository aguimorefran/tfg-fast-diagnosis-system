packages <- c(
    "fcaR",
    "Matrix",
    "RJDBC",
    "ggplot2",
    "dplyr",
    "tidyr",
    "plumber",
    "jsonlite"
)

is_installed <- function(pkg) {
    is.element(pkg, installed.packages()[, 1])
}

for (pkg in packages) {
    if (!is_installed(pkg)) {
        cat("\nInstalling", pkg, "...\n")
        install.packages(pkg, dependencies = TRUE)
        if (is_installed(pkg)) {
            cat("\n", pkg, "installed successfully.\n")
        } else {
            cat("\nFailed to install", pkg, ".\n")
        }
    } else {
        cat("\n", pkg, "is already installed.\n")
    }
}
