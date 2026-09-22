/**
 * Paddle Up Pro paywall: ball glyph hero, feature list, annual-default product
 * picker, purchase bar on a blurred material.
 */

import { useState } from "react";

import { BallGlyph } from "@/components/pu/BallMark";
import { Icon } from "@/components/pu/Icon";
import { Card, PrimaryButton } from "@/components/pu/Primitives";
import { annualProduct, proFeatures, type SubscriptionProduct } from "@/lib/pu/store";
import { cn } from "@/lib/utils";
import { useStore } from "@/state/StoreProvider";

export function PaywallPanel({
  headline,
  onComplete,
  onSkip,
  skipLabel = "Continue with limited access",
}: {
  headline: string;
  onComplete: () => void;
  onSkip?: () => void;
  skipLabel?: string;
}) {
  const store = useStore();
  const [selectedID, setSelectedID] = useState<string>(annualProduct.id);
  const [message, setMessage] = useState<string | null>(null);

  const selected =
    store.products.find((product) => product.id === selectedID) ?? annualProduct;

  const purchase = async () => {
    const success = await store.purchase(selected);
    if (success) {
      onComplete();
    } else {
      setMessage(store.lastError ?? "Purchase didn't complete.");
    }
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-xl animate-pu-rise px-5 pb-28 pt-5">
          <div className="flex justify-center">
            <BallGlyph size={40} />
          </div>

          <div className="mt-4 flex flex-col items-center gap-2.5 text-center">
            <h2 className="text-[28px] font-black leading-tight text-pu-primary">
              {headline}
            </h2>
            <p className="text-[15px] font-medium leading-relaxed text-pu-secondary">
              Get unlimited access to your AI pickleball coach, personalized
              training plans, drills, strategy, and game improvement tools.
            </p>
          </div>

          <Card className="mt-4">
            <div className="flex flex-col gap-3">
              {proFeatures.map((feature) => (
                <div key={feature.id} className="flex items-center gap-3">
                  <Icon
                    name={feature.icon}
                    className="h-[18px] w-[18px] shrink-0 text-pu-lime"
                    strokeWidth={2.2}
                  />
                  <span className="text-[15px] font-medium text-pu-primary">
                    {feature.title}
                  </span>
                </div>
              ))}
            </div>
          </Card>

          <div className="mt-4 flex flex-col gap-2.5">
            {store.products.map((product) => (
              <ProductRow
                key={product.id}
                product={product}
                isSelected={selectedID === product.id}
                onSelect={() => setSelectedID(product.id)}
              />
            ))}
          </div>

          {message && (
            <p className="mt-3 text-center text-[13px] font-medium text-pu-amber">
              {message}
            </p>
          )}

          <p className="mt-3 text-center text-[11px] text-pu-tertiary">
            Subscriptions renew automatically until cancelled. Manage or cancel
            any time from your account settings.
          </p>
        </div>
      </div>

      <div className="pu-action-bar px-5 pb-3 pt-2.5">
        <div className="mx-auto flex w-full max-w-xl flex-col items-center gap-2.5">
          <PrimaryButton onClick={purchase} disabled={store.isPurchasing}>
            {store.isPurchasing ? (
              <Icon name="LoaderCircle" className="h-5 w-5 animate-spin" />
            ) : (
              `START TRAINING — ${selected.price}`
            )}
          </PrimaryButton>
          {onSkip && (
            <button
              type="button"
              onClick={onSkip}
              className="text-[13px] font-medium text-pu-secondary transition-colors hover:text-pu-primary"
            >
              {skipLabel}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function ProductRow({
  product,
  isSelected,
  onSelect,
}: {
  product: SubscriptionProduct;
  isSelected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={isSelected}
      className={cn(
        "flex w-full items-center gap-3.5 rounded-pu-tile border p-4 text-left transition-all duration-200 active:scale-[0.985]",
        isSelected
          ? "border-pu-lime/55 bg-pu-raised"
          : "border-pu-hairline bg-pu-surface hover:bg-pu-raised/70",
      )}
    >
      <Icon
        name={isSelected ? "CircleDot" : "Circle"}
        className={cn(
          "h-5 w-5 shrink-0",
          isSelected ? "text-pu-lime" : "text-pu-tertiary/60",
        )}
        strokeWidth={2.2}
      />
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <div className="flex items-center gap-2">
          <span className="text-[17px] font-semibold text-pu-primary">
            {product.title}
          </span>
          {product.badge && (
            <span className="rounded-full bg-pu-lime px-[7px] py-[3px] text-[10px] font-bold text-pu-lime-ink">
              {product.badge}
            </span>
          )}
        </div>
        {product.subtitle && (
          <span className="text-[13px] font-medium text-pu-secondary">
            {product.subtitle}
          </span>
        )}
      </div>
      <div className="flex shrink-0 flex-col items-end">
        <span className="text-lg font-bold text-pu-primary">{product.price}</span>
        <span className="text-[11px] text-pu-tertiary">
          {product.monthlyEquivalent ?? product.period}
        </span>
      </div>
    </button>
  );
}
