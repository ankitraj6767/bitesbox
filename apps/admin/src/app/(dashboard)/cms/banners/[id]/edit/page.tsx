import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsBannerEditor } from "@/features/cms/cms-banner-editor";
import type { CmsBannerInitial, CmsOption } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "Edit banner" };

export default async function EditCmsBannerPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const [bannerResult, sections, categories, products, coupons, collections] =
    await Promise.all([
      supabase
        .from("cms_banners")
        .select(
          "id, section_id, title, subtitle, badge_text, image_path, image_path_wide, alt_text, background_color, link_kind, link_category_id, link_product_id, link_coupon_id, link_collection_id, link_url, link_route, display_order, is_active, starts_at, ends_at",
        )
        .eq("id", id)
        .maybeSingle(),
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
  if (bannerResult.error || !bannerResult.data) notFound();
  const options = {
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
  return (
    <>
      <PageHeader
        title={`Edit ${bannerResult.data.title ?? "banner"}`}
        description="Changes appear in the customer app after its next home-feed refresh."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsBannerEditor
        initial={bannerResult.data as unknown as CmsBannerInitial}
        {...options}
      />
    </>
  );
}
