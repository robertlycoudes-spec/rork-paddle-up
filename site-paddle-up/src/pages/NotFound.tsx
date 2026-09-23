import { Link } from "react-router-dom";

import { usePageTitle } from "@/hooks/use-page-title";

const NotFound = () => {
  usePageTitle("Page not found");

  return (
    <div className="mx-auto flex max-w-6xl flex-col items-start px-5 py-28 sm:py-36">
      <p className="micro text-lime">Error 404</p>
      <h1 className="mt-3 text-[80px] font-black leading-none tracking-tight tabular-nums text-fg-primary sm:text-[120px]">
        Out.
      </h1>
      <p className="mt-5 max-w-md text-[17px] leading-relaxed text-fg-secondary">
        That page landed wide of the line. It may have moved, or the link may be mistyped.
      </p>
      <Link
        to="/"
        className="mt-9 inline-flex h-12 items-center rounded-full bg-lime px-6 text-[15px] font-bold text-lime-ink transition-transform active:scale-[0.97]"
      >
        Back to home
      </Link>
    </div>
  );
};

export default NotFound;
