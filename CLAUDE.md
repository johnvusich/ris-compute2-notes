# Rules for this repo

1. **Read `docs/` first.** Before doing anything, read `docs/` and follow its storage, scratch, and Slurm conventions (`02_storage.md`, `03_slurm_accounts.md`, `04_nextflow.md`).
2. **Change one thing per attempt.** Never combine multiple fixes in a single run.
3. **Log every attempt** in `docs/07_pipeline_tests.md`: Slurm job ID, what changed, the error (if any), and the result.
4. **Commit after each attempt**, including the log entry.
5. **Never commit secrets, tokens, large logs, or data.** Check `git diff --staged` before each commit.
6. **Never delete anything outside the test directory**
   (`/storage3/fs1/sheila.stewart/Active/john.v/tests/<pipeline>_<version>/`).
7. **Stop and ask me**:
   - after 5 failed attempts, or
   - before any change that would cost more than ~50 CPU hours.
