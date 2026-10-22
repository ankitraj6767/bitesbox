-- Replace duplicated/legacy menu artwork with the versioned, per-product photos.
-- A new object prefix avoids stale CDN responses for the old shared files.
-- This can match zero rows during a fresh migration run; the menu seed uses these same paths.
begin;

update public.products
set thumbnail_path = 'menu-images/products/food-v2/' || slug || '-thumb.jpg',
    hero_image_path = 'menu-images/products/food-v2/' || slug || '.jpg'
where deleted_at is null
  and slug = any (array[
    'aloo-chokha-rice',
    'bihari-chicken-masala',
    'butter-chicken',
    'butter-naan',
    'champaran-handi-mutton',
    'chicken-dum-biryani',
    'chicken-hakka-noodles',
    'chicken-seekh-kebab',
    'chicken-tikka',
    'chicken-tikka-roll',
    'chilli-chicken',
    'coca-cola',
    'dal-tadka',
    'egg-biryani',
    'egg-chicken-roll',
    'family-feast-box',
    'gulab-jamun',
    'laccha-paratha',
    'litti-chokha',
    'masala-chaas',
    'mutton-curry',
    'mutton-dum-biryani',
    'onion-pakoda',
    'packaged-water-1l',
    'paneer-butter-masala',
    'paneer-tikka',
    'paneer-tikka-roll',
    'poori-sabzi',
    'rice-kheer',
    'sattu-paratha',
    'solo-biryani-combo',
    'subz-handi-biryani',
    'sweet-lassi',
    'tandoori-chicken',
    'tandoori-roti',
    'veg-fried-rice',
    'veg-manchurian',
    'veg-thali-box'
  ]::text[]);

update public.product_images as image
set storage_path = product.hero_image_path,
    alt_text = product.name || ' — Bites Box',
    width = 1024,
    height = 1024,
    variants = jsonb_build_object(
      'thumb', product.thumbnail_path,
      'medium', product.hero_image_path,
      'large', product.hero_image_path
    ),
    updated_at = now()
from public.products as product
where image.product_id = product.id
  and image.is_primary
  and product.deleted_at is null
  and product.slug = any (array[
    'aloo-chokha-rice',
    'bihari-chicken-masala',
    'butter-chicken',
    'butter-naan',
    'champaran-handi-mutton',
    'chicken-dum-biryani',
    'chicken-hakka-noodles',
    'chicken-seekh-kebab',
    'chicken-tikka',
    'chicken-tikka-roll',
    'chilli-chicken',
    'coca-cola',
    'dal-tadka',
    'egg-biryani',
    'egg-chicken-roll',
    'family-feast-box',
    'gulab-jamun',
    'laccha-paratha',
    'litti-chokha',
    'masala-chaas',
    'mutton-curry',
    'mutton-dum-biryani',
    'onion-pakoda',
    'packaged-water-1l',
    'paneer-butter-masala',
    'paneer-tikka',
    'paneer-tikka-roll',
    'poori-sabzi',
    'rice-kheer',
    'sattu-paratha',
    'solo-biryani-combo',
    'subz-handi-biryani',
    'sweet-lassi',
    'tandoori-chicken',
    'tandoori-roti',
    'veg-fried-rice',
    'veg-manchurian',
    'veg-thali-box'
  ]::text[]);

commit;
