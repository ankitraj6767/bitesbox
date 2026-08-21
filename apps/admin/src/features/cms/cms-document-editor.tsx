"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Save } from "lucide-react";
import { toast } from "sonner";
import { Card, CardContent, CardToolbar } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Field,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
} from "@/components/ui/form-controls";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { errorMessage } from "@/lib/errors";
import {
  LEGAL_DOCUMENT_KINDS,
  type CmsDocumentInitial,
  type LegalDocumentKind,
} from "./cms-types";

export function CmsDocumentEditor({
  initial,
}: {
  initial: CmsDocumentInitial;
}) {
  const router = useRouter();
  const [form, setForm] = React.useState(initial);
  const [saving, setSaving] = React.useState(false);
  const set = <K extends keyof CmsDocumentInitial>(
    key: K,
    value: CmsDocumentInitial[K],
  ) => setForm((current) => ({ ...current, [key]: value }));

  async function save(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const payload = {
        kind: form.kind,
        locale: form.locale,
        title: form.title.trim(),
        body: form.body.trim(),
        version: form.version.trim(),
        effective_from: form.effective_from,
        is_published: form.is_published,
      };
      const result = form.id
        ? await supabase.from("cms_documents").update(payload).eq("id", form.id)
        : await supabase.from("cms_documents").insert(payload);
      if (result.error) throw result.error;
      toast.success(form.id ? "Policy updated" : "Policy created");
      router.push("/cms");
      router.refresh();
    } catch (error) {
      toast.error(errorMessage(error));
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={save} className="space-y-4">
      <Card>
        <CardToolbar
          title="Policy details"
          description="The mobile app reads the currently published version for the selected language."
        />
        <CardContent className="grid gap-4 p-5 md:grid-cols-2">
          <Field label="Document type" required>
            <Select
              value={form.kind}
              onValueChange={(value) => set("kind", value as LegalDocumentKind)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {LEGAL_DOCUMENT_KINDS.map((kind) => (
                  <SelectItem key={kind.value} value={kind.value}>
                    {kind.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          <Field label="Locale" required>
            <Select
              value={form.locale}
              onValueChange={(value) => set("locale", value as "en" | "hi")}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="en">English</SelectItem>
                <SelectItem value="hi">Hindi</SelectItem>
              </SelectContent>
            </Select>
          </Field>
          <Field label="Title" required>
            <Input
              value={form.title}
              onChange={(event) => set("title", event.target.value)}
              required
            />
          </Field>
          <Field
            label="Version"
            required
            hint="Use a new version when publishing a replacement."
          >
            <Input
              value={form.version}
              onChange={(event) => set("version", event.target.value)}
              required
            />
          </Field>
          <Field label="Effective from" required>
            <Input
              type="date"
              value={form.effective_from}
              onChange={(event) => set("effective_from", event.target.value)}
              required
            />
          </Field>
          <label className="flex items-center gap-2 text-[13px] text-ink md:items-end">
            <input
              type="checkbox"
              checked={form.is_published}
              onChange={(event) => set("is_published", event.target.checked)}
            />
            Publish this policy
          </label>
          <Field label="Body" required className="md:col-span-2">
            <Textarea
              value={form.body}
              onChange={(event) => set("body", event.target.value)}
              rows={18}
              required
            />
          </Field>
        </CardContent>
      </Card>
      <div className="flex justify-end gap-2">
        <Button
          type="button"
          variant="secondary"
          onClick={() => router.push("/cms")}
        >
          Cancel
        </Button>
        <Button type="submit" loading={saving}>
          <Save />
          {form.id ? "Save changes" : "Create policy"}
        </Button>
      </div>
    </form>
  );
}
