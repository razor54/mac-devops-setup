TASK 9: README IPSW Disk Validation Runbook — Semantic Consistency Check
Generated: 2026-03-16

=== SEMANTIC CONSISTENCY CHECK: README vs Scripts ===

Checking disk expectations alignment across README.md, scripts/tart-setup.sh, scripts/tart-test.sh:

1. Pre-built disk expectation:
   README.md:    "~44GB usable space due to a recovery partition"
   tart-setup.sh: "~44GB usable due to recovery partition" (line 14, 79, 84)
   tart-test.sh:  "prebuilt-expected (~${avail_gb}GB available)" (line 101)
   → CONSISTENT

2. IPSW disk expectation:
   README.md:    ">=90GB usable" (section heading and df -h expectation)
   tart-setup.sh: "you will have >=90GB usable space" (line 63)
   tart-test.sh:  "ipsw-expected" classification for >=90GB (line 92-94)
   → CONSISTENT

3. DISK_SIZE=100 command:
   README.md:    "USE_IPSW=true DISK_SIZE=100 ./scripts/tart-setup.sh" (line 112)
   tart-setup.sh: "USE_IPSW=true DISK_SIZE=100 ./scripts/tart-setup.sh" (line 89)
   tart-test.sh:  "USE_IPSW=true DISK_SIZE=100 ./scripts/tart-setup.sh" (line 102)
   → CONSISTENT

4. Manual Setup Assistant boundary:
   README.md:    6-step manual process documented (lines 114-121)
   tart-setup.sh: 5-step manual process in echo output (lines 66-72)
   tart-test.sh:  "Ensure Setup Assistant completed correctly" in remediation (line 97)
   → CONSISTENT

5. Classification labels:
   README.md:    Documents all three: prebuilt-expected, ipsw-expected, unexpected-low-space
   tart-test.sh:  Emits all three classifications
   → CONSISTENT

=== VERDICT ===

Docs and scripts use consistent expectations — no divergence detected.
All disk space messaging aligns across README.md, tart-setup.sh, and tart-test.sh.
