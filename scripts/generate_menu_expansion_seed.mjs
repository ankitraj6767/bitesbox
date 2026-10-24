import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const source = resolve(root, "supabase/seeds/menu_expansion_products.tsv");
const output = resolve(root, "supabase/seeds/22_menu_expansion.sql");
const lines = readFileSync(source, "utf8").trim().split(/\r?\n/);
const [header, ...records] = lines;
const keys = header.split("|");
const categoryIds = [
  null,
  "33333333-0000-0000-0000-000000000001",
  "33333333-0000-0000-0000-000000000002",
  "33333333-0000-0000-0000-000000000003",
  "33333333-0000-0000-0000-000000000004",
  "33333333-0000-0000-0000-000000000005",
  "33333333-0000-0000-0000-000000000006",
  "33333333-0000-0000-0000-000000000007",
  "33333333-0000-0000-0000-000000000008",
  "33333333-0000-0000-0000-000000000009",
  "33333333-0000-0000-0000-00000000000a",
  "33333333-0000-0000-0000-00000000000b",
  "33333333-0000-0000-0000-00000000000c",
];

const quote = (value) => `'${String(value).replaceAll("'", "''")}'`;
const searchStopWords = new Set([
  "a",
  "and",
  "for",
  "in",
  "of",
  "the",
  "to",
  "with",
]);
const textArray = (value) => {
  const values = value === "none" || !value ? [] : value.split(",");
  return `array[${values.map(quote).join(", ")}]::text[]`;
};
const products = records.map((line, index) => {
  const row = Object.fromEntries(
    keys.map((key, column) => [key, line.split("|")[column]]),
  );
  const number = String(index + 1).padStart(12, "0");
  const id = `77777777-0000-0000-0000-${number}`;
  const image = `menu-images/products/expansion/${row.slug}.jpg`;
  const categoryId = categoryIds[Number(row.category)];
  const categoryName = [
    "Biryani",
    "Chicken",
    "Mutton",
    "Rolls & Wraps",
    "Chinese",
    "Starters",
    "Rice & Curries",
    "Breads",
    "Beverages",
    "Desserts",
    "Combos & Meals",
    "Breakfast",
  ][Number(row.category) - 1];
  const summary = `${row.signature}; ${row.method}.`;
  const short = `${summary.charAt(0).toUpperCase()}${summary.slice(1)}`;
  const description = `A freshly prepared ${row.name} built around ${row.signature}. Preparation: ${row.method}. Finished with ${row.finish}; served with ${row.pairing}.`;
  const metaDescription = `${row.signature.charAt(0).toUpperCase()}${row.signature.slice(1)}. Prepared fresh to order in the Bites Box kitchen.`;
  const keywords = [
    ...new Set(
      [
        ...row.name
          .toLowerCase()
          .split(/[^a-z0-9]+/)
          .filter(Boolean),
        ...row.slug.split("-"),
        ...row.signature
          .toLowerCase()
          .split(/[^a-z0-9]+/)
          .filter(Boolean),
        categoryName.toLowerCase(),
        row.food_type.toLowerCase(),
        "bites box",
      ]
        .flatMap((value) => value.split(/[^a-z0-9]+/))
        .filter((word) => word.length > 1 && !searchStopWords.has(word)),
    ),
  ];
  const featured =
    (Number(row.category) + index) % 9 === 0 || Number(row.category) === 11;
  const packaging = ["8", "9", "10"].includes(row.category)
    ? 5
    : row.category === "11"
      ? 15
      : 10;
  const values = [
    quote(id),
    quote(categoryId),
    "null",
    quote(row.name),
    quote(row.slug),
    quote(short),
    quote(description),
    quote(image),
    quote(image),
    quote(row.food_type),
    quote(row.spice_level),
    textArray(row.allergens),
    textArray(row.dietary_tags),
    row.price,
    "null",
    packaging,
    quote("22222222-0000-0000-0000-000000000001"),
    row.prep,
    row.serves,
    row.calories,
    featured ? "true" : "false",
    "false",
    "true",
    featured ? "true" : "false",
    row.category === "11" ? "true" : "false",
    1000 + index,
    10,
    `array[${keywords.map(quote).join(", ")}]::text[]`,
    quote(`${row.name} | Bites Box`),
    quote(metaDescription),
  ];
  return `  (${values.join(", ")})`;
});

const sql = `-- SEED 22 · 100 additional, image-backed menu choices.\n-- Product photos are bundled in the customer apps; see the shared path resolver.\n-- Safe to apply more than once so manual hosted deployments can be retried.\ninsert into public.products (\n  id, category_id, subcategory_id, name, slug, short_description, description,\n  thumbnail_path, hero_image_path, food_type, spice_level, allergens, dietary_tags,\n  base_price, compare_price, packaging_charge, tax_category_id,\n  preparation_minutes, serves_count, calories,\n  is_featured, is_best_seller, is_new, is_recommended, is_combo, display_order,\n  max_quantity_per_order, search_keywords, meta_title, meta_description\n) values\n${products.join(",\n")}\non conflict (id) do nothing\n;\n\ninsert into public.product_images (product_id, storage_path, alt_text, width, height, variants, is_primary, display_order)\nselect\n  p.id, p.hero_image_path, p.name || ' — Bites Box', 768, 768,\n  jsonb_build_object('thumb', p.thumbnail_path, 'medium', p.hero_image_path, 'large', p.hero_image_path),\n  true, 1\nfrom public.products p\nwhere p.id::text like '77777777-%'\n  and not exists (\n    select 1\n    from public.product_images existing\n    where existing.product_id = p.id\n      and existing.is_primary\n  );\n`;

writeFileSync(output, sql);
console.log(`Wrote ${products.length} products to ${output}`);
