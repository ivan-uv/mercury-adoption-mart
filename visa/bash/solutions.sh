#!/usr/bin/env bash
# ============================================================
# Visa Bash Practice — Solutions
# Senior Analyst, Global Interchange Compliance
#
# Each solution includes the command, expected output, and
# an interview-context note explaining why this matters.
#
# Usage:
#   bash solutions.sh setup_sample_data   # create test files first
#   bash solutions.sh q1                  # run a specific solution
#   bash solutions.sh all                 # run all solutions
# ============================================================

DATA_DIR="/tmp/visa_bash_practice"
TXN_FILE="$DATA_DIR/transactions.csv"
LOG_FILE="$DATA_DIR/compliance_alerts.log"
MER_FILE="$DATA_DIR/merchants.csv"
DAILY_DIR="$DATA_DIR/daily"

# Source the setup function from questions.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/questions.sh"

print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

print_note() {
    echo "  [Interview note] $1"
    echo ""
}


# ============================================================
# 1. FILE INSPECTION & NAVIGATION
# ============================================================

q1() {
    print_header "Q1: Count transactions (excluding header)"
    tail -n +2 "$TXN_FILE" | wc -l | tr -d ' '
    # Alternative: echo $(( $(wc -l < "$TXN_FILE") - 1 ))
    print_note "First thing you do with any new dataset: how big is it? At Visa, 'big' means billions — but the instinct to profile before querying is what they want to see."
}

q2() {
    print_header "Q2: Show header row"
    head -1 "$TXN_FILE"
    print_note "Knowing column positions is essential for cut/awk commands. In interviews, always confirm the schema before writing queries."
}

q3() {
    print_header "Q3: Last 5 transactions"
    tail -5 "$TXN_FILE"
    print_note "tail is useful for checking recent data loads — did the latest batch make it into the file?"
}

q4() {
    print_header "Q4: File size in bytes"
    wc -c < "$TXN_FILE" | tr -d ' '
    # macOS alternative: stat -f%z "$TXN_FILE"
    # Linux alternative: stat --printf="%s" "$TXN_FILE"
    print_note "File size monitoring catches truncated loads. A compliance pipeline should alert if today's file is significantly smaller than yesterday's."
}

q5() {
    print_header "Q5: Unique card types"
    tail -n +2 "$TXN_FILE" | cut -d',' -f8 | sort -u
    # Alternative: awk -F',' 'NR>1 {print $8}' "$TXN_FILE" | sort -u
    print_note "Understanding the card_type distribution is step one of any interchange analysis — rates vary dramatically between consumer credit, debit, and commercial."
}


# ============================================================
# 2. TEXT PROCESSING
# ============================================================

q6() {
    print_header "Q6: Count downgraded transactions"
    grep -c "downgraded" "$TXN_FILE"
    print_note "Downgrades are a core compliance KPI. A spike in downgrades means acquirers/merchants are losing money on higher-than-expected interchange."
}

q7() {
    print_header "Q7: ACQ001 transactions — transaction_id and amount_usd"
    awk -F',' '$4 == "ACQ001" {print $1, $7}' "$TXN_FILE"
    # Alternative: grep "ACQ001" "$TXN_FILE" | cut -d',' -f1,7
    print_note "Isolating by acquirer is a common first step when investigating a client-reported issue."
}

q8() {
    print_header "Q8: Transactions with interchange variance"
    awk -F',' 'NR>1 && $10 != $11 && $10 != "" && $11 != "" {
        printf "%s  actual=%.4f  expected=%.4f  variance=%.4f\n", $1, $10, $11, $10-$11
    }' "$TXN_FILE"
    print_note "Interchange variance is the primary signal for compliance issues. actual != expected means something was misclassified, mis-rated, or mis-settled."
}

q9() {
    print_header "Q9: Top MCC codes by transaction count"
    tail -n +2 "$TXN_FILE" | cut -d',' -f13 | sort | uniq -c | sort -rn
    print_note "MCC distribution analysis helps spot misclassification — e.g., if a 'grocery' MCC has suspiciously high average tickets, it may be misclassified."
}

q10() {
    print_header "Q10: ERROR lines from compliance log"
    grep "ERROR" "$LOG_FILE" | awk '{
        timestamp = $1 " " $2;
        $1=$2=$3="";
        sub(/^   /, "", $0);
        print timestamp " — " $0
    }'
    # Simpler: grep "ERROR" "$LOG_FILE" | sed 's/ERROR //'
    print_note "Log parsing is daily work. When an Airflow DAG fails, you grep the logs for ERROR to triage."
}


# ============================================================
# 3. PIPING & ONE-LINERS
# ============================================================

q11() {
    print_header "Q11: Total interchange amount"
    tail -n +2 "$TXN_FILE" | awk -F',' '{sum += $10} END {printf "$%.4f\n", sum}'
    print_note "Quick aggregate checks catch settlement discrepancies. If today's total is 20% off from the 30-day average, investigate."
}

q12() {
    print_header "Q12: Potential duplicate transactions"
    echo "(Duplicates by card_hash + merchant_id + amount):"
    tail -n +2 "$TXN_FILE" | awk -F',' '{key = $2","$5","$7; txns[key] = txns[key] " " $1; count[key]++}
        END {for (k in count) if (count[k] > 1) print k, " -> " txns[k]}'
    print_note "Duplicate detection is a top compliance concern. Same card + same merchant + same amount within a short window = possible double-charge. The schema includes card_number_hash specifically for this."
}

q13() {
    print_header "Q13: Grocery (MCC 5411) transactions with merchant names"
    # Load merchants into an awk associative array, then process transactions
    awk -F',' '
        NR==FNR {mer[$1] = $2; next}
        FNR>1 && $13 == "5411" {
            print $1, mer[$5], $7, $12
        }
    ' "$MER_FILE" "$TXN_FILE" | column -t
    print_note "Joining files in Bash is a power move. In practice you'd use SQL, but showing you can do ad-hoc joins on the CLI demonstrates strong fundamentals."
}

q14() {
    print_header "Q14: Log level counts"
    awk '{print $3}' "$LOG_FILE" | sort | uniq -c | sort -rn
    print_note "Monitoring log level distribution over time is a basic ops health check. A jump in ERROR count triggers investigation."
}

q15() {
    print_header "Q15: Top 3 merchants by transaction volume"
    tail -n +2 "$TXN_FILE" | awk -F',' '{vol[$5] += $7}
        END {for (m in vol) printf "%.2f  %s\n", vol[m], m}' | sort -rn | head -3
    print_note "Top-N queries are bread and butter for compliance analysts — who are the biggest players, and are their rates correct?"
}


# ============================================================
# 4. LOOPS & CONDITIONALS
# ============================================================

q16() {
    print_header "Q16: Count transactions per daily file"
    for f in "$DAILY_DIR"/*.csv; do
        count=$(tail -n +2 "$f" | wc -l | tr -d ' ')
        echo "$(basename "$f"): $count transactions"
    done
    print_note "Batch processing is how daily compliance monitoring starts. Before Airflow, teams ran loops like this in cron."
}

q17() {
    print_header "Q17: Daily downgrade rates"
    for f in "$DAILY_DIR"/*.csv; do
        total=$(tail -n +2 "$f" | wc -l | tr -d ' ')
        downgrades=$(grep -c "downgraded" "$f")
        if [ "$total" -gt 0 ]; then
            rate=$(awk "BEGIN {printf \"%.1f\", ($downgrades / $total) * 100}")
            echo "$(basename "$f"): ${rate}% downgrade rate"
        fi
    done
    print_note "Downgrade rate trending is a key daily check. If it jumps after a rate change (April/October), the compliance team needs to investigate immediately."
}

q18() {
    print_header "Q18: Downgrade rate alert (threshold: 30%)"
    THRESHOLD=30
    for f in "$DAILY_DIR"/*.csv; do
        total=$(tail -n +2 "$f" | wc -l | tr -d ' ')
        downgrades=$(grep -c "downgraded" "$f")
        if [ "$total" -gt 0 ]; then
            rate=$(awk "BEGIN {printf \"%.1f\", ($downgrades / $total) * 100}")
            exceeds=$(awk "BEGIN {print ($rate > $THRESHOLD) ? 1 : 0}")
            if [ "$exceeds" -eq 1 ]; then
                echo "WARNING: $(basename "$f") downgrade rate ${rate}% exceeds ${THRESHOLD}% threshold"
            fi
        fi
    done
    echo "(Any file above 30% triggers the warning above)"
    print_note "This is exactly the kind of check that would become an Airflow task with a SlackOperator or EmailOperator for alerts."
}

q19() {
    print_header "Q19: Combine daily CSVs (single header)"
    local output="$DATA_DIR/combined.csv"
    head -1 "$DAILY_DIR"/interchange_2026-03-01.csv > "$output"
    for f in "$DAILY_DIR"/*.csv; do
        tail -n +2 "$f" >> "$output"
    done
    echo "Combined file: $(wc -l < "$output" | tr -d ' ') lines (1 header + $(tail -n +2 "$output" | wc -l | tr -d ' ') data rows)"
    cat "$output"
    print_note "Combining partitioned files is a daily ETL task. The key gotcha is handling the header — include it once, not per file."
}

q20() {
    print_header "Q20: Split transactions by acquirer"
    local header
    header=$(head -1 "$TXN_FILE")
    # Get unique acquirer IDs
    for acq in $(tail -n +2 "$TXN_FILE" | cut -d',' -f4 | sort -u); do
        local outfile="$DATA_DIR/acq_${acq}.csv"
        echo "$header" > "$outfile"
        awk -F',' -v acq="$acq" 'NR>1 && $4 == acq' "$TXN_FILE" >> "$outfile"
        count=$(tail -n +2 "$outfile" | wc -l | tr -d ' ')
        echo "$outfile: $count transactions"
    done
    print_note "Splitting by acquirer is common for distributing client-specific compliance reports. Each acquirer gets only their transactions."
}


# ============================================================
# 5. CRON & SCHEDULING
# ============================================================

q21() {
    print_header "Q21: Daily compliance check cron entry"
    echo '0 6 * * * /usr/bin/python3 /opt/compliance/daily_check.py >> /var/log/compliance_daily.log 2>&1'
    echo ""
    echo "Breakdown: 0=minute, 6=hour, *=any day, *=any month, *=any weekday"
    print_note "This runs every day at 6 AM. The >> appends (not overwrites) and 2>&1 captures stderr too. Use full paths because cron has a minimal PATH."
}

q22() {
    print_header "Q22: Semi-annual rate change validation"
    echo '0 0 1 4,10 * /usr/bin/python3 /opt/compliance/rate_change_validator.py >> /var/log/rate_changes.log 2>&1'
    echo ""
    echo "Breakdown: midnight on the 1st of April and October"
    print_note "Visa updates interchange rates twice a year (April and October). The compliance team runs validation scripts to confirm all rates were applied correctly across the network."
}

q23() {
    print_header "Q23: Weekly Durbin audit (Mondays 7 AM)"
    echo '0 7 * * 1 /usr/bin/python3 /opt/compliance/durbin_audit.py 2>&1 | mail -s "Weekly Durbin Audit" compliance@visa.com'
    echo ""
    echo "Breakdown: 7 AM, any date, any month, weekday=1 (Monday), pipe output to mail"
    print_note "Durbin cap compliance must be 100%. A weekly audit catches any violations before they accumulate into a regulatory issue."
}

q24() {
    print_header "Q24: Cron concepts"
    echo '2>&1:'
    echo '  Redirects stderr (file descriptor 2) to stdout (file descriptor 1).'
    echo '  Without this, errors go to cron mail instead of the log file.'
    echo '  In compliance pipelines, you want ALL output captured for the audit trail.'
    echo ''
    echo '> vs >>:'
    echo '  > overwrites the file each run (you lose history).'
    echo '  >> appends to the file (preserves full log history).'
    echo '  For compliance logs, ALWAYS use >> to maintain an audit trail.'
    echo ''
    echo 'Full path to python:'
    echo '  Cron runs with a minimal PATH (typically just /usr/bin:/bin).'
    echo '  Your shell profile (.bashrc, .zshrc) is NOT sourced.'
    echo '  If python3 is in /usr/local/bin or a virtualenv, cron won'\''t find it.'
    echo '  Always use absolute paths: /usr/bin/python3 or /opt/venv/bin/python3.'
    print_note "These are fundamentals that distinguish someone who has actually deployed scheduled jobs from someone who only writes ad-hoc scripts."
}


# ============================================================
# 6. PROCESS MANAGEMENT & SYSTEM
# ============================================================

q25() {
    print_header "Q25: Find compliance-related Python processes"
    echo "Command: ps aux | grep '[c]ompliance.*python\|python.*[c]ompliance'"
    echo ""
    echo "(The [c] trick prevents grep from matching itself in the output)"
    # Actually run it — likely no matches in practice:
    ps aux | grep '[c]ompliance' | grep -i python || echo "(No matching processes found — expected in practice mode)"
    print_note "When a pipeline hangs or runs long, 'ps aux | grep' is how you find and investigate it."
}

q26() {
    print_header "Q26: Monitor live file additions"
    echo "Command: tail -f $TXN_FILE"
    echo ""
    echo "(This would block and show new lines as they're appended.)"
    echo "(Press Ctrl+C to stop. Useful for watching live data feeds.)"
    print_note "tail -f is essential for monitoring live pipelines. In production, you'd tail the Airflow task log during a run."
}

q27() {
    print_header "Q27: File health check"
    local filepath="${1:-$TXN_FILE}"

    # Check existence and non-empty
    if [ ! -s "$filepath" ]; then
        echo "FAIL: $filepath does not exist or is empty"
        return 1
    fi

    # Check modification time (last 24 hours = 86400 seconds)
    local mod_time
    if [[ "$(uname)" == "Darwin" ]]; then
        mod_time=$(stat -f %m "$filepath")
    else
        mod_time=$(stat -c %Y "$filepath")
    fi
    local now
    now=$(date +%s)
    local age=$(( now - mod_time ))

    if [ "$age" -gt 86400 ]; then
        echo "FAIL: $filepath was last modified $(( age / 3600 )) hours ago (>24h stale)"
        return 1
    fi

    local lines
    lines=$(wc -l < "$filepath" | tr -d ' ')
    echo "PASS: $filepath exists, $lines lines, modified $(( age / 60 )) minutes ago"
    return 0

    # Interview note: This is a pre-flight check before processing.
    # In Airflow, you'd use a ShortCircuitOperator or a custom sensor
    # to gate downstream tasks on data freshness.
}

q28() {
    print_header "Q28: File checksum"
    if command -v md5sum &>/dev/null; then
        md5sum "$TXN_FILE"
    else
        md5 "$TXN_FILE"  # macOS
    fi
    echo ""
    echo "Why checksums matter in compliance:"
    echo "  - Verify file integrity during transfer (source → staging → production)"
    echo "  - Detect tampering or corruption in settlement files"
    echo "  - Confirm idempotency — re-processing the same file produces the same hash"
    echo "  - Audit trail: log the checksum of every file processed"
    print_note "Checksums are part of the data lineage story. If a regulator asks 'are you sure this is the same file the acquirer sent?', the checksum proves it."
}


# ============================================================
# BONUS: Interview-style compound questions
# ============================================================

q29() {
    print_header "Q29: Settlement file validator"
    local filepath="${1:-$TXN_FILE}"
    local expected_cols=13
    local errors=0

    echo "Validating: $filepath"
    echo "---"

    # Check 1: Expected number of columns
    local actual_cols
    actual_cols=$(head -1 "$filepath" | awk -F',' '{print NF}')
    if [ "$actual_cols" -ne "$expected_cols" ]; then
        echo "FAIL: Expected $expected_cols columns, found $actual_cols"
        errors=$((errors + 1))
    else
        echo "PASS: Column count = $expected_cols"
    fi

    # Check 2: Empty/NULL amounts (column 7 = amount_usd)
    local null_amounts
    null_amounts=$(tail -n +2 "$filepath" | awk -F',' '$7 == "" || $7 == "NULL"' | wc -l | tr -d ' ')
    if [ "$null_amounts" -gt 0 ]; then
        echo "FAIL: $null_amounts rows with NULL/empty amount_usd"
        errors=$((errors + 1))
    else
        echo "PASS: No NULL amounts"
    fi

    # Check 3: Report totals
    local txn_count
    txn_count=$(tail -n +2 "$filepath" | wc -l | tr -d ' ')
    local total_interchange
    total_interchange=$(tail -n +2 "$filepath" | awk -F',' '{sum += $10} END {printf "%.4f", sum}')

    echo "---"
    echo "Transactions: $txn_count"
    echo "Total interchange: \$$total_interchange"

    if [ "$errors" -gt 0 ]; then
        echo "STATUS: FAILED ($errors validation errors)"
        return 1
    else
        echo "STATUS: PASSED"
        return 0
    fi

    # Interview note: This is exactly what a pre-processing validation
    # task looks like. In Airflow, this would be the first task in the
    # DAG — if it fails, downstream tasks don't run, preventing bad
    # data from reaching dashboards.
}

q30() {
    print_header "Q30: Grocery (MCC 5411) interchange rate audit"
    echo "Transactions where effective rate exceeds 1.80% for Grocery:"
    echo ""
    tail -n +2 "$TXN_FILE" | awk -F',' '
        $13 == "5411" && $7 > 0 {
            rate = ($10 / $7) * 100;
            if (rate > 1.80) {
                printf "FLAGGED: %s  amount=$%.2f  ic=$%.4f  rate=%.2f%%\n", $1, $7, $10, rate
            } else {
                printf "    OK:  %s  amount=$%.2f  ic=$%.4f  rate=%.2f%%\n", $1, $7, $10, rate
            }
        }
        $13 == "5411" && $7 == "" {
            printf "  NULL:  %s  amount=MISSING\n", $1
        }'
    print_note "This is a realistic ad-hoc investigation. An acquirer calls and says 'our grocery merchants are being overcharged.' You fire up this one-liner to confirm, then escalate with specific transaction IDs and dollar impact."
}


# ============================================================
# Runner
# ============================================================

all() {
    setup_sample_data
    for i in $(seq 1 30); do
        q${i}
    done
}

if [[ -n "$1" ]]; then
    "$@"
else
    echo "Usage:"
    echo "  bash solutions.sh setup_sample_data   # create test data"
    echo "  bash solutions.sh q1                   # run specific solution"
    echo "  bash solutions.sh all                  # run all solutions"
fi
