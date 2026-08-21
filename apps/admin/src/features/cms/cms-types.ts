import type { Json } from "@bitesbox/shared-types";

export type CmsSectionKind =
  | "HERO_CAROUSEL"
  | "CATEGORY_GRID"
  | "CATEGORY_CAROUSEL"
  | "PRODUCT_CAROUSEL"
  | "BEST_SELLERS"
  | "TODAYS_OFFERS"
  | "RECOMMENDED_COMBOS"
  | "NEW_ARRIVALS"
  | "PRICE_BUCKET"
  | "POPULAR_NOW"
  | "BUY_AGAIN"
  | "RECENTLY_ORDERED"
  | "CUSTOMER_FAVOURITES"
  | "CAMPAIGN_BANNER"
  | "COUPON_STRIP"
  | "RICH_TEXT";

export type CmsLayout = "CAROUSEL" | "GRID" | "LIST" | "BANNER" | "STRIP";

export type BannerLinkKind =
  | "NONE"
  | "CATEGORY"
  | "PRODUCT"
  | "COUPON"
  | "COLLECTION"
  | "EXTERNAL_URL"
  | "IN_APP_ROUTE";

export type LegalDocumentKind =
  | "TERMS"
  | "PRIVACY"
  | "REFUND_POLICY"
  | "CANCELLATION_POLICY"
  | "DELIVERY_POLICY"
  | "ABOUT"
  | "FAQ"
  | "SHIPPING_POLICY";

export interface CmsOption {
  id: string;
  label: string;
}

export interface CmsSectionInitial {
  id?: string;
  kind: CmsSectionKind;
  section_key: string;
  title: string | null;
  subtitle: string | null;
  action_label: string | null;
  action_route: string | null;
  layout: CmsLayout;
  item_limit: number;
  display_order: number;
  is_active: boolean;
  requires_auth: boolean;
  category_id: string | null;
  collection_id: string | null;
  rule: Json;
  background_color: string | null;
  text_color: string | null;
  image_path: string | null;
  rich_text: string | null;
  starts_at: string | null;
  ends_at: string | null;
  valid_days_of_week: number[];
  valid_from_time: string | null;
  valid_to_time: string | null;
}

export interface CmsBannerInitial {
  id?: string;
  section_id: string | null;
  title: string | null;
  subtitle: string | null;
  badge_text: string | null;
  image_path: string;
  image_path_wide: string | null;
  alt_text: string | null;
  background_color: string | null;
  link_kind: BannerLinkKind;
  link_category_id: string | null;
  link_product_id: string | null;
  link_coupon_id: string | null;
  link_collection_id: string | null;
  link_url: string | null;
  link_route: string | null;
  display_order: number;
  is_active: boolean;
  starts_at: string | null;
  ends_at: string | null;
}

export interface CmsDocumentInitial {
  id?: string;
  kind: LegalDocumentKind;
  locale: "en" | "hi";
  title: string;
  body: string;
  version: string;
  effective_from: string;
  is_published: boolean;
}

export interface CmsFaqInitial {
  id?: string;
  category: string;
  question: string;
  answer: string;
  locale: "en" | "hi";
  display_order: number;
  is_published: boolean;
}

export const SECTION_KINDS: Array<{ value: CmsSectionKind; label: string }> = [
  ["HERO_CAROUSEL", "Hero carousel"],
  ["CATEGORY_GRID", "Category grid"],
  ["CATEGORY_CAROUSEL", "Category carousel"],
  ["PRODUCT_CAROUSEL", "Product carousel"],
  ["BEST_SELLERS", "Best sellers"],
  ["TODAYS_OFFERS", "Today's offers"],
  ["RECOMMENDED_COMBOS", "Recommended combos"],
  ["NEW_ARRIVALS", "New arrivals"],
  ["PRICE_BUCKET", "Price bucket"],
  ["POPULAR_NOW", "Popular now"],
  ["BUY_AGAIN", "Buy again"],
  ["RECENTLY_ORDERED", "Recently ordered"],
  ["CUSTOMER_FAVOURITES", "Customer favourites"],
  ["CAMPAIGN_BANNER", "Campaign banner"],
  ["COUPON_STRIP", "Coupon strip"],
  ["RICH_TEXT", "Rich text"],
].map(([value, label]) => ({
  value: value as CmsSectionKind,
  label: String(label ?? value),
}));

export const LEGAL_DOCUMENT_KINDS: Array<{
  value: LegalDocumentKind;
  label: string;
}> = [
  ["TERMS", "Terms of service"],
  ["PRIVACY", "Privacy policy"],
  ["REFUND_POLICY", "Refund policy"],
  ["CANCELLATION_POLICY", "Cancellation policy"],
  ["DELIVERY_POLICY", "Delivery policy"],
  ["ABOUT", "About Bites Box"],
  ["FAQ", "FAQ"],
  ["SHIPPING_POLICY", "Shipping policy"],
].map(([value, label]) => ({
  value: value as LegalDocumentKind,
  label: String(label ?? value),
}));

export const BANNER_LINK_KINDS: Array<{
  value: BannerLinkKind;
  label: string;
}> = [
  ["NONE", "No link"],
  ["CATEGORY", "Category"],
  ["PRODUCT", "Product"],
  ["COUPON", "Coupon"],
  ["COLLECTION", "Collection"],
  ["EXTERNAL_URL", "External URL"],
  ["IN_APP_ROUTE", "In-app route"],
].map(([value, label]) => ({
  value: value as BannerLinkKind,
  label: String(label ?? value),
}));
