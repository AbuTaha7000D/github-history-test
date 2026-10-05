#!/bin/bash
set -euo pipefail

# Generate a large synthetic Git history for testing.
#
# Usage:
#   ./generate-test-history.sh /path/to/test-repo
#
# Period:
#   2026-02-01 -> 2026-09-30
#
# Normal days:
#   2-9 commits
#
# Random outlier days:
#   0-1 or 10-20 commits

REPO="${1:-.}"

cd "$REPO"

# Safety check: must be a Git repository.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Error: '$REPO' is not a Git repository."
    exit 1
}

# Refuse to run if there are uncommitted changes.
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: repository has uncommitted changes."
    echo "Commit/stash them first, or use a clean test repository."
    exit 1
fi

TEST_FILE="synthetic-test-history.log"

touch "$TEST_FILE"

# Deterministic random seed.
# Change this number if you want a different generated history.
RANDOM=20261005

START_DATE="2026-02-01"
END_DATE="2026-09-30"

current="$START_DATE"
total=0
days=0
outlier_days=0

declare -A daily_counts

echo "Generating synthetic Git history..."
echo "Repository: $(pwd)"
echo "Period:     $START_DATE -> $END_DATE"
echo

while [[ "$current" < "$END_DATE" || "$current" == "$END_DATE" ]]; do

    # Decide whether this is an outlier day.
    # ~8% chance.
    roll=$((RANDOM % 100))

    if (( roll < 8 )); then
        ((outlier_days += 1))

        if (( RANDOM % 2 == 0 )); then
            # Very low activity day.
            commits=$((RANDOM % 2))       # 0-1
        else
            # High activity day.
            commits=$((10 + RANDOM % 11)) # 10-20
        fi
    else
        # Normal day: 2-9 commits.
        commits=$((2 + RANDOM % 8))
    fi

    daily_counts["$current"]=$commits

    # Generate commits for this day.
    for ((i = 1; i <= commits; i++)); do

        # Random time between 08:00 and 23:59.
        hour=$((8 + RANDOM % 16))
        minute=$((RANDOM % 60))
        second=$((RANDOM % 60))

        timestamp=$(printf "%s %02d:%02d:%02d" \
            "$current" "$hour" "$minute" "$second")

        ((total += 1))

        printf '%s | synthetic test commit %04d\n' \
            "$timestamp" "$total" >> "$TEST_FILE"

        GIT_AUTHOR_DATE="$timestamp" \
        GIT_COMMITTER_DATE="$timestamp" \
        git add "$TEST_FILE"

        GIT_AUTHOR_DATE="$timestamp" \
        GIT_COMMITTER_DATE="$timestamp" \
        git commit \
            -m "test: generated history commit $(printf '%04d' "$total")" \
            >/dev/null
    done

    ((days += 1))

    # Move to next day.
    current=$(date -d "$current + 1 day" +%Y-%m-%d)

    # Progress.
    printf "\rProcessed %d days | %d commits" "$days" "$total"
done

echo
echo
echo "========================================"
echo "Synthetic history generated successfully"
echo "========================================"
echo "Days:          $days"
echo "Total commits: $total"
echo "Outlier days:  $outlier_days"
echo

echo "Date range:"
git log --format='%ad' --date=short --reverse | head -n 1
git log --format='%ad' --date=short | head -n 1

echo
echo "Commit distribution:"
echo

printf '%s\n' "${!daily_counts[@]}" |
    sort |
    while read -r date; do
        count="${daily_counts[$date]}"
        printf '%s  %2d commits' "$date" "$count"

        if (( count <= 1 || count >= 10 )); then
            printf '  <-- OUTLIER'
        fi

        printf '\n'
    done

echo
echo "Total commits according to Git:"
git rev-list --count HEAD

echo
echo "Latest commits:"
git log -10 --date=iso --format='%h  %ad  %s'

echo
echo "Done."
