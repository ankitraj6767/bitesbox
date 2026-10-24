import Image from "next/image";
import Link from "next/link";
import { FavoriteToggle } from "@/components/favorite-toggle";
import { messages, storageUrl, type Locale } from "@/lib/site";

export interface Product {
  id: string;
  name: string;
  slug: string;
  category_id?: string;
  short_description?: string | null;
  thumbnail_path?: string | null;
  hero_image_path?: string | null;
  base_price: number;
  min_price?: number;
  food_type?: string;
  is_available: boolean;
  is_best_seller?: boolean;
  is_new?: boolean;
  preparation_minutes?: number | null;
  serves_count?: number | null;
  spice_level?: string | null;
  has_variants?: boolean;
  reason_code?: string;
}

export function ProductTile({
  product,
  favorite,
  locale,
  reason,
}: {
  product: Product;
  favorite: boolean;
  locale: Locale;
  reason?: string;
}) {
  const image = storageUrl(product.thumbnail_path ?? product.hero_image_path);
  const t = messages[locale];
  const spiceCopy = {
    NONE: t.noSpice,
    MILD: t.mild,
    MEDIUM: t.medium,
    HOT: t.hot,
    EXTRA_HOT: t.extraHot,
  };
  const spiceLabel = product.spice_level
    ? spiceCopy[product.spice_level as keyof typeof spiceCopy]
    : null;
  const money = new Intl.NumberFormat(locale === "hi" ? "hi-IN" : "en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  });
  return (
    <article className="product-card">
      <div className="product-image">
        <Link
          href={`/menu/${encodeURIComponent(product.slug)}`}
          aria-label={`${locale === "hi" ? "देखें" : "View"} ${product.name}`}
        >
          {image ? (
            <Image
              src={image}
              alt={product.name}
              fill
              sizes="(max-width:640px) 48vw, 24vw"
            />
          ) : null}
        </Link>
        <div className="product-badges">
          {product.is_best_seller ? (
            <span className="product-badge product-badge-featured">
              {locale === "hi" ? "लोकप्रिय" : "Fan favourite"}
            </span>
          ) : product.is_new ? (
            <span className="product-badge">
              {locale === "hi" ? "नया" : "Just added"}
            </span>
          ) : null}
        </div>
        <FavoriteToggle
          productId={product.id}
          initial={favorite}
          label={
            favorite
              ? locale === "hi"
                ? "पसंदीदा से हटाएँ"
                : "Remove from favorites"
              : locale === "hi"
                ? "पसंदीदा में सहेजें"
                : "Save to favorites"
          }
        />
      </div>
      <div className="product-info">
        <div className="product-title-line">
          <span
            className={`food-mark food-mark-${(product.food_type ?? "VEG").toLowerCase()}`}
            role="img"
            aria-label={
              product.food_type === "NON_VEG"
                ? locale === "hi"
                  ? "मांसाहारी"
                  : "Non-vegetarian"
                : product.food_type === "EGG"
                  ? locale === "hi"
                    ? "अंडा"
                    : "Contains egg"
                  : locale === "hi"
                    ? "शाकाहारी"
                    : "Vegetarian"
            }
          />
          <h3>
            <Link href={`/menu/${encodeURIComponent(product.slug)}`}>
              {product.name}
            </Link>
          </h3>
        </div>
        <p>
          {product.short_description ??
            (product.food_type === "VEG"
              ? locale === "hi"
                ? "शाकाहारी"
                : "Vegetarian"
              : locale === "hi"
                ? "Bites Box का पसंदीदा"
                : "Bites Box favourite")}
        </p>
        {reason ? <p className="taste-reason">{reason}</p> : null}
        <div className="product-detail-meta">
          {product.preparation_minutes ? (
            <span>{product.preparation_minutes} min</span>
          ) : null}
          {product.serves_count ? (
            <span>
              {locale === "hi"
                ? `${product.serves_count} लोगों के लिए`
                : `Serves ${product.serves_count}`}
            </span>
          ) : null}
          {spiceLabel && product.spice_level !== "NONE" ? (
            <span>{spiceLabel}</span>
          ) : null}
        </div>
        <div className="product-price">
          {product.has_variants
            ? locale === "hi"
              ? "शुरुआती कीमत "
              : "from "
            : ""}
          {money.format(Number(product.min_price ?? product.base_price))}
        </div>
        {!product.is_available ? (
          <span
            className="muted"
            aria-label={
              locale === "hi"
                ? "चुने हुए आउटलेट पर उपलब्ध नहीं"
                : "Unavailable at selected outlet"
            }
          >
            {locale === "hi"
              ? "इस आउटलेट पर उपलब्ध नहीं"
              : "Unavailable at this outlet"}
          </span>
        ) : null}
      </div>
    </article>
  );
}
