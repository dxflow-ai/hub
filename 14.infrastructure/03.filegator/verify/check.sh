# filegator is a long-running service: apache stays up and serves the file manager.

# verify.sh helper: block until the step is up and stays up
wait_running 10

# verify.sh helper: the front end answers on the published port
expect_http 8080

# verify.sh helper: and so does the app's own api, which only answers once php has
# read configuration.php and reached the volume — a static index.html would not
expect_http 8080 '/?r=/getconfig'
