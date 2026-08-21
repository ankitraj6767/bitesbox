import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import {
  FileText,
  HelpCircle,
  Image as ImageIcon,
  LayoutTemplate,
  Pencil,
  Plus,
} from "lucide-react";
import { hasPermission, requirePermission } from "@/lib/session";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardToolbar } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { EmptyState, ErrorState, InlineNotice } from "@/components/ui/states";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/overlays";
import { CmsActiveToggle } from "@/features/cms/cms-active-toggle";
import { CmsPublishToggle } from "@/features/cms/cms-publish-toggle";
import { SoftDeleteAction } from "@/components/ui/soft-delete-action";
import { PERMISSIONS } from "@bitesbox/shared-types";
import { dateOnly, humanise, storageUrl } from "@/lib/utils";
import { Button } from "@/components/ui/button";

export const metadata: Metadata = { title: "Storefront" };
export const dynamic = "force-dynamic";

const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export default async function CmsPage() {
  const session = await requirePermission(PERMISSIONS.CMS_VIEW);
  const supabase = await createSupabaseServerClient();
  const canEdit = hasPermission(session, PERMISSIONS.CMS_UPDATE);

  const [sectionsResult, bannersResult, documentsResult, faqsResult] =
    await Promise.all([
      supabase
        .from("cms_sections")
        .select(
          `id, kind, section_key, title, subtitle, action_label, action_route, layout, item_limit,
         display_order, is_active, requires_auth, starts_at, ends_at, valid_days_of_week,
         valid_from_time, valid_to_time, category_id, collection_id`,
        )
        .is("deleted_at", null)
        .order("display_order"),
      supabase
        .from("cms_banners")
        .select(
          `id, section_id, title, subtitle, badge_text, image_path, link_kind, link_route, link_url,
         display_order, is_active, starts_at, ends_at, impression_count, click_count`,
        )
        .is("deleted_at", null)
        .order("display_order"),
      supabase
        .from("cms_documents")
        .select(
          "id, kind, locale, title, version, effective_from, is_published, updated_at",
        )
        .order("kind"),
      supabase
        .from("cms_faqs")
        .select("id, category, question, answer, display_order, is_published")
        .order("category")
        .order("display_order"),
    ]);

  if (sectionsResult.error) {
    return (
      <>
        <PageHeader title="Storefront" />
        <Card>
          <ErrorState
            title="Could not load storefront content"
            message={sectionsResult.error.message}
          />
        </Card>
      </>
    );
  }

  const sections = sectionsResult.data ?? [];
  const banners = bannersResult.data ?? [];
  const documents = documentsResult.data ?? [];
  const faqs = faqsResult.data ?? [];

  return (
    <>
      <PageHeader
        title="Storefront"
        description="The customer home screen is composed here — sections, banners, policies and FAQs."
        actions={
          canEdit ? (
            <Button asChild size="sm">
              <Link href="/cms/sections/new">
                <Plus /> Add section
              </Link>
            </Button>
          ) : null
        }
      />

      <InlineNotice tone="info" className="mb-4">
        Sections render in the order below. A rail with no eligible items is
        skipped automatically, so customers never see an empty heading.
      </InlineNotice>

      <Tabs defaultValue="home">
        <TabsList>
          <TabsTrigger value="home">
            Home sections ({sections.length})
          </TabsTrigger>
          <TabsTrigger value="banners">Banners ({banners.length})</TabsTrigger>
          <TabsTrigger value="policies">
            Policies ({documents.length})
          </TabsTrigger>
          <TabsTrigger value="faqs">FAQs ({faqs.length})</TabsTrigger>
        </TabsList>

        <TabsContent value="home" className="space-y-3">
          {canEdit ? (
            <div className="flex justify-end">
              <Button asChild size="sm" variant="secondary">
                <Link href="/cms/sections/new">
                  <Plus /> Add section
                </Link>
              </Button>
            </div>
          ) : null}
          {sections.length === 0 ? (
            <Card>
              <EmptyState
                icon={LayoutTemplate}
                title="No home sections configured"
              />
            </Card>
          ) : (
            sections.map((section) => {
              const days = section.valid_days_of_week ?? [];
              const scheduled =
                days.length < 7 ||
                section.valid_from_time ||
                section.starts_at ||
                section.ends_at;

              return (
                <Card key={section.id}>
                  <CardToolbar
                    title={
                      <span className="flex flex-wrap items-center gap-2">
                        <span className="tnum rounded bg-surface-muted px-1.5 py-0.5 text-[11.5px] font-semibold text-ink-muted">
                          {section.display_order}
                        </span>
                        {section.title ?? humanise(section.kind)}
                        <Badge tone="neutral" className="px-1.5 py-0">
                          {humanise(section.kind)}
                        </Badge>
                        {section.requires_auth ? (
                          <Badge tone="info" className="px-1.5 py-0">
                            Signed in only
                          </Badge>
                        ) : null}
                      </span>
                    }
                    description={section.subtitle ?? undefined}
                    action={
                      canEdit ? (
                        <span className="flex items-center gap-1">
                          <CmsActiveToggle
                            table="cms_sections"
                            id={section.id}
                            isActive={section.is_active}
                            label={section.title ?? section.section_key}
                          />
                          <Button
                            asChild
                            variant="ghost"
                            size="icon"
                            aria-label={`Edit ${section.title ?? section.section_key}`}
                          >
                            <Link href={`/cms/sections/${section.id}/edit`}>
                              <Pencil />
                            </Link>
                          </Button>
                          <SoftDeleteAction
                            table="cms_sections"
                            id={section.id}
                            label={section.title ?? section.section_key}
                          />
                        </span>
                      ) : (
                        <Badge
                          tone={section.is_active ? "positive" : "neutral"}
                        >
                          {section.is_active ? "Live" : "Hidden"}
                        </Badge>
                      )
                    }
                  />
                  <CardContent className="flex flex-wrap gap-x-6 gap-y-1.5 text-[12.5px] text-ink-muted">
                    <span>
                      Key{" "}
                      <span className="font-mono text-ink">
                        {section.section_key}
                      </span>
                    </span>
                    <span>
                      Layout{" "}
                      <span className="text-ink">
                        {humanise(section.layout)}
                      </span>
                    </span>
                    <span>
                      Shows up to{" "}
                      <span className="tnum text-ink">
                        {section.item_limit}
                      </span>{" "}
                      items
                    </span>
                    {section.action_label ? (
                      <span>
                        CTA{" "}
                        <span className="text-ink">{section.action_label}</span>
                      </span>
                    ) : null}
                    {scheduled ? (
                      <span>
                        Schedule{" "}
                        <span className="text-ink">
                          {days.length < 7
                            ? days.map((day) => DAY_LABELS[day]).join(", ")
                            : "daily"}
                          {section.valid_from_time
                            ? ` ${section.valid_from_time.slice(0, 5)}–${section.valid_to_time?.slice(0, 5)}`
                            : ""}
                        </span>
                      </span>
                    ) : null}
                  </CardContent>
                </Card>
              );
            })
          )}
        </TabsContent>

        <TabsContent value="banners">
          {canEdit ? (
            <div className="mb-3 flex justify-end">
              <Button asChild size="sm" variant="secondary">
                <Link href="/cms/banners/new">
                  <Plus /> Add banner
                </Link>
              </Button>
            </div>
          ) : null}
          {banners.length === 0 ? (
            <Card>
              <EmptyState icon={ImageIcon} title="No banners configured" />
            </Card>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {banners.map((banner) => {
                const image = storageUrl(banner.image_path, "banners");
                const ctr =
                  banner.impression_count > 0
                    ? (
                        (banner.click_count / banner.impression_count) *
                        100
                      ).toFixed(1)
                    : null;

                return (
                  <Card key={banner.id} className="overflow-hidden">
                    <div className="relative aspect-[16/9] bg-surface-muted">
                      {image ? (
                        <Image
                          src={image}
                          alt={banner.title ?? "Banner"}
                          fill
                          className="object-cover"
                          unoptimized
                        />
                      ) : (
                        <div className="flex h-full items-center justify-center text-ink-muted">
                          <ImageIcon className="size-6" aria-hidden />
                        </div>
                      )}
                      {banner.badge_text ? (
                        <span className="absolute top-2 left-2 rounded-full bg-brand-600 px-2 py-0.5 text-[11px] font-semibold text-white">
                          {banner.badge_text}
                        </span>
                      ) : null}
                    </div>

                    <CardContent className="pt-3">
                      <p className="text-[13.5px] font-medium text-ink">
                        {banner.title ?? "Untitled"}
                      </p>
                      {banner.subtitle ? (
                        <p className="mt-0.5 text-[12.5px] text-ink-muted">
                          {banner.subtitle}
                        </p>
                      ) : null}

                      <div className="mt-2 flex flex-wrap items-center gap-2">
                        <Badge tone={banner.is_active ? "positive" : "neutral"}>
                          {banner.is_active ? "Live" : "Hidden"}
                        </Badge>
                        <Badge tone="neutral" className="px-1.5 py-0">
                          {humanise(banner.link_kind)}
                        </Badge>
                        {ctr ? (
                          <span className="text-[11.5px] text-ink-muted">
                            {banner.click_count}/{banner.impression_count}{" "}
                            clicks ({ctr}%)
                          </span>
                        ) : null}
                        {canEdit ? (
                          <span className="ml-auto flex items-center gap-1">
                            <CmsActiveToggle
                              table="cms_banners"
                              id={banner.id}
                              isActive={banner.is_active}
                              label={banner.title ?? "banner"}
                            />
                            <Button
                              asChild
                              variant="ghost"
                              size="icon"
                              aria-label={`Edit ${banner.title ?? "banner"}`}
                            >
                              <Link href={`/cms/banners/${banner.id}/edit`}>
                                <Pencil />
                              </Link>
                            </Button>
                            <SoftDeleteAction
                              table="cms_banners"
                              id={banner.id}
                              label={banner.title ?? "banner"}
                            />
                          </span>
                        ) : null}
                      </div>
                    </CardContent>
                  </Card>
                );
              })}
            </div>
          )}
        </TabsContent>

        <TabsContent value="policies" className="space-y-3">
          {canEdit ? (
            <div className="flex justify-end">
              <Button asChild size="sm" variant="secondary">
                <Link href="/cms/policies/new">
                  <Plus /> Add policy
                </Link>
              </Button>
            </div>
          ) : null}
          {documents.map((document) => (
            <Card key={document.id}>
              <CardToolbar
                title={
                  <span className="flex flex-wrap items-center gap-2">
                    <FileText className="size-4 text-ink-muted" aria-hidden />
                    {document.title}
                    <Badge tone="neutral" className="px-1.5 py-0">
                      v{document.version}
                    </Badge>
                    <Badge tone="neutral" className="px-1.5 py-0 uppercase">
                      {document.locale}
                    </Badge>
                  </span>
                }
                description={`${humanise(document.kind)} · effective ${dateOnly(document.effective_from)} · updated ${dateOnly(document.updated_at)}`}
                action={
                  canEdit ? (
                    <span className="flex items-center gap-2">
                      <CmsPublishToggle
                        table="cms_documents"
                        id={document.id}
                        isPublished={document.is_published}
                        label={document.title}
                      />
                      <Button
                        asChild
                        variant="ghost"
                        size="icon"
                        aria-label={`Edit ${document.title}`}
                      >
                        <Link href={`/cms/policies/${document.id}/edit`}>
                          <Pencil />
                        </Link>
                      </Button>
                    </span>
                  ) : (
                    <Badge
                      tone={document.is_published ? "positive" : "neutral"}
                    >
                      {document.is_published ? "Published" : "Draft"}
                    </Badge>
                  )
                }
              />
            </Card>
          ))}
        </TabsContent>

        <TabsContent value="faqs" className="space-y-3">
          {canEdit ? (
            <div className="flex justify-end">
              <Button asChild size="sm" variant="secondary">
                <Link href="/cms/faqs/new">
                  <Plus /> Add FAQ
                </Link>
              </Button>
            </div>
          ) : null}
          {faqs.length === 0 ? (
            <Card>
              <EmptyState icon={HelpCircle} title="No FAQs published" />
            </Card>
          ) : (
            Object.entries(
              faqs.reduce<Record<string, typeof faqs>>((groups, faq) => {
                const list = groups[faq.category] ?? [];
                list.push(faq);
                groups[faq.category] = list;
                return groups;
              }, {}),
            ).map(([category, items]) => (
              <Card key={category}>
                <CardToolbar
                  title={humanise(category)}
                  description={`${items.length} question(s)`}
                />
                <CardContent className="divide-y divide-hairline">
                  {items.map((faq) => (
                    <div key={faq.id} className="py-3 first:pt-0 last:pb-0">
                      <p className="flex items-start gap-2 text-[13.5px] font-medium text-ink">
                        <span className="min-w-0 flex-1">{faq.question}</span>
                        {!faq.is_published ? (
                          <Badge
                            tone="neutral"
                            className="shrink-0 px-1.5 py-0"
                          >
                            Draft
                          </Badge>
                        ) : null}
                        {canEdit ? (
                          <span className="ml-auto flex shrink-0 items-center gap-1">
                            <CmsPublishToggle
                              table="cms_faqs"
                              id={faq.id}
                              isPublished={faq.is_published}
                              label="FAQ"
                            />
                            <Button
                              asChild
                              variant="ghost"
                              size="icon"
                              aria-label="Edit FAQ"
                            >
                              <Link href={`/cms/faqs/${faq.id}/edit`}>
                                <Pencil />
                              </Link>
                            </Button>
                          </span>
                        ) : null}
                      </p>
                      <p className="mt-1 text-[13px] leading-relaxed whitespace-pre-line text-ink-muted">
                        {faq.answer}
                      </p>
                    </div>
                  ))}
                </CardContent>
              </Card>
            ))
          )}
        </TabsContent>
      </Tabs>
    </>
  );
}
