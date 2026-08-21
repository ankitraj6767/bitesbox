import type { Metadata } from "next";
import Link from "next/link";
import { requirePermission } from "@/lib/session";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { PageHeader } from "@/components/layout/page-header";
import { CmsFaqEditor } from "@/features/cms/cms-faq-editor";
import type { CmsFaqInitial } from "@/features/cms/cms-types";

export const metadata: Metadata = { title: "New FAQ" };

export default async function NewCmsFaqPage() {
  await requirePermission(PERMISSIONS.CMS_UPDATE);
  const initial: CmsFaqInitial = {
    category: "GENERAL",
    question: "",
    answer: "",
    locale: "en",
    display_order: 0,
    is_published: false,
  };
  return (
    <>
      <PageHeader
        title="Add FAQ"
        description="Create a support answer that can be published without a mobile release."
        actions={
          <Link href="/cms" className="text-sm text-brand-600">
            Back to Storefront
          </Link>
        }
      />
      <CmsFaqEditor initial={initial} />
    </>
  );
}
