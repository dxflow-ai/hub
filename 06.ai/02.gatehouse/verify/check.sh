# gatehouse is a long-running service: the interface, the API and the model
# server behind them stay up.

# verify.sh helper: block until the step is up and stays up. The window is wide
# because the endpoint checks below retry for 30s of their own, and a first
# start seeds the model store and boots two servers before it answers.
wait_running 60

# verify.sh helper: the interface answers
expect_http 8080 /health

# verify.sh helper: the API refuses a request carrying no credential
expect_http_auth 8080 /api/v1/auths/
