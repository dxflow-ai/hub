# verify.sh helper: block until the step exits, failing on a non-zero code
wait_exit

# verify.sh helper: assert each glob appears in the output volume — the default
# SOURCE is a public NOAA prefix of 21 station csv files
expect_output '*.csv'
