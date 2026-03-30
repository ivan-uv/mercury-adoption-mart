"""
Sample Airflow DAG — Interchange Compliance Daily Monitor
Senior Analyst, Global Interchange Compliance

This DAG demonstrates how a daily compliance monitoring pipeline would be
orchestrated in Apache Airflow. It covers the concepts most likely to come
up in a Visa interview:

  - DAG definition with schedule, retries, and SLA
  - Task dependencies (linear + branching)
  - Operator types: PythonOperator, BashOperator, SqlSensor, EmailOperator
  - Idempotent design (date-partitioned, DELETE + INSERT)
  - XCom for passing metadata between tasks
  - Failure callbacks and alerting

This file is a VALID DAG definition — if you have Airflow installed you can
drop it in your dags/ folder and it will parse. The task callables use
placeholder logic since we don't have a real database, but the structure is
production-realistic.

Schema reference: see ../schema.md for table definitions.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator
from airflow.providers.common.sql.sensors.sql import SqlSensor
from airflow.utils.trigger_rule import TriggerRule

# ============================================================
# DAG-level configuration
# ============================================================

default_args = {
    "owner": "interchange_compliance",
    "depends_on_past": False,           # each run is independent
    "email": ["compliance-alerts@visa.com"],
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,                       # retry twice on failure
    "retry_delay": timedelta(minutes=5),
    "execution_timeout": timedelta(hours=2),
    "sla": timedelta(hours=3),          # must complete within 3 hours of scheduled time
}

dag = DAG(
    dag_id="interchange_compliance_daily_monitor",
    default_args=default_args,
    description="Daily interchange compliance checks: data freshness, rate validation, Durbin audit, anomaly detection",
    # Run at 6 AM UTC daily — after overnight settlement batch completes
    schedule="0 6 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,                      # don't backfill missed runs
    max_active_runs=1,                  # only one run at a time
    tags=["compliance", "interchange", "daily"],
)


# ============================================================
# Task callables — each function is one unit of work
# ============================================================

def check_data_freshness(**context):
    """
    Verify that yesterday's settlement data has landed in the warehouse.

    This is a critical gate — if data isn't fresh, all downstream checks
    would run on stale data and produce misleading results.

    In production, this would query an information_schema or metadata table.
    """
    execution_date = context["ds"]  # YYYY-MM-DD string — Airflow's logical date

    # Simulated check — in production:
    # SELECT MAX(settlement_date) FROM transactions WHERE settlement_date = '{{ ds }}'
    latest_date = execution_date  # placeholder
    print(f"Data freshness check for {execution_date}: latest settlement_date = {latest_date}")

    # Push result to XCom so downstream tasks can use it
    context["ti"].xcom_push(key="data_date", value=execution_date)
    context["ti"].xcom_push(key="freshness_status", value="FRESH")
    return True


def validate_interchange_rates(**context):
    """
    Compare actual interchange amounts against expected amounts.
    Flag any transactions where the variance exceeds a threshold.

    Idempotent: deletes any existing results for this date before inserting.

    SQL equivalent:
        DELETE FROM compliance_daily_results WHERE run_date = '{{ ds }}';
        INSERT INTO compliance_daily_results
        SELECT
            transaction_id,
            interchange_amount_usd,
            expected_interchange_usd,
            interchange_amount_usd - expected_interchange_usd AS variance,
            CASE
                WHEN ABS(interchange_amount_usd - expected_interchange_usd) > 0.01
                THEN 'FLAGGED'
                ELSE 'OK'
            END AS status
        FROM transactions
        WHERE settlement_date = '{{ ds }}'
          AND expected_interchange_usd IS NOT NULL;
    """
    data_date = context["ti"].xcom_pull(task_ids="check_data_freshness", key="data_date")
    print(f"Validating interchange rates for {data_date}")

    # Simulated results
    total_transactions = 1_234_567
    flagged_count = 3_201
    total_variance_usd = 48_532.17

    print(f"  Transactions checked: {total_transactions:,}")
    print(f"  Flagged (variance > $0.01): {flagged_count:,}")
    print(f"  Total variance: ${total_variance_usd:,.2f}")

    context["ti"].xcom_push(key="flagged_count", value=flagged_count)
    context["ti"].xcom_push(key="total_variance", value=total_variance_usd)


def audit_durbin_compliance(**context):
    """
    Check that all regulated debit transactions are within the Durbin cap.
    Cap = $0.21 + 0.05% of transaction + $0.01 fraud adjustment.

    Any violation is a regulatory issue requiring immediate escalation.

    SQL equivalent:
        SELECT
            t.transaction_id,
            t.amount_usd,
            t.interchange_amount_usd AS actual_ic,
            (0.21 + t.amount_usd * 0.0005 + 0.01) AS durbin_cap,
            t.interchange_amount_usd - (0.21 + t.amount_usd * 0.0005 + 0.01) AS overage
        FROM transactions t
        JOIN issuers i ON t.issuer_id = i.issuer_id
        WHERE t.settlement_date = '{{ ds }}'
          AND i.is_durbin_regulated = TRUE
          AND t.card_type LIKE '%debit%'
          AND t.interchange_amount_usd > (0.21 + t.amount_usd * 0.0005 + 0.01);
    """
    data_date = context["ti"].xcom_pull(task_ids="check_data_freshness", key="data_date")
    print(f"Auditing Durbin cap compliance for {data_date}")

    # Simulated results
    regulated_debit_count = 456_789
    violations = 0  # should always be 0 — any non-zero is critical

    print(f"  Regulated debit transactions: {regulated_debit_count:,}")
    print(f"  Durbin violations: {violations}")

    context["ti"].xcom_push(key="durbin_violations", value=violations)


def detect_downgrade_anomalies(**context):
    """
    Check if any acquirer's downgrade rate exceeds the alert threshold.

    Normal: 5-10% downgrade rate
    Warning: >15%
    Critical: >25%

    SQL equivalent:
        WITH acquirer_stats AS (
            SELECT
                acquirer_id,
                COUNT(*) AS total_txns,
                AVG(CASE WHEN qualification_status = 'downgraded'
                    THEN 1.0 ELSE 0.0 END) AS downgrade_rate
            FROM transactions
            WHERE settlement_date = '{{ ds }}'
            GROUP BY acquirer_id
        )
        SELECT * FROM acquirer_stats
        WHERE downgrade_rate > 0.15
        ORDER BY downgrade_rate DESC;
    """
    data_date = context["ti"].xcom_pull(task_ids="check_data_freshness", key="data_date")
    print(f"Checking downgrade anomalies for {data_date}")

    # Simulated results
    acquirers_checked = 847
    warning_count = 3
    critical_count = 0

    print(f"  Acquirers checked: {acquirers_checked}")
    print(f"  Warning (>15%): {warning_count}")
    print(f"  Critical (>25%): {critical_count}")

    context["ti"].xcom_push(key="downgrade_warnings", value=warning_count)
    context["ti"].xcom_push(key="downgrade_criticals", value=critical_count)


def check_cedp_qualification(**context):
    """
    Monitor CEDP Product 3 qualification rates for commercial transactions.
    Target: 80%+ qualification rate per acquirer.

    This is the most relevant current initiative — CEDP replaces L2/L3
    interchange incentives. Monitoring is critical during the transition.

    SQL equivalent:
        SELECT
            acquirer_id,
            COUNT(*) AS commercial_txns,
            AVG(CASE WHEN qualification_status = 'qualified'
                THEN 1.0 ELSE 0.0 END) AS cedp_qual_rate
        FROM transactions
        WHERE settlement_date = '{{ ds }}'
          AND card_type IN ('commercial_credit', 'commercial_debit')
        GROUP BY acquirer_id
        HAVING cedp_qual_rate < 0.80;
    """
    data_date = context["ti"].xcom_pull(task_ids="check_data_freshness", key="data_date")
    print(f"Checking CEDP qualification rates for {data_date}")

    # Simulated results
    below_target = 12
    avg_qual_rate = 0.84

    print(f"  Acquirers below 80% target: {below_target}")
    print(f"  Network-wide CEDP qual rate: {avg_qual_rate:.1%}")

    context["ti"].xcom_push(key="cedp_below_target", value=below_target)


def decide_escalation(**context):
    """
    BranchPythonOperator: decide whether to escalate or proceed normally.

    Checks XCom values from upstream tasks to determine severity.
    Returns the task_id of the next task to execute.
    """
    durbin_violations = context["ti"].xcom_pull(
        task_ids="audit_durbin_compliance", key="durbin_violations"
    ) or 0
    downgrade_criticals = context["ti"].xcom_pull(
        task_ids="detect_downgrade_anomalies", key="downgrade_criticals"
    ) or 0
    total_variance = context["ti"].xcom_pull(
        task_ids="validate_interchange_rates", key="total_variance"
    ) or 0

    if durbin_violations > 0 or downgrade_criticals > 0:
        print("CRITICAL issues found — escalating immediately")
        return "escalate_critical"
    elif total_variance > 100_000:
        print(f"High variance (${total_variance:,.2f}) — escalating")
        return "escalate_critical"
    else:
        print("No critical issues — proceeding to summary")
        return "generate_summary"


def generate_compliance_summary(**context):
    """
    Compile all check results into a daily summary for the dashboard.

    In production, this would INSERT into a compliance_daily_summary table
    and refresh the Power BI / Tableau dataset.
    """
    data_date = context["ti"].xcom_pull(task_ids="check_data_freshness", key="data_date")
    flagged = context["ti"].xcom_pull(task_ids="validate_interchange_rates", key="flagged_count") or 0
    variance = context["ti"].xcom_pull(task_ids="validate_interchange_rates", key="total_variance") or 0
    durbin = context["ti"].xcom_pull(task_ids="audit_durbin_compliance", key="durbin_violations") or 0
    downgrades = context["ti"].xcom_pull(task_ids="detect_downgrade_anomalies", key="downgrade_warnings") or 0
    cedp = context["ti"].xcom_pull(task_ids="check_cedp_qualification", key="cedp_below_target") or 0

    summary = {
        "date": data_date,
        "rate_flags": flagged,
        "total_variance_usd": variance,
        "durbin_violations": durbin,
        "downgrade_warnings": downgrades,
        "cedp_below_target": cedp,
        "overall_status": "GREEN" if (durbin == 0 and variance < 50_000) else "YELLOW",
    }

    print(f"Daily Compliance Summary for {data_date}:")
    for k, v in summary.items():
        print(f"  {k}: {v}")

    # In production: INSERT INTO compliance_daily_summary VALUES (...)


# ============================================================
# Task definitions — wiring callables into the DAG
# ============================================================

with dag:

    # --- GATE: Wait for settlement data to be available ---
    # SqlSensor polls a query until it returns a truthy result.
    # This replaces fragile "sleep and hope" patterns.
    wait_for_settlement = SqlSensor(
        task_id="wait_for_settlement_data",
        conn_id="visa_warehouse",       # Airflow Connection (stores credentials securely)
        sql="""
            SELECT COUNT(*) > 0
            FROM transactions
            WHERE settlement_date = '{{ ds }}'
        """,
        mode="poke",                    # check every poke_interval seconds
        poke_interval=300,              # 5 minutes between checks
        timeout=7200,                   # fail after 2 hours of waiting
    )

    # --- TASK 1: Verify data freshness ---
    t_freshness = PythonOperator(
        task_id="check_data_freshness",
        python_callable=check_data_freshness,
    )

    # --- TASK 2-5: Compliance checks (run in parallel) ---
    t_rates = PythonOperator(
        task_id="validate_interchange_rates",
        python_callable=validate_interchange_rates,
    )

    t_durbin = PythonOperator(
        task_id="audit_durbin_compliance",
        python_callable=audit_durbin_compliance,
    )

    t_downgrades = PythonOperator(
        task_id="detect_downgrade_anomalies",
        python_callable=detect_downgrade_anomalies,
    )

    t_cedp = PythonOperator(
        task_id="check_cedp_qualification",
        python_callable=check_cedp_qualification,
    )

    # --- TASK 6: Archive raw data (Bash) ---
    # Demonstrates BashOperator for file-level operations
    t_archive = BashOperator(
        task_id="archive_settlement_file",
        bash_command="""
            DATE={{ ds_nodash }}
            SRC="/data/staging/settlement_${DATE}.csv"
            DST="/data/archive/settlement_${DATE}.csv"

            if [ -f "$SRC" ]; then
                cp "$SRC" "$DST"
                md5sum "$DST" >> /data/archive/checksums.log
                echo "Archived: $DST"
            else
                echo "No file to archive for $DATE"
            fi
        """,
    )

    # --- TASK 7: Branch — escalate or summarize ---
    t_branch = BranchPythonOperator(
        task_id="decide_escalation",
        python_callable=decide_escalation,
    )

    # --- TASK 8a: Critical escalation path ---
    t_escalate = BashOperator(
        task_id="escalate_critical",
        bash_command="""
            echo "CRITICAL COMPLIANCE ALERT for {{ ds }}" | \
            mail -s "[URGENT] Interchange Compliance — Critical Issues Detected" \
                compliance-escalation@visa.com
        """,
    )

    # --- TASK 8b: Normal summary path ---
    t_summary = PythonOperator(
        task_id="generate_summary",
        python_callable=generate_compliance_summary,
    )

    # --- TASK 9: Join point — runs after either escalation or summary ---
    t_done = EmptyOperator(
        task_id="monitoring_complete",
        trigger_rule=TriggerRule.NONE_FAILED_MIN_ONE_SUCCESS,
    )


    # ============================================================
    # DAG dependency graph
    # ============================================================
    #
    #   wait_for_settlement
    #           |
    #     check_data_freshness
    #           |
    #     +-----+-----+-----+-----+
    #     |     |     |     |     |
    #   rates durbin downs  cedp archive
    #     |     |     |     |
    #     +-----+-----+-----+
    #           |
    #     decide_escalation
    #        /        \
    # escalate   generate_summary
    #        \        /
    #     monitoring_complete
    #

    wait_for_settlement >> t_freshness

    t_freshness >> [t_rates, t_durbin, t_downgrades, t_cedp, t_archive]

    [t_rates, t_durbin, t_downgrades, t_cedp] >> t_branch

    t_branch >> [t_escalate, t_summary]

    [t_escalate, t_summary] >> t_done


# ============================================================
# Interview talking points for this DAG
# ============================================================
#
# 1. WHY AIRFLOW OVER CRON?
#    - Task dependencies: freshness check MUST pass before rate validation
#    - Parallel execution: four compliance checks run simultaneously
#    - Branching: escalation path chosen dynamically based on results
#    - Retries: if the DB is briefly unavailable, tasks retry automatically
#    - Monitoring: Airflow UI shows task status, duration, logs — no grepping
#    - Backfill: can re-run for a past date without modifying the code
#
# 2. IDEMPOTENCY
#    - Every task uses {{ ds }} (the logical execution date), not datetime.now()
#    - Rate validation DELETEs existing results before INSERTing
#    - Re-running a failed date produces the same output as a first run
#    - This is critical for compliance: results must be reproducible
#
# 3. DATA QUALITY GATES
#    - SqlSensor blocks until data is actually available
#    - Freshness check validates before downstream tasks run
#    - This prevents "dashboard showed green but data was 2 days stale"
#
# 4. XCOMS
#    - Small metadata (counts, flags, dates) passed between tasks
#    - NOT used for large datasets — that goes through the warehouse
#    - Enables the BranchPythonOperator to make routing decisions
#
# 5. ALERTING
#    - email_on_failure in default_args catches unexpected crashes
#    - BranchPythonOperator escalates known-bad conditions
#    - SLA (3 hours) catches silent hangs — if the DAG doesn't finish, alert
#
# 6. CONNECTIONS & SECURITY
#    - conn_id="visa_warehouse" — credentials stored in Airflow, not in code
#    - No hardcoded passwords, hostnames, or API keys
#    - Audit trail: Airflow logs who ran what, when, with what parameters
#
# 7. WHAT I'D ADD IN PRODUCTION
#    - Slack/PagerDuty integration for critical alerts (not just email)
#    - Partition-level data quality checks (row counts, NULL rates, distributions)
#    - Downstream Tableau/Power BI extract refresh trigger
#    - Weekly summary DAG that aggregates daily results for trend analysis
#    - Separate DAGs for CEDP transition monitoring and Durbin audit deep-dives
