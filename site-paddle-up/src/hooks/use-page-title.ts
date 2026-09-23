import { useEffect } from "react";

import { SITE } from "@/lib/site";

/** Sets the browser tab title for a page. */
export function usePageTitle(title?: string): void {
  useEffect(() => {
    document.title = title ? `${title} · ${SITE.product} by ${SITE.companyShort}` : `${SITE.companyShort} · Makers of ${SITE.product}`;
  }, [title]);
}
