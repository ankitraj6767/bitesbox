import type { Metadata } from "next";
import Link from "next/link";
import { requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsBannerEditor } from "@/features/cms/cms-banner-editor";
import type { CmsBannerInitial, CmsOption } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "New banner" };

export default async function NewCmsBannerPage() {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const supabase = await createSupabaseServerClient();
  const options = await loadOptions(supabase);
  const initial: CmsBannerInitial = {
    section_id: null,
    title: "",
    subtitle: "",
    badge_text: "",
    image_path: "",
    image_path_wide: "",
    alt_text: "",
    background_color: "",
    link_kind: "NONE",
    link_category_id: null,
    link_product_id: null,
    link_coupon_id: null,
    link_collection_id: null,
    link_url: "",
    link_route: "",
    display_order: 0,
    is_active: true,
    starts_at: null,
    ends_at: null,
  };
  return (
    <>
      <PageHeader
        title="Add banner"
        description="Upload artwork and link it to a section, product, offer or route."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsBannerEditor initial={initial} {...options} />
    </>
  );
}

async function loadOptions(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
) {
  const [sections, categories, products, coupons, collections] =
    await Promise.all([
      supabase
        .from("cms_sections")
        .select("id, section_key, title")
        .is("deleted_at", null)
        .order("display_order"),
      supabase
        .from("categories")
        .select("id, name")
        .is("deleted_at", null)
        .order("display_order"),
      supabase
        .from("products")
        .select("id, name")
        .is("deleted_at", null)
        .order("name"),
      supabase
        .from("coupons")
        .select("id, code, title")
        .is("deleted_at", null)
        .order("code"),
      supabase
        .from("collections")
        .select("id, name")
        .is("deleted_at", null)
        .order("name"),
    ]);
  return {
    sections: (sections.data ?? []).map((item) => ({
      id: item.id,
      label: item.title ?? item.section_key,
    })),
    categories: (categories.data ?? []).map((item) => ({
      id: item.id,
      label: item.name,
    })),
    products: (products.data ?? []).map((item) => ({
      id: item.id,
      label: item.name,
    })),
    coupons: (coupons.data ?? []).map((item) => ({
      id: item.id,
      label: `${item.code} · ${item.title}`,
    })),
    collections: (collections.data ?? []).map((item) => ({
      id: item.id,
      label: item.name,
    })),
  } satisfies {
    sections: CmsOption[];
    categories: CmsOption[];
    products: CmsOption[];
    coupons: CmsOption[];
    collections: CmsOption[];
  };
}
