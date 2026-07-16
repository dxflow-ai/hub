# chromium is a long-running service: the desktop stays up and serves the browser.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the noVNC web endpoint answers
expect_http 6082

# verify.sh helper: the raw VNC port is open
expect_port 5901
