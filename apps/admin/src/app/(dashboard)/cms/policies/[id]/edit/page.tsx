import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsDocumentEditor } from "@/features/cms/cms-document-editor";
import type { CmsDocumentInitial } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "Edit policy" };

export default async function EditCmsPolicyPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("cms_documents")
    .select(
      "id, kind, locale, title, body, version, effective_from, is_published",
    )
    .eq("id", id)
    .maybeSingle();
  if (error || !data) notFound();
  return (
    <>
      <PageHeader
        title={`Edit ${data.title}`}
        description="Update the policy and publish state."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsDocumentEditor initial={data as CmsDocumentInitial} />
    </>
  );
}
