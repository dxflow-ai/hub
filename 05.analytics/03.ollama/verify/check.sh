# ollama is a long-running service: the server and web interface stay up.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the web interface answers
expect_http 8080
