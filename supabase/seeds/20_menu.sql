-- SEED 20 · MENU

-- ═══════════════════════════════════════════════════════════════════════════
-- MENU — CATEGORIES
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.categories (
  id, name, slug, short_description, description, thumbnail_path, image_path,
  icon_name, accent_color, display_order, is_featured, day_part,
  meta_title, meta_description, search_keywords
) values
  ('33333333-0000-0000-0000-000000000001', 'Biryani', 'biryani',
   'Slow-dum handi biryani, layered with saffron rice',
   'Our signature dum biryani is layered in sealed handis with aged basmati, whole spices and saffron milk, then cooked slowly so every grain stays separate.',
   'menu-images/categories/biryani-thumb.jpg', 'menu-images/categories/biryani.jpg',
   'rice_bowl', '#C1121F', 1, true, 'ALL_DAY',
   'Biryani in Bakhtiyarpur | Bites Box', 'Order authentic dum handi biryani in Bakhtiyarpur. Chicken, mutton and veg biryani delivered hot.',
   array['biryani','biriyani','handi','dum','rice','pulao']),

  ('33333333-0000-0000-0000-000000000002', 'Chicken', 'chicken',
   'Tandoori, curry and Bihari-style chicken',
   'From smoky tandoori to rich Bihari chicken curry cooked in mustard oil.',
   'menu-images/categories/chicken-thumb.jpg', 'menu-images/categories/chicken.jpg',
   'drumstick', '#8E0D17', 2, true, 'ALL_DAY',
   'Chicken dishes | Bites Box', 'Tandoori chicken, chicken curry and Bihari chicken specials.',
   array['chicken','murgh','tandoori','curry','chicken masala']),

  ('33333333-0000-0000-0000-000000000003', 'Mutton', 'mutton',
   'Slow-cooked champaran and rogan style mutton',
   'Tender goat meat cooked the Bihari way — handi champaran mutton and rich curries.',
   'menu-images/categories/mutton-thumb.jpg', 'menu-images/categories/mutton.jpg',
   'meat', '#5C0A11', 3, true, 'ALL_DAY',
   'Mutton dishes | Bites Box', 'Champaran handi mutton and mutton curry in Bakhtiyarpur.',
   array['mutton','goat','champaran','handi mutton','bakra']),

  ('33333333-0000-0000-0000-000000000004', 'Rolls & Wraps', 'rolls-and-wraps',
   'Flaky paratha rolls stuffed generously',
   'Hand-rolled parathas wrapped around tandoori fillings with mint chutney and onions.',
   'menu-images/categories/rolls-thumb.jpg', 'menu-images/categories/rolls.jpg',
   'wrap', '#F0A202', 4, true, 'ALL_DAY',
   'Rolls & Wraps | Bites Box', 'Chicken and paneer paratha rolls delivered fresh.',
   array['roll','wrap','kathi','paratha roll','shawarma']),

  ('33333333-0000-0000-0000-000000000005', 'Chinese', 'chinese',
   'Wok-tossed Indo-Chinese favourites',
   'High-flame wok cooking — noodles, fried rice, chilli and Manchurian.',
   'menu-images/categories/chinese-thumb.jpg', 'menu-images/categories/chinese.jpg',
   'noodles', '#1B4332', 5, false, 'ALL_DAY',
   'Chinese food | Bites Box', 'Hakka noodles, fried rice, chilli chicken and Manchurian.',
   array['chinese','noodles','hakka','fried rice','manchurian','chowmein']),

  ('33333333-0000-0000-0000-000000000006', 'Starters', 'starters',
   'Tandoor and fryer snacks to begin with',
   'Kebabs, tikka and crisp fried starters straight off the tandoor.',
   'menu-images/categories/starters-thumb.jpg', 'menu-images/categories/starters.jpg',
   'skewer', '#B45309', 6, false, 'ALL_DAY',
   'Starters & Kebabs | Bites Box', 'Tandoori kebabs, tikka and crispy starters.',
   array['starter','kebab','tikka','appetizer','snacks','pakoda']),

  ('33333333-0000-0000-0000-000000000007', 'Rice & Curries', 'rice-and-curries',
   'Homely thali-style curries with steamed rice',
   'Everyday Bihari comfort — dal, sabzi and curries with steamed rice.',
   'menu-images/categories/curries-thumb.jpg', 'menu-images/categories/curries.jpg',
   'bowl', '#1B7F4B', 7, false, 'ALL_DAY',
   'Rice & Curries | Bites Box', 'Dal, paneer and vegetable curries with rice.',
   array['curry','dal','rice','sabzi','paneer','thali']),

  ('33333333-0000-0000-0000-000000000008', 'Breads', 'breads',
   'Tandoori rotis, naans and parathas',
   'Fresh from the clay tandoor, brushed with butter.',
   'menu-images/categories/breads-thumb.jpg', 'menu-images/categories/breads.jpg',
   'bread', '#D4A24C', 8, false, 'ALL_DAY',
   'Indian Breads | Bites Box', 'Tandoori roti, butter naan, laccha paratha.',
   array['bread','roti','naan','paratha','tandoori roti','kulcha']),

  ('33333333-0000-0000-0000-000000000009', 'Beverages', 'beverages',
   'Chilled drinks, lassi and fresh coolers',
   'Soft drinks, sweet and salted lassi, and seasonal coolers.',
   'menu-images/categories/beverages-thumb.jpg', 'menu-images/categories/beverages.jpg',
   'cup', '#0EA5E9', 9, false, 'ALL_DAY',
   'Beverages | Bites Box', 'Cold drinks, lassi and coolers.',
   array['drink','beverage','cold drink','lassi','coke','water','juice']),

  ('33333333-0000-0000-0000-00000000000a', 'Desserts', 'desserts',
   'Bihari sweets and chilled desserts',
   'Traditional favourites like khaja and gulab jamun, plus chilled kheer.',
   'menu-images/categories/desserts-thumb.jpg', 'menu-images/categories/desserts.jpg',
   'sweet', '#EC4899', 10, false, 'ALL_DAY',
   'Desserts | Bites Box', 'Gulab jamun, kheer and Bihari sweets.',
   array['dessert','sweet','mithai','gulab jamun','kheer','ice cream']),

  ('33333333-0000-0000-0000-00000000000b', 'Combos & Meals', 'combos-and-meals',
   'Value meal boxes for one, two or the family',
   'Complete meal boxes that pair a main with bread, rice and a drink.',
   'menu-images/categories/combos-thumb.jpg', 'menu-images/categories/combos.jpg',
   'box', '#C1121F', 11, true, 'ALL_DAY',
   'Combo Meals | Bites Box', 'Value combo meals for solo, couple and family.',
   array['combo','meal','box','thali','family pack','value']),

  ('33333333-0000-0000-0000-00000000000c', 'Breakfast', 'breakfast',
   'Litti chokha, poori sabzi and morning classics',
   'Bihar wakes up to litti chokha, sattu paratha and hot poori sabzi.',
   'menu-images/categories/breakfast-thumb.jpg', 'menu-images/categories/breakfast.jpg',
   'sunrise', '#F0A202', 12, true, 'BREAKFAST',
   'Breakfast | Bites Box', 'Litti chokha, sattu paratha and poori sabzi in Bakhtiyarpur.',
   array['breakfast','litti','chokha','sattu','poori','nashta']);

insert into public.subcategories (category_id, name, slug, display_order) values
  ('33333333-0000-0000-0000-000000000001', 'Chicken Biryani', 'chicken-biryani', 1),
  ('33333333-0000-0000-0000-000000000001', 'Mutton Biryani', 'mutton-biryani', 2),
  ('33333333-0000-0000-0000-000000000001', 'Veg Biryani', 'veg-biryani', 3),
  ('33333333-0000-0000-0000-000000000002', 'Tandoori', 'tandoori', 1),
  ('33333333-0000-0000-0000-000000000002', 'Curry', 'curry', 2),
  ('33333333-0000-0000-0000-000000000005', 'Noodles', 'noodles', 1),
  ('33333333-0000-0000-0000-000000000005', 'Rice', 'chinese-rice', 2),
  ('33333333-0000-0000-0000-000000000005', 'Gravy', 'chinese-gravy', 3),
  ('33333333-0000-0000-0000-000000000006', 'Veg Starters', 'veg-starters', 1),
  ('33333333-0000-0000-0000-000000000006', 'Non-veg Starters', 'non-veg-starters', 2);

-- ═══════════════════════════════════════════════════════════════════════════
-- MODIFIER GROUPS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.modifier_groups (
  id, name, slug, description, selection, min_select, max_select, is_required,
  free_selections, display_order
) values
  ('44444444-0000-0000-0000-000000000001', 'Spice level', 'spice-level',
   'How hot would you like it?', 'SINGLE', 1, 1, true, 0, 1),
  ('44444444-0000-0000-0000-000000000002', 'Add-ons', 'add-ons',
   'Make it a fuller meal', 'MULTIPLE', 0, 6, false, 0, 5),
  ('44444444-0000-0000-0000-000000000003', 'Biryani extras', 'biryani-extras',
   'Raita, salan and extra pieces', 'MULTIPLE', 0, 5, false, 0, 3),
  ('44444444-0000-0000-0000-000000000004', 'Roll fillings', 'roll-fillings',
   'Load up your roll', 'MULTIPLE', 0, 4, false, 0, 3),
  ('44444444-0000-0000-0000-000000000005', 'Remove ingredients', 'remove-ingredients',
   'Anything you would like left out?', 'MULTIPLE', 0, 4, false, 4, 8),
  ('44444444-0000-0000-0000-000000000006', 'Bread choice', 'bread-choice',
   'Pick your bread', 'SINGLE', 1, 1, true, 0, 2),
  ('44444444-0000-0000-0000-000000000007', 'Gravy style', 'gravy-style',
   'Choose your preparation', 'SINGLE', 1, 1, true, 0, 2),
  ('44444444-0000-0000-0000-000000000008', 'Drink choice', 'drink-choice',
   'Included drink', 'SINGLE', 1, 1, true, 0, 4),
  ('44444444-0000-0000-0000-000000000009', 'Toppings', 'toppings',
   'First two toppings are on us', 'MULTIPLE', 0, 5, false, 2, 6);

insert into public.modifiers (modifier_group_id, name, price, food_type, is_default, display_order) values
  -- Spice level
  ('44444444-0000-0000-0000-000000000001', 'Mild',            0, 'VEG', false, 1),
  ('44444444-0000-0000-0000-000000000001', 'Medium',          0, 'VEG', true,  2),
  ('44444444-0000-0000-0000-000000000001', 'Bihari hot',      0, 'VEG', false, 3),
  ('44444444-0000-0000-0000-000000000001', 'Extra hot',       0, 'VEG', false, 4),
  -- Add-ons
  ('44444444-0000-0000-0000-000000000002', 'Extra gravy',    30, 'VEG', false, 1),
  ('44444444-0000-0000-0000-000000000002', 'Butter naan',    45, 'VEG', false, 2),
  ('44444444-0000-0000-0000-000000000002', 'Green salad',    35, 'VEG', false, 3),
  ('44444444-0000-0000-0000-000000000002', 'Masala papad',   30, 'VEG', false, 4),
  ('44444444-0000-0000-0000-000000000002', 'Boiled egg',     25, 'EGG', false, 5),
  ('44444444-0000-0000-0000-000000000002', 'Gulab jamun (2)',60, 'VEG', false, 6),
  -- Biryani extras
  ('44444444-0000-0000-0000-000000000003', 'Boondi raita',       40, 'VEG',     false, 1),
  ('44444444-0000-0000-0000-000000000003', 'Mirchi ka salan',    35, 'VEG',     false, 2),
  ('44444444-0000-0000-0000-000000000003', 'Extra chicken leg',  90, 'NON_VEG', false, 3),
  ('44444444-0000-0000-0000-000000000003', 'Extra mutton pieces',140,'NON_VEG', false, 4),
  ('44444444-0000-0000-0000-000000000003', 'Extra rice portion', 70, 'VEG',     false, 5),
  -- Roll fillings
  ('44444444-0000-0000-0000-000000000004', 'Extra chicken',  60, 'NON_VEG', false, 1),
  ('44444444-0000-0000-0000-000000000004', 'Extra cheese',   40, 'VEG',     false, 2),
  ('44444444-0000-0000-0000-000000000004', 'Double egg',     30, 'EGG',     false, 3),
  ('44444444-0000-0000-0000-000000000004', 'Extra onions',   10, 'VEG',     false, 4),
  -- Remove ingredients (free)
  ('44444444-0000-0000-0000-000000000005', 'No onion',       0, 'VEG', false, 1),
  ('44444444-0000-0000-0000-000000000005', 'No garlic',      0, 'VEG', false, 2),
  ('44444444-0000-0000-0000-000000000005', 'No coriander',   0, 'VEG', false, 3),
  ('44444444-0000-0000-0000-000000000005', 'Less oil',       0, 'VEG', false, 4),
  -- Bread choice
  ('44444444-0000-0000-0000-000000000006', 'Tandoori roti (2)',  0, 'VEG', true,  1),
  ('44444444-0000-0000-0000-000000000006', 'Butter naan (2)',   25, 'VEG', false, 2),
  ('44444444-0000-0000-0000-000000000006', 'Laccha paratha (1)',20, 'VEG', false, 3),
  ('44444444-0000-0000-0000-000000000006', 'Steamed rice',       0, 'VEG', false, 4),
  -- Gravy style
  ('44444444-0000-0000-0000-000000000007', 'Bihari masala', 0, 'VEG', true,  1),
  ('44444444-0000-0000-0000-000000000007', 'Butter gravy',  20, 'VEG', false, 2),
  ('44444444-0000-0000-0000-000000000007', 'Kadhai style',  10, 'VEG', false, 3),
  -- Drink choice
  ('44444444-0000-0000-0000-000000000008', 'Coca-Cola 250ml',  0, 'VEG', true,  1),
  ('44444444-0000-0000-0000-000000000008', 'Sprite 250ml',     0, 'VEG', false, 2),
  ('44444444-0000-0000-0000-000000000008', 'Sweet lassi',     20, 'VEG', false, 3),
  ('44444444-0000-0000-0000-000000000008', 'Masala chaas',    15, 'VEG', false, 4),
  -- Toppings
  ('44444444-0000-0000-0000-000000000009', 'Fried onions',   15, 'VEG', false, 1),
  ('44444444-0000-0000-0000-000000000009', 'Roasted cashew', 35, 'VEG', false, 2),
  ('44444444-0000-0000-0000-000000000009', 'Fresh coriander', 5, 'VEG', false, 3),
  ('44444444-0000-0000-0000-000000000009', 'Lemon wedge',     5, 'VEG', false, 4),
  ('44444444-0000-0000-0000-000000000009', 'Green chutney',  15, 'VEG', false, 5);

-- ═══════════════════════════════════════════════════════════════════════════
-- PRODUCTS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.products (
  id, category_id, subcategory_id, name, slug, short_description, description,
  thumbnail_path, hero_image_path, food_type, spice_level, allergens, dietary_tags,
  base_price, compare_price, packaging_charge, tax_category_id,
  preparation_minutes, serves_count, calories,
  is_featured, is_best_seller, is_new, is_recommended, is_combo, display_order,
  max_quantity_per_order, search_keywords, meta_title, meta_description
) values
-- ── Biryani ──
('55555555-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001',
 (select id from public.subcategories where slug = 'chicken-biryani'),
 'Chicken Dum Biryani', 'chicken-dum-biryani',
 'Handi-sealed biryani with saffron rice and tender chicken',
 'Aged basmati layered with marinated chicken, browned onions, mint and saffron milk, sealed in a handi and finished on slow dum. Served with boondi raita and mirchi ka salan.',
 'menu-images/products/chicken-dum-biryani-thumb.jpg', 'menu-images/products/chicken-dum-biryani.jpg',
 'NON_VEG', 'MEDIUM', array['dairy','nuts'], array['high-protein'],
 249, 299, 15, '22222222-0000-0000-0000-000000000001', 25, 1, 720,
 true, true, false, true, false, 1, 10,
 array['biryani','chicken biryani','dum biryani','handi','murgh biryani'],
 'Chicken Dum Biryani in Bakhtiyarpur | Bites Box',
 'Order authentic chicken dum biryani cooked in sealed handis. Free delivery above ₹349.'),

('55555555-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000001',
 (select id from public.subcategories where slug = 'mutton-biryani'),
 'Mutton Dum Biryani', 'mutton-dum-biryani',
 'Slow-cooked goat meat layered with basmati and whole spices',
 'Tender goat meat marinated overnight in yoghurt and Bihari spices, then dum-cooked with basmati until the meat falls off the bone.',
 'menu-images/products/mutton-dum-biryani-thumb.jpg', 'menu-images/products/mutton-dum-biryani.jpg',
 'NON_VEG', 'MEDIUM', array['dairy','nuts'], array['high-protein'],
 379, 449, 15, '22222222-0000-0000-0000-000000000001', 35, 1, 850,
 true, true, false, true, false, 2, 8,
 array['mutton biryani','goat biryani','dum biryani','handi'],
 'Mutton Dum Biryani | Bites Box', 'Slow dum-cooked mutton biryani delivered hot in Bakhtiyarpur.'),

('55555555-0000-0000-0000-000000000003', '33333333-0000-0000-0000-000000000001',
 (select id from public.subcategories where slug = 'veg-biryani'),
 'Subz Handi Biryani', 'subz-handi-biryani',
 'Seasonal vegetables and paneer dum-cooked with saffron rice',
 'Garden vegetables, paneer cubes and cashew layered with fragrant basmati, dum-cooked and finished with fried onions.',
 'menu-images/products/subz-biryani-thumb.jpg', 'menu-images/products/subz-biryani.jpg',
 'VEG', 'MILD', array['dairy','nuts'], array['vegetarian'],
 199, 239, 15, '22222222-0000-0000-0000-000000000001', 22, 1, 610,
 false, true, false, false, false, 3, 10,
 array['veg biryani','subz biryani','paneer biryani','vegetarian'],
 'Veg Handi Biryani | Bites Box', 'Vegetarian dum biryani with paneer and seasonal vegetables.'),

('55555555-0000-0000-0000-000000000004', '33333333-0000-0000-0000-000000000001',
 (select id from public.subcategories where slug = 'chicken-biryani'),
 'Egg Biryani', 'egg-biryani',
 'Saffron biryani with spiced boiled eggs',
 'Fragrant dum rice served with two masala-coated boiled eggs and browned onions.',
 'menu-images/products/egg-biryani-thumb.jpg', 'menu-images/products/egg-biryani.jpg',
 'EGG', 'MEDIUM', array['dairy','egg'], array['high-protein'],
 169, null, 15, '22222222-0000-0000-0000-000000000001', 20, 1, 560,
 false, false, true, false, false, 4, 10,
 array['egg biryani','anda biryani'],
 'Egg Biryani | Bites Box', 'Egg dum biryani with masala boiled eggs.'),

-- ── Chicken ──
('55555555-0000-0000-0000-000000000010', '33333333-0000-0000-0000-000000000002',
 (select id from public.subcategories where slug = 'tandoori'),
 'Tandoori Chicken', 'tandoori-chicken',
 'Charcoal-grilled chicken in yoghurt and Kashmiri chilli marinade',
 'Overnight marinade of hung curd, ginger-garlic and Kashmiri chilli, finished over charcoal for a smoky crust. Served with mint chutney and onion rings.',
 'menu-images/products/tandoori-chicken-thumb.jpg', 'menu-images/products/tandoori-chicken.jpg',
 'NON_VEG', 'MEDIUM', array['dairy'], array['high-protein','gluten-free'],
 279, 329, 15, '22222222-0000-0000-0000-000000000001', 28, 2, 480,
 true, true, false, true, false, 1, 6,
 array['tandoori chicken','tandoori','grilled chicken','charcoal'],
 'Tandoori Chicken | Bites Box', 'Charcoal tandoori chicken, half or full.'),

('55555555-0000-0000-0000-000000000011', '33333333-0000-0000-0000-000000000002',
 (select id from public.subcategories where slug = 'curry'),
 'Bihari Chicken Masala', 'bihari-chicken-masala',
 'Mustard-oil chicken curry the way Bihar makes it',
 'Chicken slow-cooked in mustard oil with onion, whole spices and a hint of panch phoron. Robust, rustic and best with tandoori roti.',
 'menu-images/products/bihari-chicken-thumb.jpg', 'menu-images/products/bihari-chicken.jpg',
 'NON_VEG', 'HOT', array[]::text[], array['high-protein'],
 269, null, 15, '22222222-0000-0000-0000-000000000001', 25, 2, 520,
 true, true, false, true, false, 2, 8,
 array['chicken curry','bihari chicken','chicken masala','murgh'],
 'Bihari Chicken Masala | Bites Box', 'Authentic Bihari-style chicken curry in mustard oil.'),

('55555555-0000-0000-0000-000000000012', '33333333-0000-0000-0000-000000000002',
 (select id from public.subcategories where slug = 'curry'),
 'Butter Chicken', 'butter-chicken',
 'Tandoori chicken in a silky tomato-butter gravy',
 'Charred tandoori chicken simmered in a velvety tomato, cashew and butter gravy, finished with cream and fenugreek.',
 'menu-images/products/butter-chicken-thumb.jpg', 'menu-images/products/butter-chicken.jpg',
 'NON_VEG', 'MILD', array['dairy','nuts'], array['high-protein'],
 299, 349, 15, '22222222-0000-0000-0000-000000000001', 25, 2, 640,
 true, true, false, true, false, 3, 8,
 array['butter chicken','murgh makhani','makhani','creamy chicken'],
 'Butter Chicken | Bites Box', 'Rich butter chicken with naan or rice.'),

('55555555-0000-0000-0000-000000000013', '33333333-0000-0000-0000-000000000002',
 (select id from public.subcategories where slug = 'tandoori'),
 'Chicken Tikka', 'chicken-tikka',
 'Boneless tandoori chicken cubes, smoky and juicy',
 'Boneless thigh pieces marinated in spiced hung curd and grilled in the tandoor on skewers.',
 'menu-images/products/chicken-tikka-thumb.jpg', 'menu-images/products/chicken-tikka.jpg',
 'NON_VEG', 'MEDIUM', array['dairy'], array['high-protein','gluten-free'],
 249, null, 15, '22222222-0000-0000-0000-000000000001', 22, 1, 420,
 false, true, false, false, false, 4, 8,
 array['chicken tikka','tikka','boneless chicken','tandoori'],
 'Chicken Tikka | Bites Box', 'Boneless chicken tikka from the tandoor.'),

-- ── Mutton ──
('55555555-0000-0000-0000-000000000020', '33333333-0000-0000-0000-000000000003', null,
 'Champaran Handi Mutton', 'champaran-handi-mutton',
 'Sealed-clay-pot mutton — Bihar''s most famous dish',
 'The pride of Champaran. Goat meat, mustard oil, garlic and whole spices sealed inside a clay handi with dough and slow-cooked so nothing escapes.',
 'menu-images/products/champaran-mutton-thumb.jpg', 'menu-images/products/champaran-mutton.jpg',
 'NON_VEG', 'HOT', array[]::text[], array['high-protein'],
 449, 529, 20, '22222222-0000-0000-0000-000000000001', 40, 2, 760,
 true, true, false, true, false, 1, 6,
 array['champaran mutton','handi mutton','ahuna','matka mutton','bihari mutton'],
 'Champaran Handi Mutton | Bites Box', 'Authentic Champaran ahuna mutton cooked in a sealed clay handi.'),

('55555555-0000-0000-0000-000000000021', '33333333-0000-0000-0000-000000000003', null,
 'Mutton Curry', 'mutton-curry',
 'Home-style goat curry with onion-tomato masala',
 'Everyday mutton curry, pressure-finished until tender, with a thin spiced gravy perfect for rice.',
 'menu-images/products/mutton-curry-thumb.jpg', 'menu-images/products/mutton-curry.jpg',
 'NON_VEG', 'MEDIUM', array[]::text[], array['high-protein'],
 399, null, 20, '22222222-0000-0000-0000-000000000001', 35, 2, 690,
 false, false, false, true, false, 2, 6,
 array['mutton curry','goat curry','mutton masala'],
 'Mutton Curry | Bites Box', 'Home-style mutton curry with rice or roti.'),

-- ── Rolls ──
('55555555-0000-0000-0000-000000000030', '33333333-0000-0000-0000-000000000004', null,
 'Chicken Tikka Roll', 'chicken-tikka-roll',
 'Flaky paratha wrapped around smoky chicken tikka',
 'Layered paratha rolled with tandoori chicken tikka, onions, green chutney and a squeeze of lemon.',
 'menu-images/products/chicken-tikka-roll-thumb.jpg', 'menu-images/products/chicken-tikka-roll.jpg',
 'NON_VEG', 'MEDIUM', array['gluten','dairy'], array['high-protein'],
 129, 149, 10, '22222222-0000-0000-0000-000000000001', 12, 1, 420,
 true, true, false, true, false, 1, 12,
 array['roll','chicken roll','tikka roll','kathi roll','wrap'],
 'Chicken Tikka Roll | Bites Box', 'Chicken tikka paratha roll with mint chutney.'),

('55555555-0000-0000-0000-000000000031', '33333333-0000-0000-0000-000000000004', null,
 'Egg Chicken Roll', 'egg-chicken-roll',
 'Egg-coated paratha with chicken and onions',
 'Paratha crisped with a layer of egg, filled with chicken, onions and chutney.',
 'menu-images/products/egg-chicken-roll-thumb.jpg', 'menu-images/products/egg-chicken-roll.jpg',
 'NON_VEG', 'MEDIUM', array['gluten','egg'], array['high-protein'],
 149, null, 10, '22222222-0000-0000-0000-000000000001', 13, 1, 480,
 false, true, false, false, false, 2, 12,
 array['egg roll','anda roll','chicken egg roll'],
 'Egg Chicken Roll | Bites Box', 'Egg chicken paratha roll.'),

('55555555-0000-0000-0000-000000000032', '33333333-0000-0000-0000-000000000004', null,
 'Paneer Tikka Roll', 'paneer-tikka-roll',
 'Tandoori paneer wrapped in flaky paratha',
 'Marinated paneer cubes grilled in the tandoor, rolled with capsicum, onions and mint chutney.',
 'menu-images/products/paneer-tikka-roll-thumb.jpg', 'menu-images/products/paneer-tikka-roll.jpg',
 'VEG', 'MEDIUM', array['gluten','dairy'], array['vegetarian'],
 119, 139, 10, '22222222-0000-0000-0000-000000000001', 12, 1, 400,
 false, false, false, true, false, 3, 12,
 array['paneer roll','veg roll','paneer tikka roll'],
 'Paneer Tikka Roll | Bites Box', 'Vegetarian paneer tikka roll.'),

-- ── Chinese ──
('55555555-0000-0000-0000-000000000040', '33333333-0000-0000-0000-000000000005',
 (select id from public.subcategories where slug = 'noodles'),
 'Chicken Hakka Noodles', 'chicken-hakka-noodles',
 'Wok-tossed noodles with shredded chicken and vegetables',
 'High-flame wok noodles with julienned vegetables, shredded chicken, soy and a touch of vinegar.',
 'menu-images/products/chicken-hakka-noodles-thumb.jpg', 'menu-images/products/chicken-hakka-noodles.jpg',
 'NON_VEG', 'MEDIUM', array['gluten','soy'], array[]::text[],
 179, null, 15, '22222222-0000-0000-0000-000000000001', 15, 1, 580,
 false, true, false, false, false, 1, 10,
 array['noodles','hakka noodles','chowmein','chinese noodles'],
 'Chicken Hakka Noodles | Bites Box', 'Wok-tossed chicken hakka noodles.'),

('55555555-0000-0000-0000-000000000041', '33333333-0000-0000-0000-000000000005',
 (select id from public.subcategories where slug = 'chinese-rice'),
 'Veg Fried Rice', 'veg-fried-rice',
 'Wok-fried rice with crisp garden vegetables',
 'Long-grain rice tossed on high flame with carrot, beans, cabbage, spring onion and soy.',
 'menu-images/products/veg-fried-rice-thumb.jpg', 'menu-images/products/veg-fried-rice.jpg',
 'VEG', 'MILD', array['gluten','soy'], array['vegetarian'],
 149, null, 15, '22222222-0000-0000-0000-000000000001', 14, 1, 520,
 false, false, false, false, false, 2, 10,
 array['fried rice','veg fried rice','chinese rice'],
 'Veg Fried Rice | Bites Box', 'Wok-fried vegetable rice.'),

('55555555-0000-0000-0000-000000000042', '33333333-0000-0000-0000-000000000005',
 (select id from public.subcategories where slug = 'chinese-gravy'),
 'Chilli Chicken', 'chilli-chicken',
 'Crisp chicken tossed in a fiery soy-chilli glaze',
 'Batter-fried chicken tossed with onion, capsicum and green chilli in a glossy soy-chilli sauce.',
 'menu-images/products/chilli-chicken-thumb.jpg', 'menu-images/products/chilli-chicken.jpg',
 'NON_VEG', 'HOT', array['gluten','soy'], array['high-protein'],
 229, null, 15, '22222222-0000-0000-0000-000000000001', 18, 1, 540,
 false, true, false, true, false, 3, 8,
 array['chilli chicken','chinese chicken','dry chicken'],
 'Chilli Chicken | Bites Box', 'Indo-Chinese chilli chicken, dry or gravy.'),

('55555555-0000-0000-0000-000000000043', '33333333-0000-0000-0000-000000000005',
 (select id from public.subcategories where slug = 'chinese-gravy'),
 'Veg Manchurian', 'veg-manchurian',
 'Crisp vegetable dumplings in a tangy Manchurian sauce',
 'Hand-rolled vegetable balls fried until crisp, then simmered in a garlicky sweet-and-sour sauce.',
 'menu-images/products/veg-manchurian-thumb.jpg', 'menu-images/products/veg-manchurian.jpg',
 'VEG', 'MEDIUM', array['gluten','soy'], array['vegetarian'],
 169, null, 15, '22222222-0000-0000-0000-000000000001', 16, 1, 470,
 false, false, false, false, false, 4, 10,
 array['manchurian','veg manchurian','chinese veg'],
 'Veg Manchurian | Bites Box', 'Veg Manchurian, dry or gravy.'),

-- ── Starters ──
('55555555-0000-0000-0000-000000000050', '33333333-0000-0000-0000-000000000006',
 (select id from public.subcategories where slug = 'non-veg-starters'),
 'Chicken Seekh Kebab', 'chicken-seekh-kebab',
 'Minced chicken kebabs grilled on skewers',
 'Spiced chicken mince pressed onto skewers with ginger, coriander and green chilli, char-grilled until juicy.',
 'menu-images/products/seekh-kebab-thumb.jpg', 'menu-images/products/seekh-kebab.jpg',
 'NON_VEG', 'MEDIUM', array[]::text[], array['high-protein','gluten-free'],
 229, null, 15, '22222222-0000-0000-0000-000000000001', 20, 1, 380,
 false, false, true, true, false, 1, 8,
 array['seekh kebab','kebab','chicken kebab','starter'],
 'Chicken Seekh Kebab | Bites Box', 'Char-grilled chicken seekh kebabs.'),

('55555555-0000-0000-0000-000000000051', '33333333-0000-0000-0000-000000000006',
 (select id from public.subcategories where slug = 'veg-starters'),
 'Paneer Tikka', 'paneer-tikka',
 'Tandoor-charred cottage cheese with peppers',
 'Thick paneer cubes marinated in spiced yoghurt and grilled with onion and capsicum.',
 'menu-images/products/paneer-tikka-thumb.jpg', 'menu-images/products/paneer-tikka.jpg',
 'VEG', 'MEDIUM', array['dairy'], array['vegetarian','gluten-free'],
 219, 249, 15, '22222222-0000-0000-0000-000000000001', 18, 1, 410,
 true, false, false, true, false, 2, 8,
 array['paneer tikka','veg starter','tandoori paneer'],
 'Paneer Tikka | Bites Box', 'Tandoori paneer tikka with mint chutney.'),

('55555555-0000-0000-0000-000000000052', '33333333-0000-0000-0000-000000000006',
 (select id from public.subcategories where slug = 'veg-starters'),
 'Onion Pakoda', 'onion-pakoda',
 'Crisp gram-flour onion fritters',
 'Sliced onions in a spiced besan batter, fried crisp. The monsoon classic.',
 'menu-images/products/onion-pakoda-thumb.jpg', 'menu-images/products/onion-pakoda.jpg',
 'VEG', 'MEDIUM', array[]::text[], array['vegetarian','vegan'],
 89, null, 10, '22222222-0000-0000-0000-000000000001', 12, 1, 320,
 false, false, false, false, false, 3, 12,
 array['pakoda','pakora','fritters','onion pakoda','snacks'],
 'Onion Pakoda | Bites Box', 'Crisp onion pakoda with chutney.'),

-- ── Rice & Curries ──
('55555555-0000-0000-0000-000000000060', '33333333-0000-0000-0000-000000000007', null,
 'Paneer Butter Masala', 'paneer-butter-masala',
 'Soft paneer in a rich tomato-cashew gravy',
 'Cottage cheese cubes in a smooth tomato and cashew gravy, finished with butter and cream.',
 'menu-images/products/paneer-butter-masala-thumb.jpg', 'menu-images/products/paneer-butter-masala.jpg',
 'VEG', 'MILD', array['dairy','nuts'], array['vegetarian'],
 239, 279, 15, '22222222-0000-0000-0000-000000000001', 20, 2, 560,
 true, true, false, true, false, 1, 8,
 array['paneer','paneer butter masala','paneer makhani','veg curry'],
 'Paneer Butter Masala | Bites Box', 'Creamy paneer butter masala with naan.'),

('55555555-0000-0000-0000-000000000061', '33333333-0000-0000-0000-000000000007', null,
 'Dal Tadka', 'dal-tadka',
 'Yellow lentils with a sizzling ghee tempering',
 'Slow-simmered arhar dal finished with a ghee tadka of cumin, garlic and dried red chilli.',
 'menu-images/products/dal-tadka-thumb.jpg', 'menu-images/products/dal-tadka.jpg',
 'VEG', 'MILD', array['dairy'], array['vegetarian'],
 129, null, 15, '22222222-0000-0000-0000-000000000001', 15, 2, 320,
 false, true, false, false, false, 2, 10,
 array['dal','dal tadka','dal fry','lentils'],
 'Dal Tadka | Bites Box', 'Ghee-tempered dal tadka with rice.'),

('55555555-0000-0000-0000-000000000062', '33333333-0000-0000-0000-000000000007', null,
 'Aloo Chokha with Rice', 'aloo-chokha-rice',
 'Smoked mashed potato with steamed rice and ghee',
 'Fire-roasted potato mashed with mustard oil, onion, garlic and green chilli, served with steamed rice.',
 'menu-images/products/aloo-chokha-thumb.jpg', 'menu-images/products/aloo-chokha.jpg',
 'VEG', 'MEDIUM', array[]::text[], array['vegetarian','vegan'],
 119, null, 15, '22222222-0000-0000-0000-000000000001', 14, 1, 430,
 false, false, false, false, false, 3, 10,
 array['chokha','aloo chokha','bihari','rice'],
 'Aloo Chokha with Rice | Bites Box', 'Bihari smoked potato chokha with rice.'),

-- ── Breads ──
('55555555-0000-0000-0000-000000000070', '33333333-0000-0000-0000-000000000008', null,
 'Tandoori Roti', 'tandoori-roti',
 'Whole-wheat roti from the clay tandoor',
 'Hand-stretched wheat roti baked against the wall of the tandoor.',
 'menu-images/products/tandoori-roti-thumb.jpg', 'menu-images/products/tandoori-roti.jpg',
 'VEG', 'NONE', array['gluten'], array['vegetarian'],
 15, null, 0, '22222222-0000-0000-0000-000000000001', 6, 1, 120,
 false, false, false, false, false, 1, 20,
 array['roti','tandoori roti','bread'],
 'Tandoori Roti | Bites Box', 'Fresh tandoori roti.'),

('55555555-0000-0000-0000-000000000071', '33333333-0000-0000-0000-000000000008', null,
 'Butter Naan', 'butter-naan',
 'Soft leavened naan brushed with butter',
 'Refined-flour naan baked in the tandoor and finished with a generous brush of butter.',
 'menu-images/products/butter-naan-thumb.jpg', 'menu-images/products/butter-naan.jpg',
 'VEG', 'NONE', array['gluten','dairy'], array['vegetarian'],
 45, null, 0, '22222222-0000-0000-0000-000000000001', 7, 1, 260,
 false, true, false, false, false, 2, 20,
 array['naan','butter naan','bread'],
 'Butter Naan | Bites Box', 'Soft butter naan from the tandoor.'),

('55555555-0000-0000-0000-000000000072', '33333333-0000-0000-0000-000000000008', null,
 'Laccha Paratha', 'laccha-paratha',
 'Multi-layered flaky paratha',
 'Whorled, layered paratha baked in the tandoor until each layer separates.',
 'menu-images/products/laccha-paratha-thumb.jpg', 'menu-images/products/laccha-paratha.jpg',
 'VEG', 'NONE', array['gluten','dairy'], array['vegetarian'],
 55, null, 0, '22222222-0000-0000-0000-000000000001', 8, 1, 310,
 false, false, false, false, false, 3, 20,
 array['paratha','laccha paratha','lachha','bread'],
 'Laccha Paratha | Bites Box', 'Flaky laccha paratha.'),

-- ── Beverages ──
('55555555-0000-0000-0000-000000000080', '33333333-0000-0000-0000-000000000009', null,
 'Coca-Cola', 'coca-cola',
 'Chilled Coca-Cola',
 'Served chilled.',
 'menu-images/products/coca-cola-thumb.jpg', 'menu-images/products/coca-cola.jpg',
 'VEG', 'NONE', array[]::text[], array[]::text[],
 40, null, 0, '22222222-0000-0000-0000-000000000003', 2, 1, 140,
 false, true, false, false, false, 1, 12,
 array['coke','coca cola','cold drink','soft drink','pepsi'],
 'Coca-Cola | Bites Box', 'Chilled Coca-Cola.'),

('55555555-0000-0000-0000-000000000081', '33333333-0000-0000-0000-000000000009', null,
 'Sweet Lassi', 'sweet-lassi',
 'Thick chilled yoghurt drink',
 'Hand-churned curd blended with sugar and a hint of cardamom, served chilled.',
 'menu-images/products/sweet-lassi-thumb.jpg', 'menu-images/products/sweet-lassi.jpg',
 'VEG', 'NONE', array['dairy'], array['vegetarian'],
 60, null, 5, '22222222-0000-0000-0000-000000000002', 5, 1, 220,
 false, true, false, true, false, 2, 10,
 array['lassi','sweet lassi','curd','yoghurt drink'],
 'Sweet Lassi | Bites Box', 'Thick sweet lassi.'),

('55555555-0000-0000-0000-000000000082', '33333333-0000-0000-0000-000000000009', null,
 'Masala Chaas', 'masala-chaas',
 'Spiced buttermilk with roasted cumin',
 'Light buttermilk with roasted cumin, black salt and fresh coriander.',
 'menu-images/products/masala-chaas-thumb.jpg', 'menu-images/products/masala-chaas.jpg',
 'VEG', 'NONE', array['dairy'], array['vegetarian'],
 45, null, 5, '22222222-0000-0000-0000-000000000002', 4, 1, 90,
 false, false, false, false, false, 3, 10,
 array['chaas','buttermilk','masala chaas','mattha'],
 'Masala Chaas | Bites Box', 'Spiced buttermilk.'),

('55555555-0000-0000-0000-000000000083', '33333333-0000-0000-0000-000000000009', null,
 'Packaged Drinking Water 1L', 'packaged-water-1l',
 'Sealed 1 litre bottle',
 'Sealed packaged drinking water.',
 'menu-images/products/water-thumb.jpg', 'menu-images/products/water.jpg',
 'VEG', 'NONE', array[]::text[], array[]::text[],
 20, null, 0, '22222222-0000-0000-0000-000000000004', 1, 1, 0,
 false, false, false, false, false, 4, 12,
 array['water','bottle','drinking water','pani'],
 'Packaged Water | Bites Box', 'Sealed 1L drinking water.'),

-- ── Desserts ──
('55555555-0000-0000-0000-000000000090', '33333333-0000-0000-0000-00000000000a', null,
 'Gulab Jamun (2 pcs)', 'gulab-jamun',
 'Warm milk dumplings in cardamom syrup',
 'Khoya dumplings fried golden and soaked in rose-cardamom syrup.',
 'menu-images/products/gulab-jamun-thumb.jpg', 'menu-images/products/gulab-jamun.jpg',
 'VEG', 'NONE', array['dairy','gluten'], array['vegetarian'],
 70, null, 5, '22222222-0000-0000-0000-000000000002', 3, 1, 300,
 false, true, false, true, false, 1, 10,
 array['gulab jamun','sweet','dessert','mithai'],
 'Gulab Jamun | Bites Box', 'Warm gulab jamun, 2 pieces.'),

('55555555-0000-0000-0000-000000000091', '33333333-0000-0000-0000-00000000000a', null,
 'Rice Kheer', 'rice-kheer',
 'Slow-cooked rice pudding with nuts',
 'Full-fat milk reduced with rice, cardamom and slivered almonds. Served chilled.',
 'menu-images/products/kheer-thumb.jpg', 'menu-images/products/kheer.jpg',
 'VEG', 'NONE', array['dairy','nuts'], array['vegetarian'],
 90, null, 5, '22222222-0000-0000-0000-000000000002', 4, 1, 340,
 false, false, false, false, false, 2, 10,
 array['kheer','rice kheer','payasam','dessert'],
 'Rice Kheer | Bites Box', 'Chilled rice kheer with nuts.'),

-- ── Breakfast ──
('55555555-0000-0000-0000-0000000000a0', '33333333-0000-0000-0000-00000000000c', null,
 'Litti Chokha (4 pcs)', 'litti-chokha',
 'Sattu-stuffed wheat balls with smoked chokha and ghee',
 'Bihar''s signature dish. Whole-wheat litti stuffed with spiced roasted gram flour, roasted over coal, dunked in ghee and served with brinjal-tomato-potato chokha.',
 'menu-images/products/litti-chokha-thumb.jpg', 'menu-images/products/litti-chokha.jpg',
 'VEG', 'MEDIUM', array['gluten','dairy'], array['vegetarian'],
 149, 179, 15, '22222222-0000-0000-0000-000000000001', 20, 1, 620,
 true, true, false, true, false, 1, 10,
 array['litti','chokha','litti chokha','sattu','bihari','breakfast'],
 'Litti Chokha in Bakhtiyarpur | Bites Box', 'Authentic coal-roasted litti chokha with ghee.'),

('55555555-0000-0000-0000-0000000000a1', '33333333-0000-0000-0000-00000000000c', null,
 'Sattu Paratha (2 pcs)', 'sattu-paratha',
 'Roasted gram-flour stuffed paratha with pickle',
 'Wheat paratha stuffed with spiced sattu, griddled with ghee, served with mango pickle and curd.',
 'menu-images/products/sattu-paratha-thumb.jpg', 'menu-images/products/sattu-paratha.jpg',
 'VEG', 'MEDIUM', array['gluten','dairy'], array['vegetarian'],
 109, null, 10, '22222222-0000-0000-0000-000000000001', 15, 1, 480,
 false, false, true, false, false, 2, 10,
 array['sattu paratha','paratha','breakfast','bihari'],
 'Sattu Paratha | Bites Box', 'Sattu-stuffed paratha with pickle and curd.'),

('55555555-0000-0000-0000-0000000000a2', '33333333-0000-0000-0000-00000000000c', null,
 'Poori Sabzi', 'poori-sabzi',
 'Puffed pooris with spiced potato curry',
 'Six hot pooris with Bihari-style aloo sabzi and a wedge of pickle.',
 'menu-images/products/poori-sabzi-thumb.jpg', 'menu-images/products/poori-sabzi.jpg',
 'VEG', 'MEDIUM', array['gluten'], array['vegetarian','vegan'],
 99, null, 10, '22222222-0000-0000-0000-000000000001', 14, 1, 560,
 false, true, false, false, false, 3, 10,
 array['poori','puri','sabzi','breakfast','aloo'],
 'Poori Sabzi | Bites Box', 'Hot pooris with aloo sabzi.'),

-- ── Combos ──
('55555555-0000-0000-0000-0000000000b0', '33333333-0000-0000-0000-00000000000b', null,
 'Solo Biryani Combo', 'solo-biryani-combo',
 'Chicken biryani + raita + gulab jamun + drink',
 'Everything one person needs: a full chicken dum biryani, boondi raita, two gulab jamun and a chilled drink.',
 'menu-images/products/solo-biryani-combo-thumb.jpg', 'menu-images/products/solo-biryani-combo.jpg',
 'NON_VEG', 'MEDIUM', array['dairy','nuts','gluten'], array['high-protein'],
 329, 419, 20, '22222222-0000-0000-0000-000000000001', 27, 1, 1080,
 true, true, false, true, true, 1, 6,
 array['combo','biryani combo','meal box','value meal'],
 'Solo Biryani Combo | Bites Box', 'Biryani, raita, dessert and a drink in one box.'),

('55555555-0000-0000-0000-0000000000b1', '33333333-0000-0000-0000-00000000000b', null,
 'Family Feast Box', 'family-feast-box',
 'Serves 4 — biryani, mutton, chicken, breads and dessert',
 'A complete family spread: two chicken dum biryanis, Champaran handi mutton, butter chicken, four breads and four gulab jamun.',
 'menu-images/products/family-feast-thumb.jpg', 'menu-images/products/family-feast.jpg',
 'NON_VEG', 'MEDIUM', array['dairy','nuts','gluten'], array['high-protein'],
 1299, 1699, 40, '22222222-0000-0000-0000-000000000001', 45, 4, 4200,
 true, true, false, true, true, 2, 3,
 array['family pack','feast','combo','party','bulk'],
 'Family Feast Box | Bites Box', 'Family combo for four with biryani, mutton and chicken.'),

('55555555-0000-0000-0000-0000000000b2', '33333333-0000-0000-0000-00000000000b', null,
 'Veg Thali Box', 'veg-thali-box',
 'Paneer, dal, rice, two rotis and dessert',
 'A balanced vegetarian thali: paneer butter masala, dal tadka, steamed rice, two tandoori rotis and gulab jamun.',
 'menu-images/products/veg-thali-thumb.jpg', 'menu-images/products/veg-thali.jpg',
 'VEG', 'MILD', array['dairy','nuts','gluten'], array['vegetarian'],
 279, 349, 20, '22222222-0000-0000-0000-000000000001', 25, 1, 980,
 true, false, false, true, true, 3, 6,
 array['thali','veg thali','combo','meal box','vegetarian'],
 'Veg Thali Box | Bites Box', 'Complete vegetarian thali box.');

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIANTS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.product_variants (
  product_id, name, option_group, sku, price, compare_price, calories,
  serves_count, preparation_minutes, is_default, display_order
) values
  -- Chicken Dum Biryani
  ('55555555-0000-0000-0000-000000000001', 'Half (Serves 1)',  'Portion', 'BIR-CHK-H', 249, 299, 720, 1, 25, true,  1),
  ('55555555-0000-0000-0000-000000000001', 'Full (Serves 2)',  'Portion', 'BIR-CHK-F', 449, 529, 1400, 2, 28, false, 2),
  ('55555555-0000-0000-0000-000000000001', 'Family (Serves 4)','Portion', 'BIR-CHK-X', 849, 999, 2800, 4, 35, false, 3),
  -- Mutton Dum Biryani
  ('55555555-0000-0000-0000-000000000002', 'Half (Serves 1)',  'Portion', 'BIR-MTN-H', 379, 449, 850, 1, 35, true,  1),
  ('55555555-0000-0000-0000-000000000002', 'Full (Serves 2)',  'Portion', 'BIR-MTN-F', 699, 819, 1650, 2, 38, false, 2),
  -- Subz Biryani
  ('55555555-0000-0000-0000-000000000003', 'Half (Serves 1)',  'Portion', 'BIR-VEG-H', 199, 239, 610, 1, 22, true,  1),
  ('55555555-0000-0000-0000-000000000003', 'Full (Serves 2)',  'Portion', 'BIR-VEG-F', 349, 419, 1200, 2, 25, false, 2),
  -- Tandoori Chicken
  ('55555555-0000-0000-0000-000000000010', 'Half (2 pcs)',     'Portion', 'TAN-CHK-H', 279, 329, 480, 2, 28, true,  1),
  ('55555555-0000-0000-0000-000000000010', 'Full (4 pcs)',     'Portion', 'TAN-CHK-F', 529, 619, 960, 4, 32, false, 2),
  -- Bihari Chicken Masala
  ('55555555-0000-0000-0000-000000000011', 'Half (Serves 2)',  'Portion', 'CUR-CHK-H', 269, null, 520, 2, 25, true,  1),
  ('55555555-0000-0000-0000-000000000011', 'Full (Serves 4)',  'Portion', 'CUR-CHK-F', 499, null, 1040, 4, 30, false, 2),
  -- Butter Chicken
  ('55555555-0000-0000-0000-000000000012', 'Half (Serves 2)',  'Portion', 'BUT-CHK-H', 299, 349, 640, 2, 25, true,  1),
  ('55555555-0000-0000-0000-000000000012', 'Full (Serves 4)',  'Portion', 'BUT-CHK-F', 549, 649, 1280, 4, 30, false, 2),
  -- Chicken Tikka
  ('55555555-0000-0000-0000-000000000013', '6 pieces',         'Portion', 'TIK-CHK-6', 249, null, 420, 1, 22, true,  1),
  ('55555555-0000-0000-0000-000000000013', '12 pieces',        'Portion', 'TIK-CHK-12', 469, null, 840, 2, 26, false, 2),
  -- Champaran Handi Mutton
  ('55555555-0000-0000-0000-000000000020', 'Half (Serves 2)',  'Portion', 'CHP-MTN-H', 449, 529, 760, 2, 40, true,  1),
  ('55555555-0000-0000-0000-000000000020', 'Full (Serves 4)',  'Portion', 'CHP-MTN-F', 849, 989, 1520, 4, 45, false, 2),
  -- Mutton Curry
  ('55555555-0000-0000-0000-000000000021', 'Half (Serves 2)',  'Portion', 'CUR-MTN-H', 399, null, 690, 2, 35, true,  1),
  ('55555555-0000-0000-0000-000000000021', 'Full (Serves 4)',  'Portion', 'CUR-MTN-F', 749, null, 1380, 4, 40, false, 2),
  -- Chilli Chicken
  ('55555555-0000-0000-0000-000000000042', 'Dry',              'Style',   'CHL-CHK-D', 229, null, 540, 1, 18, true,  1),
  ('55555555-0000-0000-0000-000000000042', 'Gravy',            'Style',   'CHL-CHK-G', 249, null, 580, 1, 20, false, 2),
  -- Veg Manchurian
  ('55555555-0000-0000-0000-000000000043', 'Dry',              'Style',   'MAN-VEG-D', 169, null, 470, 1, 16, true,  1),
  ('55555555-0000-0000-0000-000000000043', 'Gravy',            'Style',   'MAN-VEG-G', 189, null, 510, 1, 18, false, 2),
  -- Paneer Butter Masala
  ('55555555-0000-0000-0000-000000000060', 'Half (Serves 2)',  'Portion', 'PBM-H', 239, 279, 560, 2, 20, true,  1),
  ('55555555-0000-0000-0000-000000000060', 'Full (Serves 4)',  'Portion', 'PBM-F', 439, 519, 1120, 4, 24, false, 2),
  -- Dal Tadka
  ('55555555-0000-0000-0000-000000000061', 'Half (Serves 2)',  'Portion', 'DAL-H', 129, null, 320, 2, 15, true,  1),
  ('55555555-0000-0000-0000-000000000061', 'Full (Serves 4)',  'Portion', 'DAL-F', 229, null, 640, 4, 18, false, 2),
  -- Litti Chokha
  ('55555555-0000-0000-0000-0000000000a0', '4 pieces',         'Portion', 'LIT-4', 149, 179, 620, 1, 20, true,  1),
  ('55555555-0000-0000-0000-0000000000a0', '6 pieces',         'Portion', 'LIT-6', 209, 249, 930, 2, 24, false, 2),
  ('55555555-0000-0000-0000-0000000000a0', '8 pieces',         'Portion', 'LIT-8', 269, 319, 1240, 3, 28, false, 3),
  -- Coca-Cola
  ('55555555-0000-0000-0000-000000000080', '250 ml',           'Size',    'COK-250', 40, null, 140, 1, 2, true,  1),
  ('55555555-0000-0000-0000-000000000080', '600 ml',           'Size',    'COK-600', 70, null, 300, 2, 2, false, 2),
  ('55555555-0000-0000-0000-000000000080', '1.25 L',           'Size',    'COK-1250', 95, null, 620, 4, 2, false, 3),
  -- Sweet Lassi
  ('55555555-0000-0000-0000-000000000081', 'Regular (300 ml)', 'Size',    'LAS-R', 60, null, 220, 1, 5, true,  1),
  ('55555555-0000-0000-0000-000000000081', 'Large (500 ml)',   'Size',    'LAS-L', 90, null, 360, 1, 5, false, 2),
  -- Hakka Noodles
  ('55555555-0000-0000-0000-000000000040', 'Regular',          'Portion', 'NOO-CHK-R', 179, null, 580, 1, 15, true,  1),
  ('55555555-0000-0000-0000-000000000040', 'Large',            'Portion', 'NOO-CHK-L', 269, null, 870, 2, 18, false, 2),
  -- Veg Fried Rice
  ('55555555-0000-0000-0000-000000000041', 'Regular',          'Portion', 'FRR-VEG-R', 149, null, 520, 1, 14, true,  1),
  ('55555555-0000-0000-0000-000000000041', 'Large',            'Portion', 'FRR-VEG-L', 229, null, 790, 2, 16, false, 2);

-- ═══════════════════════════════════════════════════════════════════════════
-- PRODUCT ⇄ MODIFIER GROUP WIRING
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.product_modifier_groups (product_id, modifier_group_id, display_order)
select p.id, '44444444-0000-0000-0000-000000000001', 1
from public.products p
where p.slug in (
  'chicken-dum-biryani','mutton-dum-biryani','subz-handi-biryani','egg-biryani',
  'bihari-chicken-masala','butter-chicken','tandoori-chicken','chicken-tikka',
  'champaran-handi-mutton','mutton-curry','chilli-chicken','veg-manchurian',
  'chicken-hakka-noodles','veg-fried-rice','paneer-butter-masala','dal-tadka',
  'chicken-tikka-roll','egg-chicken-roll','paneer-tikka-roll',
  'chicken-seekh-kebab','paneer-tikka','litti-chokha','aloo-chokha-rice'
);

insert into public.product_modifier_groups (product_id, modifier_group_id, display_order)
select p.id, '44444444-0000-0000-0000-000000000003', 2
from public.products p
where p.slug in ('chicken-dum-biryani','mutton-dum-biryani','subz-handi-biryani','egg-biryani');

insert into public.product_modifier_groups (product_id, modifier_group_id, display_order)
select p.id, '44444444-0000-0000-0000-000000000004', 2
from public.products p
where p.slug in ('chicken-tikka-roll','egg-chicken-roll','paneer-tikka-roll');

insert into public.product_modifier_groups (product_id, modifier_group_id, display_order)
select p.id, '44444444-0000-0000-0000-000000000007', 2
from public.products p
where p.slug in ('bihari-chicken-masala','mutton-curry','paneer-butter-masala');

insert into public.product_modifier_groups (product_id, modifier_group_id, display_order)
select p.id, '44444444-0000-0000-0000-000000000002', 5
from public.products p
where p.slug in (
  'chicken-dum-biryani','mutton-dum-biryani','subz-handi-biryani','bihari-chicken-masala',
  'butter-chicken','champaran-handi-mutton','mutton-curry','paneer-butter-masala',
  'dal-tadka','litti-chokha','tandoori-chicken'
);

insert into public.product_modifier_groups (product_id, modifier_group_id, display_order)
select p.id, '44444444-0000-0000-0000-000000000005', 8
from public.products p
where p.category_id in (
  '33333333-0000-0000-0000-000000000001','33333333-0000-0000-0000-000000000002',
  '33333333-0000-0000-0000-000000000003','33333333-0000-0000-0000-000000000004',
  '33333333-0000-0000-0000-000000000005','33333333-0000-0000-0000-000000000006',
  '33333333-0000-0000-0000-000000000007'
);

insert into public.product_modifier_groups (product_id, modifier_group_id, is_required, min_select, max_select, display_order)
select p.id, '44444444-0000-0000-0000-000000000006', true, 1, 1, 2
from public.products p
where p.slug in ('veg-thali-box','family-feast-box');

insert into public.product_modifier_groups (product_id, modifier_group_id, is_required, min_select, max_select, display_order)
select p.id, '44444444-0000-0000-0000-000000000008', true, 1, 1, 3
from public.products p
where p.slug in ('solo-biryani-combo','family-feast-box');

insert into public.product_modifier_groups (product_id, modifier_group_id, display_order)
select p.id, '44444444-0000-0000-0000-000000000009', 6
from public.products p
where p.slug in ('chicken-dum-biryani','mutton-dum-biryani','subz-handi-biryani');

-- ═══════════════════════════════════════════════════════════════════════════
-- SCHEDULED AVAILABILITY (breakfast items only until 11:30)
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.product_schedules (product_id, label, day_part, days_of_week, starts_at, ends_at)
select p.id, 'Breakfast service', 'BREAKFAST', '{0,1,2,3,4,5,6}', '08:00', '11:30'
from public.products p
where p.slug in ('sattu-paratha','poori-sabzi');

-- Litti chokha is a Bihar staple — available all day.
insert into public.product_schedules (product_id, label, day_part, days_of_week, starts_at, ends_at)
select p.id, 'All day', 'ALL_DAY', '{0,1,2,3,4,5,6}', '08:00', '23:00'
from public.products p where p.slug = 'litti-chokha';

-- ═══════════════════════════════════════════════════════════════════════════
-- PRODUCT IMAGES
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.product_images (product_id, storage_path, alt_text, width, height, variants, is_primary, display_order)
select
  p.id,
  p.hero_image_path,
  p.name || ' — Bites Box',
  1600, 1200,
  jsonb_build_object(
    'thumb', replace(p.hero_image_path, '.jpg', '-320.webp'),
    'medium', replace(p.hero_image_path, '.jpg', '-800.webp'),
    'large', replace(p.hero_image_path, '.jpg', '-1600.webp')
  ),
  true, 1
from public.products p
where p.hero_image_path is not null;

-- ═══════════════════════════════════════════════════════════════════════════
-- COLLECTIONS
-- ═══════════════════════════════════════════════════════════════════════════
insert into public.collections (id, name, slug, description, rule, display_order) values
  ('66666666-0000-0000-0000-000000000001', 'Under ₹199', 'under-199',
   'Great food that stays light on the wallet.', '{"max_price": 199}'::jsonb, 1),
  ('66666666-0000-0000-0000-000000000002', 'Bihari Specials', 'bihari-specials',
   'The dishes Bihar is famous for.', '{}'::jsonb, 2),
  ('66666666-0000-0000-0000-000000000003', 'Pure Veg', 'pure-veg',
   'Entirely vegetarian, cooked separately.', '{}'::jsonb, 3);

insert into public.collection_products (collection_id, product_id, display_order)
select '66666666-0000-0000-0000-000000000002', p.id, row_number() over (order by p.display_order)
from public.products p
where p.slug in ('litti-chokha','champaran-handi-mutton','bihari-chicken-masala',
                 'sattu-paratha','aloo-chokha-rice','poori-sabzi');

insert into public.collection_products (collection_id, product_id, display_order)
select '66666666-0000-0000-0000-000000000003', p.id, row_number() over (order by p.display_order)
from public.products p
where p.food_type = 'VEG';

insert into public.collection_products (collection_id, product_id, display_order)
select '66666666-0000-0000-0000-000000000001', p.id, row_number() over (order by p.base_price)
from public.products p
where p.base_price <= 199;
