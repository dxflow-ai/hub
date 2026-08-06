# jupyter is a long-running service: jupyterlab stays up and serves the notebook UI.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the jupyterlab web endpoint answers, behind its password
expect_http_auth 8888
