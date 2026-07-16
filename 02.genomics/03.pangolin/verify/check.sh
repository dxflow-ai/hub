# verify.sh helper: block until the step exits, failing on a non-zero code
wait_exit

# verify.sh helper: assert the lineage report appears in the output volume
expect_output 'lineage_report.csv'
