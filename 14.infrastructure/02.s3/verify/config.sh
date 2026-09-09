# verify.sh setting: the volume the transfer lands in (checked by expect_output)
output=data

# verify.sh setting: nothing is uploaded — the default run pulls from a public bucket
input=data

# verify.sh setting: the transfer reaches out to AWS, so allow for a slow network
timeout=300
