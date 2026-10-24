import type { Metadata } from "next";
import Link from "next/link";
import { SignOutButton } from "@/components/sign-out-button";
import { StorefrontHeader } from "@/components/storefront-header";
import { storefrontContext } from "@/lib/storefront-context";
import { messages } from "@/lib/site";
import { TastePassportEditor } from "@/components/taste-passport-editor";

export const metadata: Metadata = {
  title: "Account",
  robots: { index: false, follow: false },
};
export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const context = await storefrontContext();
  const t = messages[context.locale];
  const [ordersResult, tasteProfileResult, catalogResult] = await Promise.all([
    context.user
      ? context.supabase.rpc("my_orders", { p_limit: 10, p_scope: "ALL" })
      : Promise.resolve({ data: null }),
    context.isCustomer
      ? context.supabase.rpc("my_taste_profile")
      : Promise.resolve({ data: null }),
    context.isCustomer
      ? context.supabase.rpc("localized_menu_catalog", {
          p_branch_id: context.outlet?.id,
          p_locale: context.locale,
        })
      : Promise.resolve({ data: null }),
  ]);
  const orders =
    (
      ordersResult.data as {
        orders?: Array<{
          id: string;
          order_number: string;
          status: string;
          created_at: string;
        }>;
      } | null
    )?.orders ?? [];
  const tasteProfile =
    (tasteProfileResult.data as {
      food_types?: string[];
      max_spice?: string | null;
      category_ids?: string[];
      price_ceiling?: number | null;
      has_profile?: boolean;
    } | null) ?? {};
  const tasteCategories =
    (
      catalogResult.data as {
        categories?: Array<{ id: string; name: string }>;
      } | null
    )?.categories ?? [];
  return (
    <>
      <StorefrontHeader
        outlets={context.outlets}
        outletId={context.outlet?.id ?? ""}
        outletName={context.outlet?.name ?? ""}
        locale={context.locale}
        userId={context.user?.id ?? null}
      />
      <main className="page">
        <h1>{t.account}</h1>
        {!context.user ? (
          <section className="panel">
            <p>{t.signInRequired}</p>
            <Link
              className="primary-button"
              href={`/sign-in?next=${encodeURIComponent("/account")}`}
            >
              {t.signIn}
            </Link>
          </section>
        ) : (
          <>
            <section className="panel account-summary">
              <h2>{context.profile?.full_name ?? t.account}</h2>
              <p>
                {context.profile?.preferred_language === "hi"
                  ? "हिन्दी"
                  : "English"}
              </p>
              <div className="account-links">
                <Link href="/favorites">{t.favorites}</Link>
                <Link href="/referrals">{t.referral}</Link>
                <Link href="/help">{t.help}</Link>
                <SignOutButton locale={context.locale} />
              </div>
            </section>
            {context.isCustomer ? (
              <TastePassportEditor
                locale={context.locale}
                profile={{
                  food_types: tasteProfile.food_types ?? [],
                  max_spice: tasteProfile.max_spice ?? null,
                  category_ids: tasteProfile.category_ids ?? [],
                  price_ceiling: tasteProfile.price_ceiling ?? null,
                  has_profile: tasteProfile.has_profile ?? false,
                }}
                categories={tasteCategories}
              />
            ) : null}
            <section>
              <h2>{localeTitle(context.locale)}</h2>
              {orders.length ? (
                <ul className="account-orders">
                  {orders.map((order) => (
                    <li key={order.id}>
                      <Link href={`/order/${order.id}`}>
                        <span>{order.order_number}</span>
                        <span>
                          {order.status.replaceAll("_", " ").toLowerCase()}
                        </span>
                      </Link>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="muted">{t.emptyCart}</p>
              )}
            </section>
          </>
        )}
      </main>
    </>
  );
}

function localeTitle(locale: "en" | "hi") {
  return locale === "hi" ? "आपके ऑर्डर" : "Your orders";
}
