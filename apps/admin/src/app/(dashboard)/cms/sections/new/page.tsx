import type { Metadata } from "next";
import Link from "next/link";
import { requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsSectionEditor } from "@/features/cms/cms-section-editor";
import type { CmsOption, CmsSectionInitial } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "New home section" };

export default async function NewCmsSectionPage() {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const supabase = await createSupabaseServerClient();
  const [categoriesResult, collectionsResult] = await Promise.all([
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
  const categories: CmsOption[] = (categoriesResult.data ?? []).map((item) => ({
    id: item.id,
    label: item.name,
  }));
  const collections: CmsOption[] = (collectionsResult.data ?? []).map(
    (item) => ({ id: item.id, label: item.name }),
  );
  const initial: CmsSectionInitial = {
    kind: "PRODUCT_CAROUSEL",
    section_key: "",
    title: "",
    subtitle: "",
    action_label: "",
    action_route: "",
    layout: "CAROUSEL",
    item_limit: 8,
    display_order: 0,
    is_active: true,
    requires_auth: false,
    category_id: null,
    collection_id: null,
    rule: {},
    background_color: null,
    text_color: null,
    image_path: null,
    rich_text: null,
    starts_at: null,
    ends_at: null,
    valid_days_of_week: [0, 1, 2, 3, 4, 5, 6],
    valid_from_time: null,
    valid_to_time: null,
  };
  return (
    <>
      <PageHeader
        title="Add home section"
        description="Create a customer-facing block that is immediately resolved by the mobile home feed."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsSectionEditor
        initial={initial}
        categories={categories}
        collections={collections}
      />
    </>
  );
}
