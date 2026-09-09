# verify.sh setting: where the default transfer lands (checked by expect_output).
# A directory of its own, not the volume root — the harness deletes this path
# around the run, and the volume is shared with every other workflow.
output=s3

# verify.sh setting: nothing is uploaded — the default run pulls from a public bucket
input=s3

# verify.sh setting: the transfer reaches out to AWS, so allow for a slow network
timeout=300
