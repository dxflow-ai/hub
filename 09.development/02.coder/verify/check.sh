# coder is a long-running service: code-server stays up and serves the IDE.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the code-server web endpoint answers
expect_http 8080
