# coder is a long-running service: code-server stays up and serves the IDE.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the code-server web endpoint answers, behind its password
expect_http_auth 8080
