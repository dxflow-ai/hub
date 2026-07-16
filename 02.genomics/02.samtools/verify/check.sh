# verify.sh helper: block until the step exits, failing on a non-zero code
wait_exit

# verify.sh helper: assert each glob appears in the output volume
expect_output 'sorted.bam' 'flagstat.txt'
