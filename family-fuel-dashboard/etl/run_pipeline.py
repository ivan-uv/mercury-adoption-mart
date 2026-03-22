"""
Main ETL orchestrator — run daily via cron or scheduler.py.

Usage:
    python etl/run_pipeline.py

Environment variables (set via .env):
    SPOONACULAR_KEY   — Spoonacular API key
    USDA_KEY          — USDA FoodData Central API key
    DUCKDB_PATH       — Optional: override DB path
"""
import logging
import sys
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

# Ensure project root is on the path
sys.path.insert(0, str(Path(__file__).parent.parent))

from etl.extract_spoonacular import fetch_recipes
from etl.extract_usda import fetch_usda_nutrients
from etl.extract_open_food_facts import fetch_off_products
from etl.transform import transform_recipes, transform_usda, transform_off
from etl.load import (
    get_connection,
    initialize_schema,
    upsert_raw_recipes,
    upsert_raw_usda,
    upsert_raw_off_products,
    log_pipeline_run,
    create_staging_tables,
    load_staging_ingredients,
    load_staging_nutrition,
    load_staging_recipe_ingredients,
    load_staging_allergens,
    run_sql_transforms,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(Path(__file__).parent.parent / "logs" / "etl.log"),
    ],
)
log = logging.getLogger(__name__)


def run_pipeline() -> None:
    log.info("═" * 60)
    log.info("Pipeline run started")

    con = get_connection()
    initialize_schema(con)
    create_staging_tables(con)

    # ── 1. Spoonacular ──────────────────────────────────────
    try:
        # Fetch only recipes not already in the DB
        existing_ids: set[int] = {
            row[0] for row in con.execute("SELECT recipe_id FROM raw_recipes").fetchall()
        }
        log.info(f"Spoonacular: {len(existing_ids)} recipes already cached")

        raw_recipes = fetch_recipes(exclude_ids=existing_ids)
        rows = upsert_raw_recipes(con, raw_recipes)
        log.info(f"Spoonacular: loaded {rows} new recipes")

        # Transform into staging tables
        ing_df, nut_df, ri_df, allergens_df = transform_recipes(raw_recipes)
        load_staging_ingredients(con, ing_df)
        load_staging_nutrition(con, nut_df)
        load_staging_recipe_ingredients(con, ri_df)
        load_staging_allergens(con, allergens_df)

        log_pipeline_run(con, "spoonacular", "success", rows)
    except Exception as exc:
        log.error(f"Spoonacular extract failed: {exc}")
        log_pipeline_run(con, "spoonacular", "error", 0, str(exc))

    # ── 2. USDA FoodData Central ────────────────────────────
    try:
        # Only look up ingredients that don't have a usda_fdc_id yet
        missing = con.execute("""
            SELECT DISTINCT name FROM staging_ingredients
            WHERE name NOT IN (SELECT description FROM raw_usda_nutrients)
            LIMIT 50
        """).fetchall()
        ingredient_names = [r[0] for r in missing]

        if ingredient_names:
            raw_usda = fetch_usda_nutrients(ingredient_names)
            rows = upsert_raw_usda(con, raw_usda)
            log.info(f"USDA: loaded {rows} nutrient records")
            log_pipeline_run(con, "usda", "success", rows)
        else:
            log.info("USDA: no new ingredients to look up")
            log_pipeline_run(con, "usda", "success", 0)
    except Exception as exc:
        log.error(f"USDA extract failed: {exc}")
        log_pipeline_run(con, "usda", "error", 0, str(exc))

    # ── 3. Open Food Facts ──────────────────────────────────
    try:
        raw_off = fetch_off_products(categories=["breakfast cereals", "snacks", "beverages"])
        rows = upsert_raw_off_products(con, raw_off)
        log.info(f"Open Food Facts: loaded {rows} product records")
        log_pipeline_run(con, "open_food_facts", "success", rows)
    except Exception as exc:
        log.error(f"Open Food Facts extract failed: {exc}")
        log_pipeline_run(con, "open_food_facts", "error", 0, str(exc))

    # ── 4. SQL transforms (must run before meal plan gen to populate dim_recipes)
    try:
        run_sql_transforms(con)
        log.info("SQL transforms completed")
    except Exception as exc:
        log.error(f"SQL transforms failed: {exc}")

    # ── 5. Meal plan generation ───────────────────────────────
    try:
        import uuid, datetime
        import pandas as pd

        # Calorie targets per meal slot
        SLOT_CALORIES = {"breakfast": 500, "lunch": 650, "dinner": 750}

        # Fetch recipes with their calorie counts, ensuring 21 unique recipes
        recipes = con.execute("""
            SELECT dr.recipe_id,
                   COALESCE(frn.amount_per_serving, 0) AS calories
            FROM dim_recipes dr
            LEFT JOIN fact_recipe_nutrition frn
                ON dr.recipe_id = frn.recipe_id AND frn.nutrient_id = 1
            ORDER BY random()
        """).fetchall()

        if len(recipes) >= 21:
            plan_id = str(uuid.uuid4())
            today = datetime.date.today()
            slots = ["breakfast", "lunch", "dinner"]
            rows_mp = []
            used_ids: set[int] = set()

            for day in range(1, 8):
                for slot in slots:
                    target = SLOT_CALORIES[slot]
                    # Pick the closest-calorie unused recipe
                    best = None
                    best_diff = float("inf")
                    for rid, cal in recipes:
                        if rid in used_ids:
                            continue
                        diff = abs(cal - target)
                        if diff < best_diff:
                            best = rid
                            best_diff = diff
                    if best is not None:
                        used_ids.add(best)
                        rows_mp.append({
                            "plan_id": plan_id,
                            "date_generated": today,
                            "day_of_week": day,
                            "meal_slot": slot,
                            "recipe_id": best,
                            "target_calories": target,
                        })

            if len(rows_mp) == 21:
                df = pd.DataFrame(rows_mp)
                con.execute("INSERT OR REPLACE INTO fact_meal_plans SELECT * FROM df")
                log.info(f"Meal plan generated: plan_id={plan_id}")
            else:
                log.info("Not enough unique recipes to generate a full weekly plan")
        else:
            log.info("Not enough recipes yet to generate a full weekly plan")
    except Exception as exc:
        log.error(f"Meal plan generation failed: {exc}")

    con.close()
    log.info("Pipeline run complete")
    log.info("═" * 60)


if __name__ == "__main__":
    run_pipeline()
