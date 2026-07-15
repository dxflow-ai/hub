# rstudio is a long-running service: rstudio-server stays up and serves the IDE.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the rstudio-server web endpoint answers
expect_http 8787
