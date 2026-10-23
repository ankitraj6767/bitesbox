-- Use a clean white canvas across customer, kitchen and delivery pages.
-- Only replace known defaults so a deliberate operator colour is preserved.
update public.settings
set value = '"#FFFFFF"'::jsonb
where key = 'brand.color_background'
  and value in ('"#F3F3F5"'::jsonb, '"#FFFBF6"'::jsonb);
