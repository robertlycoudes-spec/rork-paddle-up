/**
 * Pro entitlement state. Mirrors the iOS StoreService: local entitlement now,
 * with the same gating surface so real billing can drop in later.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import {
  allProducts,
  canStartSession,
  readEntitlement,
  sessionHistoryLimit,
  writeEntitlement,
  type ProFeature,
  type SubscriptionProduct,
} from "@/lib/pu/store";

interface StoreValue {
  products: SubscriptionProduct[];
  isPro: boolean;
  activeProduct: SubscriptionProduct | null;
  isPurchasing: boolean;
  lastError: string | null;
  purchase: (product: SubscriptionProduct) => Promise<boolean>;
  restore: () => Promise<boolean>;
  setPro: (value: boolean) => void;
  canStart: (completedSessions: number) => boolean;
  historyLimit: () => number | null;
  isLocked: (feature: ProFeature) => boolean;
}

const StoreContext = createContext<StoreValue | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [isPro, setIsPro] = useState<boolean>(false);
  const [activeProductID, setActiveProductID] = useState<string | null>(null);
  const [isPurchasing, setIsPurchasing] = useState<boolean>(false);
  const [lastError, setLastError] = useState<string | null>(null);

  useEffect(() => {
    const entitlement = readEntitlement();
    setIsPro(entitlement.isPro);
    setActiveProductID(entitlement.productID);
  }, []);

  /** MOCK PURCHASE — replace with a real billing transaction. */
  const purchase = useCallback(async (product: SubscriptionProduct) => {
    setIsPurchasing(true);
    setLastError(null);
    await new Promise((resolve) => setTimeout(resolve, 700));
    setIsPro(true);
    setActiveProductID(product.id);
    writeEntitlement(true, product.id);
    setIsPurchasing(false);
    return true;
  }, []);

  /** MOCK RESTORE — replace with a real entitlement fetch. */
  const restore = useCallback(async () => {
    setIsPurchasing(true);
    await new Promise((resolve) => setTimeout(resolve, 500));
    const restored = readEntitlement().isPro;
    setIsPro(restored);
    if (!restored) setLastError("No previous purchase found for this browser.");
    setIsPurchasing(false);
    return restored;
  }, []);

  /** Development affordance so the full Pro experience stays testable. */
  const setPro = useCallback((value: boolean) => {
    setIsPro(value);
    writeEntitlement(value);
    if (!value) setActiveProductID(null);
  }, []);

  const value = useMemo<StoreValue>(
    () => ({
      products: allProducts,
      isPro,
      activeProduct:
        allProducts.find((product) => product.id === activeProductID) ?? null,
      isPurchasing,
      lastError,
      purchase,
      restore,
      setPro,
      canStart: (completedSessions: number) =>
        canStartSession(isPro, completedSessions),
      historyLimit: () => sessionHistoryLimit(isPro),
      isLocked: () => !isPro,
    }),
    [isPro, activeProductID, isPurchasing, lastError, purchase, restore, setPro],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

export function useStore(): StoreValue {
  const context = useContext(StoreContext);
  if (!context) throw new Error("useStore must be used inside StoreProvider");
  return context;
}
