import type { Metadata } from "next";
import Link from "next/link";
import { requirePermission } from "@/lib/session";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsDocumentEditor } from "@/features/cms/cms-document-editor";
import type { CmsDocumentInitial } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "New policy" };

export default async function NewCmsPolicyPage() {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const initial: CmsDocumentInitial = {
    kind: "ABOUT",
    locale: "en",
    title: "",
    body: "",
    version: "1.0",
    effective_from: new Date().toISOString().slice(0, 10),
    is_published: false,
  };
  return (
    <>
      <PageHeader
        title="Add policy"
        description="Create a versioned policy that can be published to customer-facing surfaces."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsDocumentEditor initial={initial} />
    </>
  );
}
