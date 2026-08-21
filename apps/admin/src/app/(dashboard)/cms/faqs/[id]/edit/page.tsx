import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsFaqEditor } from "@/features/cms/cms-faq-editor";
import type { CmsFaqInitial } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "Edit FAQ" };

export default async function EditCmsFaqPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("cms_faqs")
    .select(
      "id, category, question, answer, locale, display_order, is_published",
    )
    .eq("id", id)
    .maybeSingle();
  if (error || !data) notFound();
  return (
    <>
      <PageHeader
        title="Edit FAQ"
        description="Update the answer and publish state."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsFaqEditor initial={data as CmsFaqInitial} />
    </>
  );
}
