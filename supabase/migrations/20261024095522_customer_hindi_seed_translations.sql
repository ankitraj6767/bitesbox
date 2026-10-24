-- Localized search suggestions use the same catalog translations as the
-- catalog, detail, home feed and search result surfaces.
alter table public.coupons add column if not exists terms_hi text;

create or replace function public.localized_search_suggestions(
  p_branch_id uuid default null,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb := public.search_suggestions(p_branch_id);
begin
  if p_locale <> 'hi' then
    return v_result;
  end if;

  return jsonb_set(
    v_result,
    '{popular_products}',
    coalesce((
      select jsonb_agg(
        jsonb_set(product.value, '{name}', to_jsonb(coalesce(p.name_hi, p.name)), true)
        order by product.ordinality
      )
      from jsonb_array_elements(coalesce(v_result -> 'popular_products', '[]'::jsonb))
        with ordinality as product(value, ordinality)
      left join public.products p on p.id = (product.value ->> 'id')::uuid
    ), '[]'::jsonb),
    true
  );
end;
$$;

revoke all on function public.localized_search_suggestions(uuid,text) from public;
grant execute on function public.localized_search_suggestions(uuid,text) to anon, authenticated;

create or replace function public.public_storefront_offers(
  p_branch_id uuid default null,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.default_branch_id());
begin
  if not exists (
    select 1 from public.branches b
    where b.id = v_branch and b.is_active and b.deleted_at is null
  ) then
    perform app.fail('BRANCH_UNAVAILABLE', 'This outlet is not available.');
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id,
      'code', c.code,
      'title', case when p_locale = 'hi' then coalesce(c.title_hi, c.title) else c.title end,
      'description', case when p_locale = 'hi' then coalesce(c.description_hi, c.description) else c.description end,
      'terms', case when p_locale = 'hi' then coalesce(c.terms_hi, c.terms) else c.terms end,
      'discount_kind', c.discount_kind,
      'discount_value', c.discount_value,
      'min_order_amount', c.min_order_amount,
      'max_discount_amount', c.max_discount_amount,
      'ends_at', c.ends_at
    ) order by c.created_at desc)
    from public.coupons c
    where c.is_active and c.is_visible and c.deleted_at is null
      and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())
      and (c.branch_id is null or c.branch_id = v_branch)
  ), '[]'::jsonb);
end;
$$;

create or replace function public.localized_available_coupons(
  p_branch_id uuid default null,
  p_locale text default 'en'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb := public.available_coupons(p_branch_id);
  v_item jsonb;
  v_title text;
  v_description text;
  v_terms text;
begin
  if p_locale <> 'hi' then return v_result; end if;
  for v_item in select value from jsonb_array_elements(coalesce(v_result, '[]'::jsonb)) loop
    select c.title_hi, c.description_hi, c.terms_hi
      into v_title, v_description, v_terms
    from public.coupons c where c.id = (v_item ->> 'id')::uuid;
    if v_title is not null then v_item := jsonb_set(v_item, '{title}', to_jsonb(v_title), true); end if;
    if v_description is not null then v_item := jsonb_set(v_item, '{description}', to_jsonb(v_description), true); end if;
    if v_terms is not null then v_item := jsonb_set(v_item, '{terms}', to_jsonb(v_terms), true); end if;
    v_result := (
      select jsonb_agg(case when item ->> 'id' = v_item ->> 'id' then v_item else item end)
      from jsonb_array_elements(v_result) as elements(item)
    );
  end loop;
  return coalesce(v_result, '[]'::jsonb);
end;
$$;

revoke all on function public.public_storefront_offers(uuid,text) from public;
grant execute on function public.public_storefront_offers(uuid,text) to anon, authenticated;
revoke all on function public.localized_available_coupons(uuid,text) from public, anon;
grant execute on function public.localized_available_coupons(uuid,text) to authenticated;
-- Human-reviewed Hindi catalog content used by every locale-aware customer
-- menu surface. Keep this seed in sync with the matching production migration.

update public.categories as c
set name_hi = t.name_hi,
    short_description_hi = t.short_description_hi,
    description_hi = t.description_hi
from (values
  ('biryani', 'बिरयानी', 'केसरिया चावल और धीमी आँच पर पकी हांडी की दम बिरयानी', 'हमारी खास दम बिरयानी सीलबंद हांडियों में पुराने बासमती चावल, साबुत मसालों और केसर के दूध की परतों के साथ धीमी आँच पर पकती है, ताकि हर दाना खिला रहे।'),
  ('chicken', 'चिकन', 'तंदूरी, करी और बिहारी अंदाज़ का चिकन', 'धुएँ की खुशबू वाले तंदूरी चिकन से लेकर सरसों के तेल में पकी गाढ़ी बिहारी चिकन करी तक।'),
  ('mutton', 'मटन', 'धीमी आँच पर पका चंपारण और रोगन अंदाज़ का मटन', 'नरम बकरे का मांस बिहारी अंदाज़ में पकाया जाता है — चंपारण हांडी मटन और स्वादिष्ट करी के रूप में।'),
  ('rolls-and-wraps', 'रोल और रैप', 'भरपूर स्टफ़िंग वाले परतदार पराठा रोल', 'तंदूरी भरावन को पुदीने की चटनी और प्याज़ के साथ ताज़े पराठे में लपेटकर बनाया गया।'),
  ('chinese', 'चाइनीज़', 'कड़ाही में तेज़ आँच पर बने पसंदीदा इंडो-चाइनीज़ व्यंजन', 'तेज़ आँच पर वॉक में बने नूडल्स, फ्राइड राइस, चिली और मंचूरियन।'),
  ('starters', 'स्टार्टर', 'शुरुआत के लिए तंदूर और कुरकुरे स्नैक्स', 'तंदूर से सीधे परोसे गए कबाब, टिक्का और कुरकुरे स्टार्टर।'),
  ('rice-and-curries', 'चावल और करी', 'घर जैसे चावल और थाली वाली करी', 'रोज़मर्रा का बिहारी स्वाद — दाल, सब्ज़ी और करी, भाप में पके चावल के साथ।'),
  ('breads', 'रोटियाँ', 'तंदूरी रोटी, नान और पराठे', 'मिट्टी के तंदूर से ताज़ा निकली रोटियाँ, ऊपर से मक्खन लगी हुई।'),
  ('beverages', 'पेय', 'ठंडे पेय, लस्सी और ताज़ा कूलर', 'सॉफ्ट ड्रिंक, मीठी या नमकीन लस्सी और मौसम के ताज़ा कूलर।'),
  ('desserts', 'मिठाइयाँ', 'बिहारी मिठाइयाँ और ठंडी मीठी डिश', 'खाजा और गुलाब जामुन जैसे पारंपरिक स्वाद, साथ में ठंडी खीर।'),
  ('combos-and-meals', 'कॉम्बो और मील', 'एक व्यक्ति, दो लोगों या पूरे परिवार के लिए वैल्यू मील बॉक्स', 'पूरे मील बॉक्स में मुख्य व्यंजन के साथ रोटी, चावल और पेय का स्वाद लें।'),
  ('breakfast', 'नाश्ता', 'लिट्टी चोखा, पूरी सब्ज़ी और सुबह के पसंदीदा स्वाद', 'बिहार की सुबह लिट्टी चोखा, सत्तू पराठे और गरमा-गरम पूरी सब्ज़ी से शुरू होती है।')
) as t(slug, name_hi, short_description_hi, description_hi)
where c.slug = t.slug;

update public.subcategories as sc
set name_hi = t.name_hi,
    description_hi = t.description_hi
from (values
  ('chicken-biryani', 'चिकन बिरयानी', 'चिकन के साथ धीमी आँच पर पकी दम बिरयानी।'),
  ('mutton-biryani', 'मटन बिरयानी', 'मसालों और बासमती चावल में पका नरम मटन।'),
  ('veg-biryani', 'वेज बिरयानी', 'मौसमी सब्ज़ियों और सुगंधित चावल की दम बिरयानी।'),
  ('tandoori', 'तंदूरी', 'तंदूर में भुने और धुएँ की खुशबू वाले व्यंजन।'),
  ('curry', 'करी', 'मसालेदार करी और घर जैसे स्वाद।'),
  ('noodles', 'नूडल्स', 'तेज़ आँच पर वॉक में बने नूडल्स।'),
  ('chinese-rice', 'चाइनीज़ राइस', 'सब्ज़ियों और मसालों के साथ वॉक में बना चावल।'),
  ('chinese-gravy', 'चाइनीज़ ग्रेवी', 'इंडो-चाइनीज़ अंदाज़ की गाढ़ी ग्रेवी वाले व्यंजन।'),
  ('veg-starters', 'वेज स्टार्टर', 'शुरुआत के लिए शाकाहारी स्नैक्स।'),
  ('non-veg-starters', 'नॉन-वेज स्टार्टर', 'तंदूर और कड़ाही से बने स्वादिष्ट नॉन-वेज स्नैक्स।')
) as t(slug, name_hi, description_hi)
where sc.slug = t.slug;

update public.products as p
set name_hi = t.name_hi,
    short_description_hi = t.short_description_hi,
    description_hi = t.description_hi
from (values
  ('chicken-dum-biryani', 'चिकन दम बिरयानी', 'केसरिया चावल और नरम चिकन वाली सीलबंद हांडी बिरयानी', 'पुराने बासमती चावल की परतों में मसालेदार चिकन, सुनहरा भुना प्याज़, पुदीना और केसर का दूध। सीलबंद हांडी में धीमी दम पर पकाई जाती है। बूंदी रायता और मिर्ची का सालन साथ परोसा जाता है।'),
  ('mutton-dum-biryani', 'मटन दम बिरयानी', 'बासमती और साबुत मसालों में धीमी आँच पर पका बकरे का मांस', 'नरम बकरे के मांस को दही और बिहारी मसालों में रात भर मेरिनेट करके बासमती चावल के साथ दम पर पकाया जाता है, जब तक मांस हड्डी से आसानी से अलग न हो जाए।'),
  ('subz-handi-biryani', 'सब्ज़ हांडी बिरयानी', 'मौसमी सब्ज़ियाँ और पनीर केसरिया चावल के साथ दम पर पके', 'ताज़ी सब्ज़ियों, पनीर और काजू की परतों को खुशबूदार बासमती चावल के साथ दम पर पकाकर ऊपर से कुरकुरे तले प्याज़ डाले जाते हैं।'),
  ('egg-biryani', 'अंडा बिरयानी', 'मसालेदार उबले अंडों के साथ केसरिया दम बिरयानी', 'खुशबूदार दम चावल के साथ मसाले में लिपटे दो उबले अंडे और सुनहरा भुना प्याज़ परोसा जाता है।'),
  ('tandoori-chicken', 'तंदूरी चिकन', 'दही और कश्मीरी मिर्च में मेरिनेट चिकन, कोयले पर भुना', 'लटका हुआ दही, अदरक-लहसुन और कश्मीरी मिर्च में रात भर मेरिनेट करके कोयले पर भुना जाता है, जिससे बाहर धुएँ की खुशबू वाली परत बनती है। पुदीने की चटनी और प्याज़ के छल्लों के साथ परोसा जाता है।'),
  ('bihari-chicken-masala', 'बिहारी चिकन मसाला', 'बिहार के अंदाज़ में सरसों के तेल की चिकन करी', 'चिकन को सरसों के तेल, प्याज़, साबुत मसालों और पंचफोरन की हल्की खुशबू के साथ धीमी आँच पर पकाया जाता है। इसका देसी, भरपूर स्वाद तंदूरी रोटी के साथ खूब जंचता है।'),
  ('butter-chicken', 'बटर चिकन', 'मक्खन और टमाटर की मुलायम ग्रेवी में तंदूरी चिकन', 'कोयले पर भुने तंदूरी चिकन को मलाईदार टमाटर, काजू और मक्खन की ग्रेवी में पकाकर क्रीम और कसूरी मेथी से सजाया जाता है।'),
  ('chicken-tikka', 'चिकन टिक्का', 'बिना हड्डी के चिकन के रसीले, धुएँ की खुशबू वाले टुकड़े', 'बिना हड्डी के चिकन को मसालेदार लटके दही में मेरिनेट करके सीख पर लगाकर तंदूर में भुना जाता है।'),
  ('champaran-handi-mutton', 'चंपारण हांडी मटन', 'सीलबंद मिट्टी की हांडी में पका बिहार का मशहूर मटन', 'यह चंपारण का खास स्वाद है। बकरे का मांस, सरसों का तेल, लहसुन और साबुत मसालों को मिट्टी की हांडी में भरकर आटे से सील किया जाता है और धीमी आँच पर पकाया जाता है।'),
  ('mutton-curry', 'मटन करी', 'प्याज़-टमाटर के मसाले वाली घर जैसी बकरे के मांस की करी', 'रोज़मर्रा की मटन करी को नरम होने तक पकाया जाता है। इसकी हल्की मसालेदार ग्रेवी चावल के साथ बेहतरीन लगती है।'),
  ('chicken-tikka-roll', 'चिकन टिक्का रोल', 'धुएँ की खुशबू वाले चिकन टिक्के को परतदार पराठे में लपेटा', 'परतदार पराठे में तंदूरी चिकन टिक्का, प्याज़, हरी चटनी और नींबू का रस भरकर रोल बनाया जाता है।'),
  ('egg-chicken-roll', 'एग चिकन रोल', 'अंडे में लिपटा पराठा, चिकन और प्याज़ के साथ', 'पराठे पर अंडे की परत लगाकर कुरकुरा किया जाता है और उसमें चिकन, प्याज़ और चटनी भरी जाती है।'),
  ('paneer-tikka-roll', 'पनीर टिक्का रोल', 'परतदार पराठे में लिपटा तंदूरी पनीर', 'मसाले में मेरिनेट पनीर के टुकड़ों को तंदूर में भूनकर शिमला मिर्च, प्याज़ और पुदीने की चटनी के साथ रोल किया जाता है।'),
  ('chicken-hakka-noodles', 'चिकन हक्का नूडल्स', 'कटी सब्ज़ियों और चिकन के साथ वॉक में भुने नूडल्स', 'तेज़ आँच पर वॉक में नूडल्स और पतली कटी सब्ज़ियों को चिकन, सोया सॉस और थोड़े सिरके के साथ भुना जाता है।'),
  ('veg-fried-rice', 'वेज फ्राइड राइस', 'कुरकुरी ताज़ी सब्ज़ियों के साथ वॉक में भुना चावल', 'लंबे दाने वाले चावल को तेज़ आँच पर गाजर, बीन्स, पत्तागोभी, हरे प्याज़ और सोया सॉस के साथ भुना जाता है।'),
  ('chilli-chicken', 'चिली चिकन', 'कुरकुरे चिकन पर तीखी सोया-चिली सॉस', 'तले हुए चिकन को प्याज़, शिमला मिर्च और हरी मिर्च के साथ चमकदार सोया-चिली सॉस में टॉस किया जाता है।'),
  ('veg-manchurian', 'वेज मंचूरियन', 'खट्टी-मीठी मंचूरियन सॉस में कुरकुरे सब्ज़ी बॉल', 'हाथ से बनी सब्ज़ियों की बॉल को कुरकुरा तलकर लहसुन वाली खट्टी-मीठी सॉस में पकाया जाता है।'),
  ('chicken-seekh-kebab', 'चिकन सीख कबाब', 'सीख पर भुने मसालेदार चिकन कबाब', 'अदरक, धनिया और हरी मिर्च के साथ मसालेदार चिकन कीमा सीख पर लगाकर रसदार होने तक कोयले पर भुना जाता है।'),
  ('paneer-tikka', 'पनीर टिक्का', 'शिमला मिर्च के साथ तंदूर में भुना पनीर', 'मोटे पनीर के टुकड़ों को मसालेदार दही में मेरिनेट करके प्याज़ और शिमला मिर्च के साथ तंदूर में भुना जाता है।'),
  ('onion-pakoda', 'प्याज़ पकौड़ा', 'बेसन में लिपटे प्याज़ के कुरकुरे पकौड़े', 'कटे प्याज़ को मसालेदार बेसन के घोल में लपेटकर कुरकुरा तला जाता है — बारिश का पसंदीदा नाश्ता।'),
  ('paneer-butter-masala', 'पनीर बटर मसाला', 'टमाटर-काजू की गाढ़ी ग्रेवी में नरम पनीर', 'पनीर के टुकड़ों को मुलायम टमाटर और काजू की ग्रेवी में पकाकर मक्खन और क्रीम से सजाया जाता है।'),
  ('dal-tadka', 'दाल तड़का', 'घी और मसालों के तड़के वाली पीली दाल', 'अरहर दाल को धीमी आँच पर पकाकर जीरा, लहसुन और सूखी लाल मिर्च के घी वाले तड़के से तैयार किया जाता है।'),
  ('aloo-chokha-rice', 'आलू चोखा और चावल', 'धुएँ की खुशबू वाला आलू चोखा, भाप के चावल और घी के साथ', 'आग में भुने आलू को सरसों के तेल, प्याज़, लहसुन और हरी मिर्च के साथ मसलकर भाप में पके चावल के साथ परोसा जाता है।'),
  ('tandoori-roti', 'तंदूरी रोटी', 'मिट्टी के तंदूर में बनी गेहूँ की रोटी', 'हाथ से फैलाकर बनाई गेहूँ की रोटी को तंदूर की दीवार पर सेंका जाता है।'),
  ('butter-naan', 'बटर नान', 'मक्खन लगी नरम खमीर वाली नान', 'मैदे की नान को तंदूर में सेंककर ऊपर से भरपूर मक्खन लगाया जाता है।'),
  ('laccha-paratha', 'लच्छा पराठा', 'कई परतों वाला कुरकुरा पराठा', 'परतदार पराठे को तंदूर में तब तक सेंका जाता है, जब तक हर परत अलग और कुरकुरी न हो जाए।'),
  ('coca-cola', 'कोका-कोला', 'ठंडी कोका-कोला', 'ठंडा परोसा जाता है।'),
  ('sweet-lassi', 'मीठी लस्सी', 'गाढ़ी और ठंडी दही की लस्सी', 'ताज़े मथे दही में चीनी और इलायची की हल्की खुशबू मिलाकर ठंडा परोसा जाता है।'),
  ('masala-chaas', 'मसाला छाछ', 'भुने जीरे वाली मसालेदार छाछ', 'हल्की छाछ में भुना जीरा, काला नमक और ताज़ा धनिया मिलाया जाता है।'),
  ('packaged-water-1l', 'पैक्ड पीने का पानी 1 लीटर', 'सीलबंद 1 लीटर की बोतल', 'सीलबंद बोतल में पैक पीने का पानी।'),
  ('gulab-jamun', 'गुलाब जामुन (2 पीस)', 'इलायची की चाशनी में डूबे गरम दूध के गुलाब जामुन', 'खोए के गुलाब जामुन को सुनहरा तलकर गुलाब और इलायची की चाशनी में भिगोया जाता है।'),
  ('rice-kheer', 'चावल की खीर', 'मेवों के साथ धीमी आँच पर पकी खीर', 'फुल क्रीम दूध को चावल और इलायची के साथ गाढ़ा करके ऊपर से कटे बादाम डाले जाते हैं। ठंडी परोसी जाती है।'),
  ('litti-chokha', 'लिट्टी चोखा (4 पीस)', 'सत्तू भरी लिट्टी, धुएँ की खुशबू वाला चोखा और घी', 'बिहार का खास स्वाद। मसालेदार भुने चने के आटे से भरी गेहूँ की लिट्टी को कोयले पर सेंककर घी में डुबोया जाता है और बैंगन-टमाटर-आलू के चोखे के साथ परोसा जाता है।'),
  ('sattu-paratha', 'सत्तू पराठा (2 पीस)', 'अचार के साथ भुने चने के आटे से भरा पराठा', 'गेहूँ के पराठे में मसालेदार सत्तू भरकर घी में सेंका जाता है। आम के अचार और दही के साथ परोसा जाता है।'),
  ('poori-sabzi', 'पूरी सब्ज़ी', 'मसालेदार आलू की सब्ज़ी के साथ फूली हुई पूरी', 'बिहारी अंदाज़ की आलू सब्ज़ी और अचार के साथ छह गरमा-गरम पूरियाँ।'),
  ('solo-biryani-combo', 'सोलो बिरयानी कॉम्बो', 'चिकन बिरयानी + रायता + गुलाब जामुन + पेय', 'एक व्यक्ति के पूरे खाने में चिकन दम बिरयानी, बूंदी रायता, दो गुलाब जामुन और ठंडा पेय शामिल हैं।'),
  ('family-feast-box', 'फैमिली फीस्ट बॉक्स', '4 लोगों के लिए — बिरयानी, मटन, चिकन, रोटियाँ और मिठाई', 'पूरे परिवार की दावत: दो चिकन दम बिरयानी, चंपारण हांडी मटन, बटर चिकन, चार रोटियाँ और चार गुलाब जामुन।'),
  ('veg-thali-box', 'वेज थाली बॉक्स', 'पनीर, दाल, चावल, दो रोटियाँ और मिठाई', 'संतुलित शाकाहारी थाली में पनीर बटर मसाला, दाल तड़का, भाप के चावल, दो तंदूरी रोटी और गुलाब जामुन।')
) as t(slug, name_hi, short_description_hi, description_hi)
where p.slug = t.slug;

update public.modifier_groups as g
set name_hi = t.name_hi, description_hi = t.description_hi
from (values
  ('spice-level', 'तीखेपन का स्तर', 'आप कितना तीखा पसंद करेंगे?'),
  ('add-ons', 'अतिरिक्त चीज़ें', 'अपने खाने को और भरपूर बनाएँ।'),
  ('biryani-extras', 'बिरयानी के साथ', 'रायता, सालन और अतिरिक्त पीस चुनें।'),
  ('roll-fillings', 'रोल की स्टफ़िंग', 'अपने रोल में और भरावन जोड़ें।'),
  ('remove-ingredients', 'सामग्री हटाएँ', 'क्या आप कुछ सामग्री नहीं चाहते?'),
  ('bread-choice', 'रोटी चुनें', 'अपनी पसंद की रोटी चुनें।'),
  ('gravy-style', 'ग्रेवी का प्रकार', 'पकाने का अपना पसंदीदा अंदाज़ चुनें।'),
  ('drink-choice', 'पेय चुनें', 'शामिल पेय चुनें।'),
  ('toppings', 'टॉपिंग', 'पहली दो टॉपिंग हमारी ओर से।')
) as t(slug, name_hi, description_hi)
where g.slug = t.slug;

update public.modifiers as m
set name_hi = t.name_hi
from (values
  ('spice-level', 'Mild', 'कम तीखा'),
  ('spice-level', 'Medium', 'मध्यम तीखा'),
  ('spice-level', 'Bihari hot', 'बिहारी तीखा'),
  ('spice-level', 'Extra hot', 'बहुत तीखा'),
  ('add-ons', 'Extra gravy', 'अतिरिक्त ग्रेवी'),
  ('add-ons', 'Butter naan', 'बटर नान'),
  ('add-ons', 'Green salad', 'हरा सलाद'),
  ('add-ons', 'Masala papad', 'मसाला पापड़'),
  ('add-ons', 'Boiled egg', 'उबला अंडा'),
  ('add-ons', 'Gulab jamun (2)', 'गुलाब जामुन (2)'),
  ('biryani-extras', 'Boondi raita', 'बूंदी रायता'),
  ('biryani-extras', 'Mirchi ka salan', 'मिर्ची का सालन'),
  ('biryani-extras', 'Extra chicken leg', 'अतिरिक्त चिकन लेग पीस'),
  ('biryani-extras', 'Extra mutton pieces', 'अतिरिक्त मटन पीस'),
  ('biryani-extras', 'Extra rice portion', 'अतिरिक्त चावल'),
  ('roll-fillings', 'Extra chicken', 'अतिरिक्त चिकन'),
  ('roll-fillings', 'Extra cheese', 'अतिरिक्त चीज़'),
  ('roll-fillings', 'Double egg', 'दो अंडे'),
  ('roll-fillings', 'Extra onions', 'अतिरिक्त प्याज़'),
  ('remove-ingredients', 'No onion', 'प्याज़ न डालें'),
  ('remove-ingredients', 'No garlic', 'लहसुन न डालें'),
  ('remove-ingredients', 'No coriander', 'धनिया न डालें'),
  ('remove-ingredients', 'Less oil', 'कम तेल'),
  ('bread-choice', 'Tandoori roti (2)', 'तंदूरी रोटी (2)'),
  ('bread-choice', 'Butter naan (2)', 'बटर नान (2)'),
  ('bread-choice', 'Laccha paratha (1)', 'लच्छा पराठा (1)'),
  ('bread-choice', 'Steamed rice', 'भाप के चावल'),
  ('gravy-style', 'Bihari masala', 'बिहारी मसाला'),
  ('gravy-style', 'Butter gravy', 'मक्खन वाली ग्रेवी'),
  ('gravy-style', 'Kadhai style', 'कड़ाही अंदाज़'),
  ('drink-choice', 'Coca-Cola 250ml', 'कोका-कोला 250 मिली'),
  ('drink-choice', 'Sprite 250ml', 'स्प्राइट 250 मिली'),
  ('drink-choice', 'Sweet lassi', 'मीठी लस्सी'),
  ('drink-choice', 'Masala chaas', 'मसाला छाछ'),
  ('toppings', 'Fried onions', 'तले प्याज़'),
  ('toppings', 'Roasted cashew', 'भुने काजू'),
  ('toppings', 'Fresh coriander', 'ताज़ा धनिया'),
  ('toppings', 'Lemon wedge', 'नींबू की फाँक'),
  ('toppings', 'Green chutney', 'हरी चटनी')
) as t(group_slug, name, name_hi)
join public.modifier_groups g on g.slug = t.group_slug
where m.modifier_group_id = g.id and m.name = t.name;

update public.product_variants as v
set name_hi = t.name_hi,
    option_group_hi = case v.option_group
      when 'Portion' then 'मात्रा'
      when 'Style' then 'तैयारी'
      when 'Size' then 'आकार'
      else v.option_group
    end
from (values
  ('BIR-CHK-H', 'आधा (1 व्यक्ति के लिए)'), ('BIR-CHK-F', 'पूरा (2 लोगों के लिए)'), ('BIR-CHK-X', 'फैमिली (4 लोगों के लिए)'),
  ('BIR-MTN-H', 'आधा (1 व्यक्ति के लिए)'), ('BIR-MTN-F', 'पूरा (2 लोगों के लिए)'),
  ('BIR-VEG-H', 'आधा (1 व्यक्ति के लिए)'), ('BIR-VEG-F', 'पूरा (2 लोगों के लिए)'),
  ('TAN-CHK-H', 'आधा (2 पीस)'), ('TAN-CHK-F', 'पूरा (4 पीस)'),
  ('CUR-CHK-H', 'आधा (2 लोगों के लिए)'), ('CUR-CHK-F', 'पूरा (4 लोगों के लिए)'),
  ('BUT-CHK-H', 'आधा (2 लोगों के लिए)'), ('BUT-CHK-F', 'पूरा (4 लोगों के लिए)'),
  ('TIK-CHK-6', '6 पीस'), ('TIK-CHK-12', '12 पीस'),
  ('CHP-MTN-H', 'आधा (2 लोगों के लिए)'), ('CHP-MTN-F', 'पूरा (4 लोगों के लिए)'),
  ('CUR-MTN-H', 'आधा (2 लोगों के लिए)'), ('CUR-MTN-F', 'पूरा (4 लोगों के लिए)'),
  ('CHL-CHK-D', 'सूखा'), ('CHL-CHK-G', 'ग्रेवी वाला'),
  ('MAN-VEG-D', 'सूखा'), ('MAN-VEG-G', 'ग्रेवी वाला'),
  ('PBM-H', 'आधा (2 लोगों के लिए)'), ('PBM-F', 'पूरा (4 लोगों के लिए)'),
  ('DAL-H', 'आधा (2 लोगों के लिए)'), ('DAL-F', 'पूरा (4 लोगों के लिए)'),
  ('LIT-4', '4 पीस'), ('LIT-6', '6 पीस'), ('LIT-8', '8 पीस'),
  ('COK-250', '250 मिली'), ('COK-600', '600 मिली'), ('COK-1250', '1.25 लीटर'),
  ('LAS-R', 'रेगुलर (300 मिली)'), ('LAS-L', 'लार्ज (500 मिली)'),
  ('NOO-CHK-R', 'रेगुलर'), ('NOO-CHK-L', 'लार्ज'),
  ('FRR-VEG-R', 'रेगुलर'), ('FRR-VEG-L', 'लार्ज')
) as t(sku, name_hi)
where v.sku = t.sku;
-- Human-reviewed Hindi home, promotion and help content.
update public.cms_sections as s
set title_hi = t.title_hi,
    subtitle_hi = t.subtitle_hi,
    action_label_hi = t.action_label_hi
from (values
  ('categories', 'आज क्या खाने का मन है?', 'श्रेणी के अनुसार देखें', 'सभी देखें'),
  ('breakfast-now', 'सुप्रभात, बख्तियारपुर', 'लिट्टी चोखा और सुबह के पसंदीदा स्वाद', 'सभी देखें'),
  ('best-sellers', 'बख्तियारपुर के पसंदीदा', 'जो सभी ऑर्डर कर रहे हैं', 'सभी देखें'),
  ('offers', 'आपके लिए ऑफ़र', 'आज के ऑर्डर पर और बचत करें', 'सभी ऑफ़र'),
  ('buy-again', 'फिर से ऑर्डर करें', 'आपके हाल के पसंदीदा', null),
  ('biryani-rail', 'सीलबंद हांडी में धीमी आँच पर पकी बिरयानी', 'हमारी खास दम बिरयानी', 'सभी देखें'),
  ('combos', 'पूरे मील बॉक्स', 'एक ही बॉक्स में पूरा खाना', 'सभी देखें'),
  ('under-199', '₹199 से कम', 'कम खर्च में भरपूर स्वाद', 'सभी देखें'),
  ('bihari-specials', 'बिहार के रसोईघरों से सीधे', 'चंपारण मटन, लिट्टी चोखा और भी बहुत कुछ', 'सभी देखें'),
  ('popular-tonight', 'आज रात के लोकप्रिय व्यंजन', 'पिछले कुछ घंटों में सबसे ज़्यादा पसंद किए गए', null),
  ('new-arrivals', 'मेन्यू में नए व्यंजन', 'हमारी किचन से नई पेशकश', null),
  ('pure-veg', 'पूरी तरह शाकाहारी', 'अलग हिस्से में तैयार किया जाता है', 'सभी देखें'),
  ('top-rated', 'ग्राहकों की सबसे अच्छी रेटिंग वाले', 'ग्राहकों की सबसे ऊँची रेटिंग वाले व्यंजन', null)
) as t(section_key, title_hi, subtitle_hi, action_label_hi)
where s.section_key = t.section_key;

update public.cms_banners as b
set title_hi = t.title_hi,
    subtitle_hi = t.subtitle_hi,
    badge_text_hi = t.badge_text_hi,
    alt_text_hi = t.alt_text_hi
from (values
  ('Handi biryani, sealed & slow-cooked', 'सीलबंद हांडी में धीमी आँच पर पकी बिरयानी', 'पुराने बासमती चावल · केसर · 25 मिनट', 'खास', 'सीलबंद हांडी में चिकन दम बिरयानी'),
  ('Champaran mutton is here', 'चंपारण मटन आ गया है', 'बिहारी अंदाज़ में मिट्टी की हांडी का आहूना मटन', 'ज़रूर आज़माएँ', 'मिट्टी के बर्तन में चंपारण हांडी मटन'),
  ('Flat ₹75 off your first order', 'पहले ऑर्डर पर सीधे ₹75 की छूट', 'चेकआउट पर BITES75 कोड इस्तेमाल करें', 'नए ग्राहक', 'पहले ऑर्डर पर छूट का ऑफ़र'),
  ('Free delivery above ₹349', '₹349 से ऊपर मुफ़्त डिलीवरी', 'ज़ोन A · बख्तियारपुर शहर', null, 'मुफ़्त डिलीवरी का ऑफ़र'),
  ('Family Feast Box — serves 4', 'फैमिली फीस्ट बॉक्स — 4 लोगों के लिए', '₹1299 में बिरयानी, मटन, चिकन और रोटियाँ', '₹400 बचाएँ', 'परिवार के लिए फीस्ट कॉम्बो बॉक्स')
) as t(title, title_hi, subtitle_hi, badge_text_hi, alt_text_hi)
where b.title = t.title;

update public.coupons as c
set title_hi = t.title_hi,
    description_hi = t.description_hi,
    terms_hi = t.terms_hi
from (values
  ('BITES75', 'पहले ऑर्डर पर सीधे ₹75 की छूट', '₹299 से ऊपर के ऑर्डर पर ₹75 की छूट पाएँ।', 'पहले ऑर्डर पर प्रति ग्राहक एक बार मान्य। न्यूनतम ऑर्डर ₹299।'),
  ('BIRYANI20', 'सभी बिरयानी पर 20% की छूट', 'हर हांडी बिरयानी पर 20% बचाएँ, अधिकतम छूट ₹100।', 'केवल बिरयानी श्रेणी पर लागू। अधिकतम छूट ₹100।'),
  ('FREEDEL', 'आज रात मुफ़्त डिलीवरी', 'शाम 7 बजे के बाद ₹199 से ऊपर के ऑर्डर पर डिलीवरी शुल्क नहीं।', 'शाम 7 बजे से रात 11 बजे तक मान्य। केवल डिलीवरी ऑर्डर पर।'),
  ('WEEKEND100', '₹599 से ऊपर के ऑर्डर पर ₹100 की छूट', 'वीकेंड का तोहफ़ा — ₹599 से ऊपर के ऑर्डर पर सीधे ₹100 की छूट।', 'केवल शनिवार और रविवार को मान्य। न्यूनतम ऑर्डर ₹599।'),
  ('LITTI15', 'बिहारी खास व्यंजनों पर 15% की छूट', 'लिट्टी चोखा पर भी छूट तो बनती है।', 'नाश्ता श्रेणी पर लागू। अधिकतम छूट ₹50।'),
  ('PICKUP10', 'खुद आकर लेने पर 10% की छूट', 'आउटलेट से खाना लेकर जाएँ और 10% बचाएँ।', 'केवल सेल्फ पिकअप ऑर्डर पर। अधिकतम छूट ₹80।'),
  ('COMEBACK150', '₹150 की छूट — हमें आपकी याद आई', 'कुछ समय से ऑर्डर न करने वाले ग्राहकों के लिए वापसी का ऑफ़र।', 'पिछले 30 दिनों में कोई ऑर्डर न करने वाले ग्राहकों के लिए। न्यूनतम ऑर्डर ₹499।'),
  ('EXPIRED50', 'समाप्त परीक्षण कूपन', 'यह कूपन केवल परीक्षण के लिए है।', 'परीक्षण कूपन।')
) as t(code, title_hi, description_hi, terms_hi)
where c.code = t.code;

insert into public.cms_documents (kind, locale, title, body, version)
values
('ABOUT', 'hi', 'बाइट्स बॉक्स के बारे में',
'बाइट्स बॉक्स की शुरुआत बख्तियारपुर में एक सरल सोच के साथ हुई: बिहार का पसंदीदा खाना सही तरीके से पकाया जाए, सावधानी से पैक हो और गरमागरम पहुँचे।

हमारी किचन स्टेशन रोड पर, बख्तियारपुर जंक्शन से थोड़ी ही दूरी पर है। हम बिरयानी को सीलबंद हांडियों में पकाते हैं, लिट्टी को कोयले पर सेंकते हैं और चंपारण मटन को चंपारण के पारंपरिक तरीके से — मिट्टी के बर्तन में आटे से सील करके धीमी आँच पर — बनाते हैं।

हर व्यंजन ऑर्डर मिलने पर तैयार किया जाता है। कुछ भी पहले से प्लेट में नहीं रखा जाता। अगर कोई व्यंजन हमारे मानक पर खरा न उतरे, तो हम उसे भेजते नहीं हैं।', '1.0'),
('TERMS', 'hi', 'सेवा की शर्तें',
'बाइट्स बॉक्स पर ऑर्डर देकर आप इन शर्तों से सहमत होते हैं।

1. ऑर्डर
ऑर्डर की पुष्टि तभी होती है, जब भुगतान सत्यापित हो जाए या कैश ऑन डिलीवरी के मामले में रेस्टोरेंट ऑर्डर स्वीकार कर ले। कोई आइटम उपलब्ध न हो, डिलीवरी का पता हमारे सेवा क्षेत्र से बाहर हो या धोखाधड़ी का संदेह हो, तो हम ऑर्डर स्वीकार नहीं कर सकते।

2. कीमत
ऐप में दिखाई गई सभी कीमतों में लागू GST शामिल है। डिलीवरी शुल्क आपके डिलीवरी ज़ोन के अनुसार तय होता है और भुगतान से पहले दिखाया जाता है। देय राशि ऑर्डर देते समय हमारे सर्वर पर गणना की जाती है।

3. डिलीवरी
डिलीवरी का समय अनुमान है, गारंटी नहीं। ट्रैफ़िक, मौसम और किचन के काम का असर हो सकता है। ऑर्डर लेने और डिलीवरी OTP साझा करने के लिए पते पर किसी व्यक्ति का मौजूद होना ज़रूरी है।

4. रद्द करना
ऑर्डर रद्द करने के अधिकार इस बात पर निर्भर करते हैं कि ऑर्डर किस चरण में है। अधिक जानकारी के लिए हमारी रद्दीकरण नीति देखें।

5. खाद्य सुरक्षा
हमारी किचन में मेवे, डेयरी, ग्लूटेन और अंडे का इस्तेमाल होता है। हम एलर्जेन से पूरी तरह मुक्त खाना बनाने की गारंटी नहीं दे सकते। एलर्जी हो तो ऑर्डर से पहले हमें बताएँ।

6. व्यवहार
कूपन का दुरुपयोग करने, कैश ऑन डिलीवरी के फ़र्ज़ी ऑर्डर देने, बार-बार ऑर्डर रद्द करने या हमारे कर्मचारियों अथवा डिलीवरी पार्टनर के साथ दुर्व्यवहार करने वाले खातों को हम रोक सकते हैं।', '1.0'),
('PRIVACY', 'hi', 'गोपनीयता नीति',
'खाना पहुँचाने के लिए जितनी जानकारी ज़रूरी है, हम उतनी ही लेते हैं।

हम क्या लेते हैं
· आपका नाम और फ़ोन नंबर, ताकि हम आपकी पहचान कर सकें और ऑर्डर के बारे में संपर्क कर सकें।
· डिलीवरी के पते और लोकेशन, ताकि सेवा उपलब्धता जाँच सकें और आप तक पहुँच सकें।
· ऑर्डर का इतिहास, ताकि आप दोबारा ऑर्डर कर सकें और हम सहायता अनुरोधों में मदद कर सकें।
· डिवाइस की जानकारी और सूचना टोकन, ताकि ऑर्डर अपडेट भेज सकें।

हम इसका इस्तेमाल कैसे करते हैं
हम जानकारी का इस्तेमाल ऑर्डर पूरा करने, सहायता देने, धोखाधड़ी रोकने और — आपकी सहमति होने पर — ऑफ़र बताने के लिए करते हैं। हम आपका डेटा कभी नहीं बेचते।

हम किसके साथ साझा करते हैं
· आपका ऑर्डर सक्रिय रहने तक डिलीवरी पार्टनर आपका नाम, फ़ोन नंबर और पता देख सकता है।
· हमारा भुगतान प्रदाता Razorpay भुगतान प्रोसेस करता है। हम आपके कार्ड की जानकारी अपने पास नहीं रखते।
· हमारे SMS और पुश सूचना प्रदाता ऑर्डर की सूचनाएँ पहुँचाते हैं।

लोकेशन डेटा
सक्रिय डिलीवरी के दौरान ही डिलीवरी पार्टनर की लोकेशन आपको दिखाई जाती है। आपकी लोकेशन का इस्तेमाल केवल सेवा उपलब्धता जाँचने और डिलीवरी पता तय करने के लिए होता है।

आपके विकल्प
आप ऐप में अपनी प्रोफ़ाइल बदल सकते हैं, सहेजे हुए पते हटा सकते हैं और मार्केटिंग सूचनाएँ बंद कर सकते हैं। खाता हटाने के लिए hello@bitesbox.in पर संपर्क करें।', '1.0'),
('CANCELLATION_POLICY', 'hi', 'ऑर्डर रद्द करने की नीति',
'ऑर्डर किस चरण में है, उसके अनुसार आप उसे रद्द कर सकते हैं।

किचन के स्वीकार करने से पहले — पूरा रिफ़ंड, कोई सवाल नहीं।

स्वीकार होने के 2 मिनट के भीतर — पूरा रिफ़ंड।

खाना बनते समय — रद्द करने के लिए अनुमति ज़रूरी है। ऑर्डर की कीमत का 50% वापस किया जाता है, क्योंकि सामग्री का इस्तेमाल हो चुका होता है।

ऑर्डर पैक होने, डिलीवरी पार्टनर को सौंपे जाने या उठाए जाने के बाद उसे रद्द नहीं किया जा सकता। कुछ गड़बड़ हो तो सहायता टीम से संपर्क करें, हम समस्या ठीक करेंगे।

अगर हम रद्द करें
हमारी किचन ऑर्डर पूरा न कर सके या कोई आइटम उपलब्ध न हो, तो आपको अपने आप पूरा रिफ़ंड मिलता है। हमारी गलती के लिए आपसे कभी शुल्क नहीं लिया जाता।

रिफ़ंड मिलने का समय
मूल भुगतान के तरीके से रिफ़ंड 3–5 कार्यदिवस में मिलता है। बाइट्स बॉक्स वॉलेट में रिफ़ंड तुरंत आता है।', '1.0'),
('REFUND_POLICY', 'hi', 'रिफ़ंड नीति',
'इन स्थितियों में हम रिफ़ंड देते हैं।

पूरा रिफ़ंड
· हमने आपका ऑर्डर रद्द या अस्वीकार किया।
· आपका ऑर्डर पहुँचा ही नहीं।
· किचन के खाना बनाना शुरू करने से पहले आपने ऑर्डर रद्द किया।

आंशिक या आइटम का रिफ़ंड
· ऑर्डर में कोई आइटम नहीं था।
· आपको गलत आइटम मिला।
· कोई आइटम हमारे गुणवत्ता मानक पर खरा नहीं उतरा।

अनुरोध कैसे करें
ऐप में ऑर्डर खोलें, मदद चाहिए पर टैप करें और बताएँ कि क्या समस्या हुई। खाने की गुणवत्ता से जुड़ी शिकायत जल्दी सुलझाने में तस्वीरें मदद करती हैं।

पैसे वापस कैसे मिलेंगे
· ऑनलाइन भुगतान — 3–5 कार्यदिवस में मूल भुगतान तरीके पर रिफ़ंड।
· कैश ऑन डिलीवरी — बाइट्स बॉक्स वॉलेट में तुरंत क्रेडिट या अनुरोध पर बैंक ट्रांसफ़र।

हमारा वादा
कामकाज के समय में हम हर रिफ़ंड अनुरोध की समीक्षा 60 मिनट के भीतर करते हैं।', '1.0'),
('DELIVERY_POLICY', 'hi', 'डिलीवरी नीति',
'हम कहाँ डिलीवरी करते हैं
हम बख्तियारपुर की किचन से 8 किमी तक डिलीवरी करते हैं। सेवा तुरंत जाँचने के लिए ऐप में अपना पता दर्ज करें।

ज़ोन A (0–3 किमी) · ₹20 डिलीवरी · न्यूनतम ऑर्डर ₹99 · ₹349 से ऊपर मुफ़्त
ज़ोन B (3–5 किमी) · ₹35 डिलीवरी · न्यूनतम ऑर्डर ₹149 · ₹499 से ऊपर मुफ़्त
ज़ोन C (5–8 किमी) · ₹50 डिलीवरी · न्यूनतम ऑर्डर ₹249 · ₹799 से ऊपर मुफ़्त

व्यस्त समय
शाम 7:30 से रात 10 बजे के बीच, जब माँग सबसे ज़्यादा होती है, थोड़ा अतिरिक्त शुल्क लगता है। भुगतान से पहले यह हमेशा दिखाया जाता है।

डिलीवरी OTP
आपकी सुरक्षा के लिए डिलीवरी पार्टनर को आपके फ़ोन पर आया 4 अंकों का OTP दर्ज करना होता है। खाना मिलने से पहले OTP साझा न करें।

खुद आकर लेना
आप बिना डिलीवरी शुल्क के स्टेशन रोड आउटलेट से ऑर्डर ले सकते हैं। ऑर्डर तैयार होने पर हम पिकअप कोड भेजेंगे।', '1.0')
on conflict (kind, locale, version) do update set
  title = excluded.title,
  body = excluded.body,
  is_published = true;

insert into public.cms_faqs (category, question, answer, locale, display_order, is_published)
select t.category, t.question, t.answer, 'hi', t.display_order, true
from (values
  ('ORDERING', 'डिलीवरी में कितना समय लगता है?', 'बख्तियारपुर शहर में ज़्यादातर ऑर्डर 25–35 मिनट में पहुँचते हैं। बिरयानी और चंपारण मटन ऑर्डर मिलने पर बनाए जाते हैं, इसलिए थोड़ा ज़्यादा समय लेते हैं। भुगतान से पहले ऐप आपके पते के लिए लाइव अनुमान दिखाता है।', 1),
  ('ORDERING', 'क्या मैं बाद के लिए ऑर्डर दे सकता हूँ?', 'हाँ। चेकआउट पर शेड्यूल चुनें और 30 मिनट से 7 दिन आगे तक का समय चुनें। चुने हुए समय पर खाना ताज़ा पहुँचे, इसके लिए हम उसी हिसाब से पकाना शुरू करेंगे।', 2),
  ('ORDERING', 'क्या न्यूनतम ऑर्डर की कोई राशि है?', 'यह आपके ज़ोन पर निर्भर है — ज़ोन A में ₹99, ज़ोन B में ₹149 और ज़ोन C में ₹249। थोड़ा और जोड़ना हो तो ऐप आपको बताएगा।', 3),
  ('PAYMENT', 'आप कौन-कौन से भुगतान तरीके स्वीकार करते हैं?', 'UPI, क्रेडिट और डेबिट कार्ड, नेट बैंकिंग, लोकप्रिय वॉलेट, बाइट्स बॉक्स वॉलेट क्रेडिट और ₹2,000 तक कैश ऑन डिलीवरी।', 1),
  ('PAYMENT', 'पैसे खाते से कट गए, लेकिन ऑर्डर की पुष्टि नहीं हुई। अब क्या करूँ?', 'चिंता न करें और दोबारा भुगतान न करें। हमारा सिस्टम हर भुगतान का गेटवे से अपने आप मिलान करता है। ऑर्डर पूरा न हुआ हो तो राशि 3–5 कार्यदिवस में वापस कर दी जाती है। तुरंत जाँच के लिए ऑर्डर नंबर के साथ सहायता टीम से संपर्क करें।', 2),
  ('DELIVERY', 'डिलीवरी OTP क्या है?', 'डिलीवरी पार्टनर मिलने पर आपको 4 अंकों का कोड भेजा जाता है। खाना हाथ में मिलने के बाद ही इसे साझा करें। इससे ऑर्डर गलत व्यक्ति को सौंपे जाने से बचता है।', 1),
  ('DELIVERY', 'क्या मैं डिलीवरी पार्टनर को ट्रैक कर सकता हूँ?', 'हाँ। ऑर्डर पिकअप होने के बाद ट्रैकिंग स्क्रीन पर लाइव मानचित्र में डिलीवरी पार्टनर की लोकेशन, नाम और फ़ोन नंबर दिखता है।', 2),
  ('FOOD', 'क्या शाकाहारी खाना अलग से बनता है?', 'हाँ। शाकाहारी व्यंजनों के लिए अलग तैयारी की जगह, बर्तन और तेल इस्तेमाल किए जाते हैं।', 1),
  ('FOOD', 'मुझे खाने से एलर्जी है। क्या आप मदद कर सकते हैं?', 'हमारी किचन में मेवे, डेयरी, ग्लूटेन और अंडे का इस्तेमाल होता है, इसलिए एलर्जेन से पूरी तरह मुक्त खाना बनाने का वादा नहीं कर सकते। हर व्यंजन के एलर्जेन दिए हैं और चेकआउट पर आप नोट जोड़ सकते हैं। गंभीर एलर्जी हो तो ऑर्डर से पहले हमें कॉल करें।', 2),
  ('ACCOUNT', 'मैं अपना खाता कैसे हटाऊँ?', 'अपने रजिस्टर्ड पते से hello@bitesbox.in पर ईमेल करें या ऐप में सहायता टीम से कहें। कानून के अनुसार रखने योग्य जानकारी छोड़कर, हम 30 दिनों के भीतर आपका निजी डेटा हटाते हैं।', 1)
) as t(category, question, answer, display_order)
where not exists (
  select 1 from public.cms_faqs f
  where f.locale = 'hi'
    and f.category = t.category
    and f.display_order = t.display_order
);
-- Complete Hindi notification templates so new push and inbox messages follow
-- the customer's saved language. The inbox RPC also re-renders historical rows.
insert into public.notification_templates (
  event, channel, locale, title, body, action_route, variables
) values
  ('ORDER_PLACED', 'PUSH', 'hi', 'ऑर्डर {{order_number}} मिल गया 🎉',
   'धन्यवाद {{customer_name}}! ₹{{grand_total}} का आपका ऑर्डर मिल गया है। किचन जल्द ही पुष्टि करेगी।',
   'bitesbox://orders/{{order_id}}', array['order_number','customer_name','grand_total','order_id']),
  ('ORDER_PLACED', 'IN_APP', 'hi', 'ऑर्डर मिल गया',
   'आपका ऑर्डर {{order_number}} सफलतापूर्वक दर्ज हो गया है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('PAYMENT_CONFIRMED', 'PUSH', 'hi', 'भुगतान मिल गया ✅',
   'ऑर्डर {{order_number}} के लिए ₹{{grand_total}} का भुगतान मिल गया है।',
   'bitesbox://orders/{{order_id}}', array['grand_total','order_number','order_id']),
  ('PAYMENT_CONFIRMED', 'IN_APP', 'hi', 'भुगतान की पुष्टि हुई',
   'ऑर्डर {{order_number}} के लिए ₹{{grand_total}} का भुगतान पक्का हो गया है।',
   'bitesbox://orders/{{order_id}}', array['grand_total','order_number','order_id']),
  ('PAYMENT_FAILED', 'PUSH', 'hi', 'भुगतान पूरा नहीं हो सका',
   'ऑर्डर {{order_number}} का भुगतान नहीं हो सका। कृपया फिर कोशिश करें — पैसे नहीं कटे हैं।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('PAYMENT_FAILED', 'IN_APP', 'hi', 'भुगतान असफल रहा',
   'ऑर्डर {{order_number}} का भुगतान पूरा नहीं हुआ।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('ORDER_ACCEPTED', 'PUSH', 'hi', 'किचन ने आपका ऑर्डर स्वीकार किया 👨‍🍳',
   'हमारे शेफ़ खाना बना रहे हैं। {{order_number}} लगभग {{eta_minutes}} मिनट में तैयार होगा।',
   'bitesbox://orders/{{order_id}}', array['order_number','eta_minutes','order_id']),
  ('ORDER_ACCEPTED', 'IN_APP', 'hi', 'ऑर्डर स्वीकार हुआ',
   'किचन ने {{order_number}} स्वीकार कर लिया है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_REJECTED', 'PUSH', 'hi', 'हम यह ऑर्डर पूरा नहीं कर पाए',
   'माफ़ कीजिए — {{order_number}} स्वीकार नहीं हो सका। किया गया भुगतान पूरा वापस कर दिया जाएगा।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('ORDER_PREPARING', 'PUSH', 'hi', 'आपका खाना बन रहा है 🍳',
   '{{order_number}} अभी ताज़ा तैयार किया जा रहा है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_PREPARING', 'IN_APP', 'hi', 'खाना बन रहा है',
   '{{order_number}} तैयार किया जा रहा है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_READY', 'PUSH', 'hi', 'ऑर्डर तैयार है 🛍️',
   '{{order_number}} पैक होकर तैयार है। पिकअप कोड: {{pickup_code}}',
   'bitesbox://orders/{{order_id}}', array['order_number','pickup_code','order_id']),
  ('ORDER_READY', 'IN_APP', 'hi', 'ऑर्डर तैयार है',
   '{{order_number}} तैयार है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),

  ('RIDER_ASSIGNED', 'PUSH', 'hi', '{{rider_name}} आपका ऑर्डर लेने आ रहे हैं 🛵',
   'डिलीवरी पार्टनर {{order_number}} लेने के लिए रेस्टोरेंट जा रहे हैं।',
   'bitesbox://orders/{{order_id}}/track', array['rider_name','order_number','order_id']),
  ('RIDER_ASSIGNED', 'IN_APP', 'hi', 'डिलीवरी पार्टनर तय हो गए',
   '{{rider_name}} आपका {{order_number}} पहुँचाएँगे।',
   'bitesbox://orders/{{order_id}}/track', array['rider_name','order_number','order_id']),
  ('DELIVERY_OTP', 'PUSH', 'hi', 'आपका डिलीवरी कोड {{delivery_otp}} है',
   'ऑर्डर {{order_number}} पाने के लिए {{delivery_otp}} अपने डिलीवरी पार्टनर को बताएँ।',
   'bitesbox://orders/{{order_id}}/track', array['delivery_otp','order_number','order_id']),
  ('DELIVERY_OTP', 'IN_APP', 'hi', 'डिलीवरी OTP',
   'ऑर्डर {{order_number}} का डिलीवरी कोड: {{delivery_otp}}',
   'bitesbox://orders/{{order_id}}/track', array['delivery_otp','order_number']),
  ('DELIVERY_OTP', 'SMS', 'hi', null,
   'Bites Box: ऑर्डर {{order_number}} पाने के लिए OTP {{delivery_otp}} डिलीवरी पार्टनर को बताएँ। खाना मिलने से पहले OTP साझा न करें।',
   null, array['delivery_otp','order_number']),

  ('ORDER_PICKED_UP', 'PUSH', 'hi', 'ऑर्डर रास्ते में है 🛵',
   '{{order_number}} डिलीवरी पार्टनर ने ले लिया है और आपके पास आ रहा है।',
   'bitesbox://orders/{{order_id}}/track', array['order_number','order_id']),
  ('ORDER_PICKED_UP', 'IN_APP', 'hi', 'डिलीवरी के लिए निकल गया',
   '{{order_number}} आपके पते पर भेज दिया गया है।',
   'bitesbox://orders/{{order_id}}/track', array['order_number','order_id']),
  ('RIDER_NEARBY', 'PUSH', 'hi', 'डिलीवरी पार्टनर पहुँचने वाले हैं 📍',
   '{{order_number}} लेकर डिलीवरी पार्टनर आपके पास आ रहे हैं। OTP तैयार रखें।',
   'bitesbox://orders/{{order_id}}/track', array['order_number','order_id']),
  ('RIDER_NEARBY', 'IN_APP', 'hi', 'डिलीवरी पार्टनर पास हैं',
   'आपका डिलीवरी पार्टनर पास पहुँच गया है।',
   'bitesbox://orders/{{order_id}}/track', array['order_id']),
  ('ORDER_DELIVERED', 'PUSH', 'hi', 'ऑर्डर पहुँच गया — खाने का आनंद लें! 😋',
   '{{order_number}} डिलीवर हो गया है। अपना अनुभव बताने के लिए टैप करें।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_DELIVERED', 'IN_APP', 'hi', 'डिलीवर हो गया',
   '{{order_number}} पहुँचा दिया गया है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('ORDER_CANCELLED', 'PUSH', 'hi', 'ऑर्डर रद्द हो गया',
   '{{order_number}} रद्द कर दिया गया है। {{reason}}',
   'bitesbox://orders/{{order_id}}', array['order_number','reason','order_id']),
  ('ORDER_CANCELLED', 'IN_APP', 'hi', 'ऑर्डर रद्द हो गया',
   '{{order_number}} रद्द कर दिया गया। {{reason}}',
   'bitesbox://orders/{{order_id}}', array['order_number','reason','order_id']),

  ('REFUND_INITIATED', 'PUSH', 'hi', 'रिफ़ंड शुरू हो गया 💸',
   '{{order_number}} का रिफ़ंड शुरू कर दिया गया है। राशि 3–5 कार्यदिवस में मिल जाएगी।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('REFUND_INITIATED', 'IN_APP', 'hi', 'रिफ़ंड शुरू हो गया',
   '{{order_number}} का रिफ़ंड शुरू कर दिया गया है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('REFUND_COMPLETED', 'PUSH', 'hi', 'रिफ़ंड पूरा हो गया ✅',
   '{{order_number}} के लिए ₹{{refund_amount}} {{destination}} में वापस कर दिए गए हैं।',
   'bitesbox://orders/{{order_id}}', array['refund_amount','order_number','destination','order_id']),
  ('REFUND_COMPLETED', 'IN_APP', 'hi', 'रिफ़ंड पूरा हो गया',
   '{{order_number}} के लिए ₹{{refund_amount}} वापस कर दिए गए हैं।',
   'bitesbox://orders/{{order_id}}', array['refund_amount','order_number','order_id']),

  ('SUPPORT_REPLY', 'PUSH', 'hi', '{{ticket_number}} पर सहायता टीम का जवाब आया',
   'हमारी टीम ने आपके अनुरोध का जवाब दिया है। पढ़ने के लिए टैप करें।',
   'bitesbox://support/{{ticket_id}}', array['ticket_number','ticket_id']),
  ('SUPPORT_REPLY', 'IN_APP', 'hi', 'सहायता टीम ने जवाब दिया',
   '{{ticket_number}} पर नया जवाब आया है।',
   'bitesbox://support/{{ticket_id}}', array['ticket_number','ticket_id']),
  ('REVIEW_REQUEST', 'PUSH', 'hi', 'खाना कैसा लगा? ⭐',
   'कुछ टैप में {{order_number}} को रेट करें — आपकी राय से हमारी किचन बेहतर बनती है।',
   'bitesbox://orders/{{order_id}}/review', array['order_number','order_id']),
  ('PROMOTION', 'PUSH', 'hi', 'कुछ और खाने का मन है? 🍛',
   'आपकी कार्ट में {{item_count}} आइटम छूट गए हैं। स्टॉक खत्म होने से पहले ऑर्डर पूरा करें।',
   'bitesbox://cart', array['item_count']),
  ('SYSTEM_ALERT', 'PUSH', 'hi', 'ऑर्डर में थोड़ी देर हो रही है',
   'माफ़ कीजिए — {{order_number}} तय समय से लगभग {{minutes_late}} मिनट पीछे है। हम इसे जल्द पहुँचा रहे हैं।',
   'bitesbox://orders/{{order_id}}', array['order_number','minutes_late','order_id']),
  ('SYSTEM_ALERT', 'IN_APP', 'hi', 'ऑर्डर पहुँचने में देर हो रही है',
   '{{order_number}} में थोड़ी देर हो रही है।',
   'bitesbox://orders/{{order_id}}', array['order_number','order_id']),
  ('REFERRAL_REWARD', 'PUSH', 'hi', 'रेफ़रल इनाम जुड़ गया',
   '₹{{amount}} आपके Bites Box वॉलेट में जोड़ दिए गए हैं।',
   '/referrals', array['amount']),
  ('REFERRAL_REWARD', 'IN_APP', 'hi', 'रेफ़रल इनाम जुड़ गया',
   '₹{{amount}} आपके Bites Box वॉलेट में जोड़ दिए गए हैं।',
   '/referrals', array['amount']),

  ('NEW_ORDER_KITCHEN', 'PUSH', 'hi', '🔔 नया ऑर्डर {{order_number}}',
   '{{item_count}} आइटम · ₹{{grand_total}}। स्वीकार करने के लिए टैप करें।',
   'bitesbox://kitchen/queue', array['order_number','item_count','grand_total']),
  ('NEW_ASSIGNMENT_RIDER', 'PUSH', 'hi', '🛵 नई डिलीवरी — {{order_number}}',
   '{{area}} · {{distance_km}} किमी। देखने के लिए टैप करें।',
   'bitesbox://delivery/assignments', array['order_number','area','distance_km']),
  ('RIDER_APPROVED', 'PUSH', 'hi', 'आपका खाता स्वीकृत हो गया 🎉',
   'स्वागत है। आपका पार्टनर कोड {{partner_code}} है। डिलीवरी पाने के लिए ड्यूटी शुरू करें।',
   null, array['partner_code']),
  ('RIDER_APPROVED', 'IN_APP', 'hi', 'आपका खाता स्वीकृत हो गया',
   'आपका पार्टनर कोड {{partner_code}} है। डिलीवरी पाने के लिए ड्यूटी शुरू करें।',
   null, array['partner_code']),
  ('RIDER_APPROVED', 'SMS', 'hi', null,
   'Bites Box: आपका डिलीवरी पार्टनर खाता सक्रिय है। पार्टनर कोड {{partner_code}}।',
   null, array['partner_code']),
  ('RIDER_SUSPENDED', 'IN_APP', 'hi', 'आपका खाता अस्थायी रूप से रोका गया है',
   'कृपया अपने मैनेजर से बात करें। कारण: {{reason}}',
   null, array['reason']),
  ('OTP', 'SMS', 'hi', null,
   '{{code}} आपका Bites Box सत्यापन कोड है। यह 10 मिनट तक मान्य है। इसे किसी से साझा न करें।',
   null, array['code'])
on conflict (event, channel, locale) do update set
  title = excluded.title,
  body = excluded.body,
  action_route = excluded.action_route,
  variables = excluded.variables,
  is_active = true;

-- Re-render inbox messages from saved event data so a language switch also
-- updates notifications that were originally created in another language.
create or replace function public.localized_customer_notifications(
  p_limit integer default 50,
  p_locale text default 'en'
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', n.id,
        'event', n.event,
        'title', case
          when localized.title is not null then app.render_template(localized.title, n.data)
          when fallback.title is not null then app.render_template(fallback.title, n.data)
          else n.title
        end,
        'body', case
          when localized.body is not null then app.render_template(localized.body, n.data)
          when fallback.body is not null then app.render_template(fallback.body, n.data)
          else n.body
        end,
        'order_id', n.order_id,
        'read_at', n.read_at,
        'created_at', n.created_at
      ) order by n.created_at desc
    ),
    '[]'::jsonb
  )
  from (
    select notification.*
    from public.notifications as notification
    where notification.user_id = auth.uid()
      and notification.channel = 'IN_APP'
    order by notification.created_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 100)
  ) as n
  left join lateral (
    select template.title, template.body
    from public.notification_templates as template
    where template.event = n.event
      and template.channel = 'IN_APP'
      and template.locale = case when p_locale = 'hi' then 'hi' else 'en' end
      and template.is_active
    limit 1
  ) as localized on true
  left join lateral (
    select template.title, template.body
    from public.notification_templates as template
    where template.event = n.event
      and template.channel = 'IN_APP'
      and template.locale = 'en'
      and template.is_active
    limit 1
  ) as fallback on true;
$$;

revoke all on function public.localized_customer_notifications(integer,text) from public, anon;
grant execute on function public.localized_customer_notifications(integer,text) to authenticated;
