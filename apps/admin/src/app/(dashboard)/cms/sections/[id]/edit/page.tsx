import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsSectionEditor } from "@/features/cms/cms-section-editor";
import type { CmsOption, CmsSectionInitial } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "Edit home section" };

export default async function EditCmsSectionPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const [sectionResult, categoriesResult, collectionsResult] =
    await Promise.all([
      supabase
        .from("cms_sections")
        .select(
          "id, kind, section_key, title, subtitle, action_label, action_route, layout, item_limit, display_order, is_active, requires_auth, category_id, collection_id, rule, background_color, text_color, image_path, rich_text, starts_at, ends_at, valid_days_of_week, valid_from_time, valid_to_time",
        )
        .eq("id", id)
        .maybeSingle(),
      supabase
        .from("categories")
        .select("id, name")
        .is("deleted_at", null)
        .order("display_order"),
      supabase
        .from("collections")
        .select("id, name")
        .is("deleted_at", null)
        .order("name"),
    ]);
  if (sectionResult.error || !sectionResult.data) notFound();
  const categories: CmsOption[] = (categoriesResult.data ?? []).map((item) => ({
    id: item.id,
    label: item.name,
  }));
  const collections: CmsOption[] = (collectionsResult.data ?? []).map(
    (item) => ({ id: item.id, label: item.name }),
  );
  return (
    <>
      <PageHeader
        title={`Edit ${sectionResult.data.title ?? sectionResult.data.section_key}`}
        description="Changes appear in the customer app after its next home-feed refresh."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsSectionEditor
        initial={sectionResult.data as unknown as CmsSectionInitial}
        categories={categories}
        collections={collections}
      />
    </>
  );
}
