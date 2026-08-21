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
import type { CmsFaqInitial } from "./cms-types";

export function CmsFaqEditor({ initial }: { initial: CmsFaqInitial }) {
  const router = useRouter();
  const [form, setForm] = React.useState(initial);
  const [saving, setSaving] = React.useState(false);
  const set = <K extends keyof CmsFaqInitial>(
    key: K,
    value: CmsFaqInitial[K],
  ) => setForm((current) => ({ ...current, [key]: value }));

  async function save(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const payload = {
        category: form.category.trim().toUpperCase() || "GENERAL",
        question: form.question.trim(),
        answer: form.answer.trim(),
        locale: form.locale,
        display_order: Math.max(0, Number(form.display_order) || 0),
        is_published: form.is_published,
      };
      const result = form.id
        ? await supabase.from("cms_faqs").update(payload).eq("id", form.id)
        : await supabase.from("cms_faqs").insert(payload);
      if (result.error) throw result.error;
      toast.success(form.id ? "FAQ updated" : "FAQ created");
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
          title="FAQ details"
          description="Published FAQs are read by the customer support and help surfaces."
        />
        <CardContent className="grid gap-4 p-5 md:grid-cols-2">
          <Field
            label="Category"
            required
            hint="Example: DELIVERY, PAYMENTS or GENERAL."
          >
            <Input
              value={form.category}
              onChange={(event) => set("category", event.target.value)}
              required
            />
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
          <Field label="Display order">
            <Input
              type="number"
              min="0"
              step="1"
              value={String(form.display_order)}
              onChange={(event) =>
                set("display_order", Number(event.target.value))
              }
            />
          </Field>
          <label className="flex items-center gap-2 text-[13px] text-ink md:items-end">
            <input
              type="checkbox"
              checked={form.is_published}
              onChange={(event) => set("is_published", event.target.checked)}
            />
            Publish this FAQ
          </label>
          <Field label="Question" required className="md:col-span-2">
            <Input
              value={form.question}
              onChange={(event) => set("question", event.target.value)}
              required
            />
          </Field>
          <Field label="Answer" required className="md:col-span-2">
            <Textarea
              value={form.answer}
              onChange={(event) => set("answer", event.target.value)}
              rows={8}
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
          {form.id ? "Save changes" : "Create FAQ"}
        </Button>
      </div>
    </form>
  );
}
