import Image from "next/image";
import Link from "next/link";
import { FavoriteToggle } from "@/components/favorite-toggle";
import { storageUrl, type Locale } from "@/lib/site";

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
        <h3>
          <Link href={`/menu/${encodeURIComponent(product.slug)}`}>
            {product.name}
          </Link>
        </h3>
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
