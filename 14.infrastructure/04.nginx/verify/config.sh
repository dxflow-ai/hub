# verify.sh setting: the configuration directory the check drops a snippet into.
# The harness clears this path around the run, so the reload is tested against a
# directory the step seeds itself rather than one a previous run left behind.
input=nginx
output=nginx
