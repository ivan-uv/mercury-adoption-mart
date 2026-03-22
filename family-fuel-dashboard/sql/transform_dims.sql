-- ============================================================
-- Populate dimension tables from raw JSON
-- Run after each extract cycle
-- ============================================================

-- ── dim_recipes ──────────────────────────────────────────────
INSERT OR REPLACE INTO dim_recipes
SELECT
    rr.recipe_id,
    rr.title,
    rr.raw_json->>'$.cuisines[0]'                                       AS cuisine,
    CAST(rr.raw_json->>'$.readyInMinutes' AS INTEGER)                   AS ready_minutes,
    CAST(rr.raw_json->>'$.cookingMinutes' AS INTEGER)                   AS cook_minutes,
    CAST(rr.raw_json->>'$.servings' AS INTEGER)                         AS servings,
    -- Build diet_tags array from boolean flags
    list_filter([
        CASE WHEN rr.raw_json->>'$.vegetarian' = 'true' THEN 'vegetarian' END,
        CASE WHEN rr.raw_json->>'$.vegan'      = 'true' THEN 'vegan'      END,
        CASE WHEN rr.raw_json->>'$.glutenFree' = 'true' THEN 'gluten-free' END,
        CASE WHEN rr.raw_json->>'$.dairyFree'  = 'true' THEN 'dairy-free' END,
        CASE WHEN rr.raw_json->>'$.veryHealthy' = 'true' THEN 'healthy'   END
    ], x -> x IS NOT NULL)                                              AS diet_tags,
    COALESCE(sa.allergens, []::VARCHAR[])                               AS allergens,
    -- Kid-friendly: ready in ≤30 min and either popular or has no common kid allergens
    CASE
        WHEN CAST(rr.raw_json->>'$.readyInMinutes' AS INTEGER) <= 30
         AND (rr.raw_json->>'$.veryPopular' = 'true'
              OR CAST(rr.raw_json->>'$.aggregateLikes' AS INTEGER) > 20)
        THEN true
        ELSE false
    END                                                                 AS kid_friendly,
    rr.raw_json->>'$.image'                                             AS image_url,
    rr.raw_json->>'$.sourceUrl'                                         AS source_url,
    current_timestamp                                                   AS updated_at
FROM raw_recipes rr
LEFT JOIN staging_allergens sa ON rr.recipe_id = sa.recipe_id;

-- ── dim_ingredients ───────────────────────────────────────────
-- Flatten ingredients from Spoonacular's extendedIngredients array
-- This requires the ingredients to be pre-exploded into a staging table by transform.py
INSERT OR REPLACE INTO dim_ingredients
SELECT DISTINCT
    si.ingredient_id,
    si.name,
    si.aisle,
    usda.fdc_id AS usda_fdc_id,
    off_p.barcode AS off_barcode,
    current_timestamp AS updated_at
FROM staging_ingredients si
LEFT JOIN raw_usda_nutrients usda
    ON lower(usda.description) = lower(si.name)
LEFT JOIN raw_off_products off_p
    ON lower(off_p.product_name) = lower(si.name)
WHERE si.ingredient_id NOT IN (SELECT ingredient_id FROM dim_ingredients);
