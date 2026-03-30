#!/usr/bin/env bash
# ============================================================
# Visa Bash Practice — Questions
# Senior Analyst, Global Interchange Compliance
#
# Work through each exercise below. All problems use interchange
# compliance scenarios matching the Visa schema and role context.
#
# Run solutions.sh to compare your output.
#
# Topics:
# 1. File inspection & navigation — CSV profiling, head/tail/wc
# 2. Text processing — grep, awk, sed, cut, sort, uniq
# 3. Piping & one-liners — chained commands for quick analysis
# 4. Loops & conditionals — batch file processing
# 5. Cron & scheduling — automating compliance checks
# 6. Process management & system — real-world ops tasks
# ============================================================


# ------------------------------------------------------------
# SAMPLE DATA SETUP
# Run this block first to create the sample CSVs used below.
# In a real interview you'd be given files; this just bootstraps them.
# ------------------------------------------------------------

setup_sample_data() {
    mkdir -p /tmp/visa_bash_practice/daily

    # transactions.csv — 20 sample rows
    cat > /tmp/visa_bash_practice/transactions.csv << 'CSVEOF'
transaction_id,card_number_hash,issuer_id,acquirer_id,merchant_id,transaction_date,amount_usd,card_type,entry_mode,interchange_amount_usd,expected_interchange_usd,qualification_status,mcc
TXN001,hash_a1,ISS001,ACQ001,MER001,2026-03-15 10:23:45,52.30,consumer_credit,chip,0.8600,0.8600,qualified,5411
TXN002,hash_b2,ISS002,ACQ001,MER002,2026-03-15 10:24:12,125.00,consumer_credit,ecommerce,2.1625,2.1625,qualified,5812
TXN003,hash_c3,ISS001,ACQ002,MER003,2026-03-15 10:30:00,40.00,consumer_debit,chip,0.2200,0.2200,qualified,5411
TXN004,hash_d4,ISS003,ACQ001,MER004,2026-03-15 10:31:10,200.00,commercial_credit,keyed,5.3000,4.1000,downgraded,5999
TXN005,hash_e5,ISS002,ACQ002,MER005,2026-03-15 10:45:00,15.75,consumer_debit,contactless,0.2200,0.2200,qualified,5541
TXN006,hash_f6,ISS004,ACQ003,MER006,2026-03-15 11:00:00,89.99,consumer_credit,ecommerce,1.5748,1.4849,downgraded,5691
TXN007,hash_g7,ISS001,ACQ001,MER001,2026-03-15 11:15:00,52.30,consumer_credit,chip,0.8600,0.8600,qualified,5411
TXN008,hash_a1,ISS001,ACQ001,MER001,2026-03-15 10:25:00,52.30,consumer_credit,chip,0.8600,0.8600,qualified,5411
TXN009,hash_h8,ISS005,ACQ002,MER007,2026-03-15 12:00:00,500.00,commercial_credit,ecommerce,12.6000,10.2500,downgraded,7011
TXN010,hash_i9,ISS002,ACQ003,MER008,2026-03-15 12:30:00,,consumer_credit,chip,0.0000,0.0000,standard,5411
TXN011,hash_j1,ISS003,ACQ001,MER009,2026-03-15 13:00:00,75.00,consumer_credit,swipe,1.3125,1.2375,downgraded,5812
TXN012,hash_k2,ISS004,ACQ002,MER010,2026-03-15 13:15:00,30.00,consumer_debit,chip,0.2200,0.2200,qualified,5912
TXN013,hash_l3,ISS001,ACQ003,MER003,2026-03-15 14:00:00,60.00,consumer_debit,contactless,0.2200,0.2200,qualified,5411
TXN014,hash_m4,ISS002,ACQ001,MER011,2026-03-15 14:30:00,1250.00,commercial_credit,keyed,31.3750,25.6250,downgraded,5999
TXN015,hash_n5,ISS005,ACQ002,MER012,2026-03-15 15:00:00,22.50,consumer_credit,contactless,0.3713,0.3713,qualified,5814
TXN016,hash_o6,ISS003,ACQ003,MER006,2026-03-15 15:30:00,89.99,consumer_credit,ecommerce,1.5748,1.4849,downgraded,5691
TXN017,hash_p7,ISS001,ACQ001,MER013,2026-03-15 16:00:00,150.00,consumer_credit,chip,2.4750,2.4750,qualified,5311
TXN018,hash_q8,ISS004,ACQ002,MER014,2026-03-15 16:30:00,45.00,prepaid,swipe,0.7425,0.5175,downgraded,5411
TXN019,hash_r9,ISS002,ACQ003,MER015,2026-03-15 17:00:00,320.00,consumer_credit,ecommerce,5.2800,5.2800,qualified,5944
TXN020,hash_s1,ISS005,ACQ001,MER016,2026-03-15 17:30:00,18.00,consumer_debit,chip,0.2200,0.2200,qualified,5411
CSVEOF

    # compliance_alerts.log — simulated log file
    cat > /tmp/visa_bash_practice/compliance_alerts.log << 'LOGEOF'
2026-03-15 06:00:01 INFO  DailyRefresh started for date=2026-03-14
2026-03-15 06:02:14 INFO  Loaded 1,234,567 transactions from staging
2026-03-15 06:02:15 WARN  NULL amount_usd detected in 42 rows — issuer ISS003
2026-03-15 06:03:00 INFO  Interchange variance check started
2026-03-15 06:03:45 ERROR Rate mismatch detected: ACQ002 MCC=5411 expected_rate=1.65% actual=2.15% txn_count=3201
2026-03-15 06:03:46 ERROR Rate mismatch detected: ACQ003 MCC=5691 expected_rate=1.65% actual=1.75% txn_count=890
2026-03-15 06:04:00 WARN  Downgrade rate exceeded threshold: ACQ001 downgrade_pct=18.3% threshold=15%
2026-03-15 06:04:30 INFO  Durbin cap check started
2026-03-15 06:04:45 ERROR Durbin violation: ISS004 debit_interchange=$0.28 cap=$0.22 txn_count=156
2026-03-15 06:05:00 INFO  CEDP qualification check started
2026-03-15 06:05:30 WARN  CEDP Product 3 qualification below target: ACQ002 qual_rate=62% target=80%
2026-03-15 06:06:00 INFO  DailyRefresh completed. Duration: 359s. Errors: 3, Warnings: 3
LOGEOF

    # Multiple daily CSVs for batch processing exercises
    for day in 01 02 03; do
        cat > /tmp/visa_bash_practice/daily/interchange_2026-03-${day}.csv << DAYEOF
transaction_id,amount_usd,interchange_amount_usd,qualification_status
TXN${day}01,100.00,1.65,qualified
TXN${day}02,50.00,0.83,qualified
TXN${day}03,200.00,4.30,downgraded
TXN${day}04,75.00,1.24,qualified
TXN${day}05,30.00,0.72,downgraded
DAYEOF
    done

    # merchants.csv
    cat > /tmp/visa_bash_practice/merchants.csv << 'MEREOF'
merchant_id,merchant_name,mcc,mcc_description,acquirer_id,is_high_risk
MER001,Fresh Mart #112,5411,Grocery Stores,ACQ001,false
MER002,Bella Italia,5812,Eating Places,ACQ001,false
MER003,QuickStop Gas,5541,Service Stations,ACQ002,false
MER004,TechSupply Corp,5999,Miscellaneous Retail,ACQ001,false
MER005,Corner Fuel,5541,Service Stations,ACQ002,false
MER006,ShopOnline Direct,5691,Clothing Stores,ACQ003,false
MER007,Grand Hotel,7011,Hotels and Motels,ACQ002,true
MER008,Fresh Mart #245,5411,Grocery Stores,ACQ003,false
MER009,Taco Fiesta,5812,Eating Places,ACQ001,false
MER010,CityFit Gym,5912,Drug Stores,ACQ002,false
MER011,GlobalParts Inc,5999,Miscellaneous Retail,ACQ001,true
MER012,Coffee Corner,5814,Fast Food,ACQ002,false
MER013,BestBuy Electronics,5311,Department Stores,ACQ001,false
MER014,Fresh Mart #087,5411,Grocery Stores,ACQ002,false
MER015,GameZone Online,5944,Game Stores,ACQ003,false
MER016,QuickMart,5411,Grocery Stores,ACQ001,false
MEREOF

    echo "Sample data created in /tmp/visa_bash_practice/"
}


# ============================================================
# 1. FILE INSPECTION & NAVIGATION
# ============================================================

# Q1: How many transactions are in the file? (exclude the header)
# Expected output: a single number (20)
# Hint: wc -l counts lines; subtract 1 for the header, or use tail +2
q1_count_transactions() {
    # Your command here:
    :
}


# Q2: Print just the header row of transactions.csv to see column names.
# Hint: head
q2_show_header() {
    :
}


# Q3: Display the last 5 transactions in the file.
# Hint: tail
q3_last_five() {
    :
}


# Q4: How large is the transactions file in bytes? Print file size only.
# Hint: wc -c, or stat, or ls -l with awk
q4_file_size() {
    :
}


# Q5: Print the unique card_type values from transactions.csv (column 8).
# Expected: commercial_credit, consumer_credit, consumer_debit, prepaid
# Hint: cut + sort + uniq, or awk
q5_unique_card_types() {
    :
}


# ============================================================
# 2. TEXT PROCESSING — grep, awk, sed, cut, sort, uniq
# ============================================================

# Q6: Count how many downgraded transactions are in the file.
# Expected output: a number (6)
# Hint: grep -c
q6_count_downgrades() {
    :
}


# Q7: Extract all transactions for acquirer ACQ001 and print just
#     transaction_id and amount_usd (columns 1 and 7).
# Hint: grep + cut, or awk
q7_acquirer_transactions() {
    :
}


# Q8: Find all transactions where interchange_amount_usd differs from
#     expected_interchange_usd (i.e., there's an interchange variance).
#     Print transaction_id, actual interchange, and expected interchange.
# Hint: awk with field comparison (-F',')
q8_interchange_variance() {
    :
}


# Q9: Which MCC code has the most transactions? Print "mcc count" sorted
#     descending by count.
# Hint: tail +2 | cut | sort | uniq -c | sort -rn
q9_top_mcc() {
    :
}


# Q10: From compliance_alerts.log, extract all ERROR lines and print
#      just the timestamp and the message (everything after ERROR).
# Hint: grep "ERROR" + sed or awk
q10_error_lines() {
    :
}


# ============================================================
# 3. PIPING & ONE-LINERS — chained commands for quick analysis
# ============================================================

# Q11: Calculate the total interchange amount across all transactions.
#      Print a single dollar amount (sum of column 10).
# Hint: tail +2 | awk -F',' '{sum += $10} END {printf "%.4f\n", sum}'
q11_total_interchange() {
    :
}


# Q12: Find potential duplicate transactions — same card_number_hash,
#      same merchant_id, same amount, within the file. Print duplicates.
# Hint: Create a key from cols 2,5,7, then sort | uniq -d
q12_find_duplicates() {
    :
}


# Q13: Join transactions.csv and merchants.csv on merchant_id to print:
#      transaction_id, merchant_name, amount_usd, qualification_status
#      (Only for MCC 5411 — Grocery)
# Hint: awk with arrays, or use join after sorting both files
q13_join_merchant_data() {
    :
}


# Q14: From the log file, count occurrences of each log level
#      (INFO, WARN, ERROR). Print "count level" sorted descending.
# Hint: awk '{print $3}' | sort | uniq -c | sort -rn
q14_log_level_counts() {
    :
}


# Q15: Find the top 3 merchants by total transaction volume (sum of
#      amount_usd). Print "total_amount merchant_id".
# Hint: tail +2 | awk to accumulate by merchant_id, then sort
q15_top_merchants_by_volume() {
    :
}


# ============================================================
# 4. LOOPS & CONDITIONALS — batch file processing
# ============================================================

# Q16: Loop through all daily CSV files in /tmp/visa_bash_practice/daily/
#      and print "filename: N transactions" for each (excluding header).
q16_count_daily_files() {
    :
}


# Q17: Loop through the daily CSVs. For each file, calculate and print
#      the downgrade rate (% of transactions with status "downgraded").
#      Format: "filename: XX.X% downgrade rate"
q17_daily_downgrade_rates() {
    :
}


# Q18: Write a command that checks if any daily file has a downgrade
#      rate above 30%. If so, print a warning with the filename.
#      This simulates a pre-Airflow style compliance check.
q18_downgrade_alert() {
    :
}


# Q19: Combine (concatenate) all daily CSVs into one file, keeping only
#      one header row. Save to /tmp/visa_bash_practice/combined.csv
# Hint: head -1 for first file's header, then tail +2 for all files
q19_combine_daily_files() {
    :
}


# Q20: For each unique acquirer_id in transactions.csv, create a
#      separate CSV file: /tmp/visa_bash_practice/acq_<acquirer_id>.csv
#      with the header + that acquirer's transactions.
q20_split_by_acquirer() {
    :
}


# ============================================================
# 5. CRON & SCHEDULING
# ============================================================

# Q21: Write the crontab entry that would run a daily compliance check
#      at 6:00 AM UTC, logging output to /var/log/compliance_daily.log.
#      (Just echo the crontab line — don't actually install it.)
# Hint: minute hour day month weekday command
q21_cron_daily() {
    :
}


# Q22: Write the crontab entry for a rate-change validation that runs
#      twice a year on April 1 and October 1 at midnight.
#      (echo the line)
q22_cron_rate_change() {
    :
}


# Q23: Write the crontab entry for a weekly Durbin cap audit that runs
#      every Monday at 7:00 AM, emails output to compliance@visa.com.
#      (echo the line)
q23_cron_weekly_durbin() {
    :
}


# Q24: Explain in a comment: What does 2>&1 mean in a cron command?
#      What's the difference between > and >> for log files?
#      Why is the full path to python important in cron?
q24_cron_concepts() {
    # Answer here as comments:
    # 2>&1:
    # > vs >>:
    # Full path:
    :
}


# ============================================================
# 6. PROCESS MANAGEMENT & SYSTEM
# ============================================================

# Q25: Write a command to find all Python processes currently running
#      that contain "compliance" in their command line.
# Hint: ps aux | grep
q25_find_processes() {
    :
}


# Q26: Write a one-liner that monitors the transactions.csv file for
#      new lines being appended (simulating a live feed).
# Hint: tail -f
q26_tail_live() {
    :
}


# Q27: Create a simple health check script that:
#      a) Checks if a file exists and is non-empty
#      b) Checks if the file was modified in the last 24 hours
#      c) Prints PASS or FAIL with a message
#      (Write as a function taking a filepath argument)
q27_health_check() {
    local filepath="$1"
    # Your implementation here:
    :
}


# Q28: Write a command to compute an MD5 checksum of transactions.csv.
#      Why would checksums matter in a compliance data pipeline?
# Hint: md5sum or md5 (macOS)
q28_checksum() {
    :
}


# ============================================================
# BONUS: Interview-style compound questions
# ============================================================

# Q29: "You receive a daily settlement file. Write a Bash pipeline
#       that validates the file has the expected number of columns,
#       checks for any NULL/empty amounts, and reports the total
#       interchange and transaction count. If validation fails,
#       exit with a non-zero status."
q29_settlement_validator() {
    local filepath="${1:-/tmp/visa_bash_practice/transactions.csv}"
    # Your implementation here:
    :
}


# Q30: "An acquirer reports they were overcharged on interchange for
#       MCC 5411 (Grocery). Write a Bash one-liner to extract all
#       MCC 5411 transactions, compute the average interchange rate
#       (interchange_amount / amount), and flag any where the rate
#       exceeds 1.80% (the expected grocery rate)."
q30_grocery_rate_audit() {
    :
}


# ============================================================
# Run setup and execute any function by name:
#   bash questions.sh setup_sample_data
#   bash questions.sh q1_count_transactions
# ============================================================
# Guard: only run if executed directly (not when sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" && -n "$1" ]]; then
    "$@"
fi
