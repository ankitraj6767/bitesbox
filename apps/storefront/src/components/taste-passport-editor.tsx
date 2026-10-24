"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { messages, type Locale } from "@/lib/site";
import {
  buildSaveTasteProfileArgs,
  TASTE_FOOD_TYPES,
  TASTE_SPICE_LEVELS,
} from "@/lib/taste-passport";

interface TasteProfile {
  food_types: string[];
  max_spice: string | null;
  category_ids: string[];
  price_ceiling: number | null;
  has_profile: boolean;
}

interface TasteCategory {
  id: string;
  name: string;
}

export function TastePassportEditor({
  locale,
  profile,
  categories,
}: {
  locale: Locale;
  profile: TasteProfile;
  categories: TasteCategory[];
}) {
  const t = messages[locale];
  const router = useRouter();
  const [foodTypes, setFoodTypes] = React.useState(profile.food_types ?? []);
  const [maxSpice, setMaxSpice] = React.useState(profile.max_spice ?? "ANY");
  const [categoryIds, setCategoryIds] = React.useState(
    profile.category_ids ?? [],
  );
  const [priceCeiling, setPriceCeiling] = React.useState(
    profile.price_ceiling == null ? "" : String(profile.price_ceiling),
  );
  const [busy, setBusy] = React.useState(false);
  const [status, setStatus] = React.useState("");

  async function save(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setStatus("");
    try {
      const visible = new Set(categories.map((category) => category.id));
      const hidden = profile.category_ids.filter((id) => !visible.has(id));
      const args = buildSaveTasteProfileArgs({
        foodTypes,
        maxSpice,
        categoryIds: [
          ...categoryIds.filter((id) => visible.has(id)),
          ...hidden,
        ],
        priceCeiling,
      });
      const { error } = await createSupabaseBrowserClient().rpc(
        "save_my_taste_profile",
        args,
      );
      if (error) throw error;
      setStatus(t.tasteSaved);
      router.refresh();
    } catch (error) {
      const message = error instanceof Error ? error.message : "";
      setStatus(
        message.includes("price") || message.includes("₹")
          ? t.priceCeilingInvalid
          : t.tasteSaveError,
      );
    } finally {
      setBusy(false);
    }
  }

  function toggleFood(type: string) {
    setFoodTypes((current) =>
      current.includes(type)
        ? current.filter((item) => item !== type)
        : [...current, type],
    );
  }

  function toggleCategory(id: string) {
    if (!categoryIds.includes(id) && categoryIds.length >= 20) {
      setStatus(t.chooseUpTo20Categories);
      return;
    }
    setCategoryIds((current) =>
      current.includes(id)
        ? current.filter((item) => item !== id)
        : [...current, id],
    );
  }

  const foodLabel = (type: string) =>
    ({
      VEG: t.vegetarian,
      NON_VEG: t.nonVeg,
      EGG: t.egg,
      VEGAN: t.vegan,
    })[type] ?? type;
  const spiceLabel = (level: string) =>
    ({
      NONE: t.noSpice,
      MILD: t.mild,
      MEDIUM: t.medium,
      HOT: t.hot,
      EXTRA_HOT: t.extraHot,
    })[level] ?? level;

  return (
    <section id="taste-passport" className="panel taste-passport">
      <div className="section-heading">
        <div>
          <h2>{t.tastePassport}</h2>
          <p className="muted">{t.tastePassportDescription}</p>
        </div>
      </div>
      <p className="muted">{t.tastePassportDisclaimer}</p>
      <form onSubmit={(event) => void save(event)}>
        <fieldset className="taste-choice-group">
          <legend>{t.foodTypes}</legend>
          <div className="taste-choice-list">
            {TASTE_FOOD_TYPES.map((type) => (
              <label key={type} className="choice-row">
                <input
                  type="checkbox"
                  checked={foodTypes.includes(type)}
                  disabled={busy}
                  onChange={() => toggleFood(type)}
                />
                <span>{foodLabel(type)}</span>
              </label>
            ))}
          </div>
        </fieldset>
        <label className="field">
          {t.maximumSpice}
          <select
            value={maxSpice}
            disabled={busy}
            onChange={(event) => setMaxSpice(event.target.value)}
          >
            <option value="ANY">{t.anyLevel}</option>
            {TASTE_SPICE_LEVELS.map((level) => (
              <option key={level} value={level}>
                {spiceLabel(level)}
              </option>
            ))}
          </select>
        </label>
        <fieldset className="taste-choice-group">
          <legend>{t.favoriteCategories}</legend>
          {categories.length ? (
            <div className="taste-choice-list">
              {categories.map((category) => (
                <label key={category.id} className="choice-row">
                  <input
                    type="checkbox"
                    checked={categoryIds.includes(category.id)}
                    disabled={busy}
                    onChange={() => toggleCategory(category.id)}
                  />
                  <span>{category.name}</span>
                </label>
              ))}
            </div>
          ) : (
            <p className="muted">{t.tasteCategoriesUnavailable}</p>
          )}
        </fieldset>
        <label className="field">
          {t.optionalPriceCeiling}
          <input
            type="number"
            inputMode="decimal"
            min="1"
            max="100000"
            step="0.01"
            value={priceCeiling}
            disabled={busy}
            onChange={(event) => setPriceCeiling(event.target.value)}
          />
          <small>{t.leaveBlankPrice}</small>
        </label>
        <button className="primary-button" type="submit" disabled={busy}>
          {busy ? t.loading : t.saveTastePassport}
        </button>
        {status ? (
          <p className="status-message" role="status">
            {status}
          </p>
        ) : null}
      </form>
    </section>
  );
}
