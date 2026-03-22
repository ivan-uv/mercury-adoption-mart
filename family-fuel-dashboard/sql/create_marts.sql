-- ============================================================
-- Mart views — pre-aggregated for the Streamlit dashboard
-- Run after transform_facts.sql
-- ============================================================

-- ── mart_weekly_plans ──────────────────────────────────────────
-- One row per meal slot across the most recent generated week plan.
-- Dashboard uses this for the 3×7 meal grid.
CREATE OR REPLACE VIEW mart_weekly_plans AS
WITH latest_plan AS (
    SELECT plan_id
    FROM fact_meal_plans
    ORDER BY date_generated DESC, plan_id DESC
    LIMIT 1
)
SELECT
    fmp.plan_id,
    fmp.date_generated,
    fmp.day_of_week,
    fmp.meal_slot,
    fmp.target_calories,
    dr.recipe_id,
    dr.title,
    dr.cuisine,
    dr.ready_minutes,
    dr.servings,
    dr.diet_tags,
    dr.kid_friendly,
    dr.image_url,
    dr.source_url,
    -- Inline calorie count for the grid display
    COALESCE(nut.amount_per_serving, 0) AS calories_per_serving
FROM fact_meal_plans fmp
JOIN latest_plan lp USING (plan_id)
JOIN dim_recipes dr USING (recipe_id)
LEFT JOIN fact_recipe_nutrition nut
    ON dr.recipe_id = nut.recipe_id AND nut.nutrient_id = 1  -- 1 = Calories
ORDER BY fmp.day_of_week, fmp.meal_slot;


-- ── mart_kid_friendly ──────────────────────────────────────────
-- Recipes suitable for young kids: quick, unambiguously friendly.
CREATE OR REPLACE VIEW mart_kid_friendly AS
SELECT
    dr.recipe_id,
    dr.title,
    dr.cuisine,
    dr.ready_minutes,
    dr.servings,
    dr.diet_tags,
    dr.allergens,
    dr.image_url,
    dr.source_url,
    COALESCE(cal.amount_per_serving, 0) AS calories_per_serving,
    COALESCE(prot.amount_per_serving, 0) AS protein_g,
    COALESCE(fat.amount_per_serving, 0) AS fat_g,
    COALESCE(carb.amount_per_serving, 0) AS carbs_g
FROM dim_recipes dr
LEFT JOIN fact_recipe_nutrition cal  ON dr.recipe_id = cal.recipe_id  AND cal.nutrient_id  = 1
LEFT JOIN fact_recipe_nutrition prot ON dr.recipe_id = prot.recipe_id AND prot.nutrient_id = 2
LEFT JOIN fact_recipe_nutrition fat  ON dr.recipe_id = fat.recipe_id  AND fat.nutrient_id  = 3
LEFT JOIN fact_recipe_nutrition carb ON dr.recipe_id = carb.recipe_id AND carb.nutrient_id = 4
WHERE dr.ready_minutes <= 30
  AND dr.kid_friendly = true;


-- ── mart_macro_summary ──────────────────────────────────────────
-- Daily macro totals for the active week plan.
CREATE OR REPLACE VIEW mart_macro_summary AS
WITH latest_plan AS (
    SELECT plan_id FROM fact_meal_plans ORDER BY date_generated DESC, plan_id DESC LIMIT 1
)
SELECT
    fmp.day_of_week,
    SUM(CASE WHEN frn.nutrient_id = 1 THEN frn.amount_per_serving ELSE 0 END) AS total_calories,
    SUM(CASE WHEN frn.nutrient_id = 2 THEN frn.amount_per_serving ELSE 0 END) AS total_protein_g,
    SUM(CASE WHEN frn.nutrient_id = 3 THEN frn.amount_per_serving ELSE 0 END) AS total_fat_g,
    SUM(CASE WHEN frn.nutrient_id = 4 THEN frn.amount_per_serving ELSE 0 END) AS total_carbs_g,
    SUM(CASE WHEN frn.nutrient_id = 5 THEN frn.amount_per_serving ELSE 0 END) AS total_fiber_g,
    ANY_VALUE(fmp.target_calories)                                             AS target_calories
FROM fact_meal_plans fmp
JOIN latest_plan lp USING (plan_id)
LEFT JOIN fact_recipe_nutrition frn USING (recipe_id)
GROUP BY fmp.day_of_week
ORDER BY fmp.day_of_week;


-- ── mart_grocery_list ──────────────────────────────────────────
-- Aggregated ingredient shopping list for the active week plan.
-- Normalizes common volume/weight units before aggregating.
CREATE OR REPLACE VIEW mart_grocery_list AS
WITH latest_plan AS (
    SELECT plan_id FROM fact_meal_plans ORDER BY date_generated DESC, plan_id DESC LIMIT 1
),
normalized AS (
    SELECT
        di.aisle,
        di.name AS ingredient,
        di.ingredient_id,
        CASE
            WHEN lower(fri.unit) IN ('cup', 'cups')                                                    THEN fri.quantity * 16.0
            WHEN lower(fri.unit) IN ('tablespoon', 'tablespoons', 'tbsp', 'tbsps')                     THEN fri.quantity
            WHEN lower(fri.unit) IN ('teaspoon', 'teaspoons', 'tsp', 'tsps')                           THEN fri.quantity / 3.0
            WHEN lower(fri.unit) IN ('kg', 'kilogram', 'kilograms')                                    THEN fri.quantity * 1000.0
            WHEN lower(fri.unit) IN ('lb', 'lbs', 'pound', 'pounds')                                   THEN fri.quantity * 453.6
            WHEN lower(fri.unit) IN ('oz', 'ounce', 'ounces')                                          THEN fri.quantity * 28.35
            ELSE fri.quantity
        END AS normalized_qty,
        CASE
            WHEN lower(fri.unit) IN ('cup', 'cups', 'tablespoon', 'tablespoons', 'tbsp', 'tbsps',
                                      'teaspoon', 'teaspoons', 'tsp', 'tsps')                          THEN 'tbsp'
            WHEN lower(fri.unit) IN ('kg', 'kilogram', 'kilograms', 'lb', 'lbs', 'pound', 'pounds',
                                      'oz', 'ounce', 'ounces', 'g', 'gram', 'grams')                   THEN 'g'
            ELSE fri.unit
        END AS base_unit
    FROM fact_meal_plans fmp
    JOIN latest_plan lp USING (plan_id)
    JOIN fact_recipe_ingredients fri USING (recipe_id)
    JOIN dim_ingredients di USING (ingredient_id)
)
SELECT
    aisle,
    ingredient,
    CASE
        WHEN base_unit = 'tbsp' AND SUM(normalized_qty) >= 16
            THEN ROUND(SUM(normalized_qty) / 16.0, 2)
        WHEN base_unit = 'g' AND SUM(normalized_qty) >= 1000
            THEN ROUND(SUM(normalized_qty) / 1000.0, 2)
        ELSE ROUND(SUM(normalized_qty), 2)
    END AS total_quantity,
    CASE
        WHEN base_unit = 'tbsp' AND SUM(normalized_qty) >= 16 THEN 'cups'
        WHEN base_unit = 'tbsp' THEN 'tbsp'
        WHEN base_unit = 'g' AND SUM(normalized_qty) >= 1000 THEN 'kg'
        WHEN base_unit = 'g' THEN 'g'
        ELSE base_unit
    END AS unit,
    ingredient_id
FROM normalized
GROUP BY aisle, ingredient, base_unit, ingredient_id
ORDER BY aisle, ingredient;
