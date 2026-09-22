import type { Config } from "tailwindcss";
import tailwindcssAnimate from "tailwindcss-animate";

export default {
  darkMode: ["class"],
  content: [
    "./pages/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./app/**/*.{ts,tsx}",
    "./src/**/*.{ts,tsx}",
  ],
  prefix: "",
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border) / 0.08)",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        sidebar: {
          DEFAULT: "hsl(var(--sidebar-background))",
          foreground: "hsl(var(--sidebar-foreground))",
          primary: "hsl(var(--sidebar-primary))",
          "primary-foreground": "hsl(var(--sidebar-primary-foreground))",
          accent: "hsl(var(--sidebar-accent))",
          "accent-foreground": "hsl(var(--sidebar-accent-foreground))",
          border: "hsl(var(--sidebar-border))",
          ring: "hsl(var(--sidebar-ring))",
        },
        // Paddle Up palette — the exact tokens from the iOS design system.
        pu: {
          canvas: "#0B0F0C",
          "canvas-deep": "#070A08",
          surface: "#151B16",
          raised: "#1C241D",
          hairline: "rgba(255,255,255,0.08)",
          lime: "#C6FF3D",
          "lime-ink": "#0A1005",
          primary: "#F4F7F2",
          secondary: "#8C968D",
          tertiary: "#5E6760",
          alert: "#FF5F52",
          amber: "#FFB020",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
        "pu-card": "20px",
        "pu-tile": "16px",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
        "pu-rise": {
          from: { opacity: "0", transform: "translateY(14px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        "pu-rise-lg": {
          from: { opacity: "0", transform: "translateY(22px) scale(0.94)" },
          to: { opacity: "1", transform: "translateY(0) scale(1)" },
        },
        "pu-fade": {
          from: { opacity: "0" },
          to: { opacity: "1" },
        },
        "pu-spin": {
          from: { transform: "rotate(0deg)" },
          to: { transform: "rotate(360deg)" },
        },
        "pu-spin-reverse": {
          from: { transform: "rotate(0deg)" },
          to: { transform: "rotate(-360deg)" },
        },
        "pu-pulse": {
          "0%, 100%": { opacity: "1" },
          "50%": { opacity: "0.25" },
        },
        "pu-ring-pulse": {
          from: { opacity: "0.55", transform: "scale(0.94)" },
          to: { opacity: "0", transform: "scale(1.14)" },
        },
        "pu-breathe": {
          "0%, 100%": { opacity: "0.7", transform: "scale(0.94)" },
          "50%": { opacity: "0.35", transform: "scale(1.08)" },
        },
        "pu-hint": {
          "0%, 100%": { transform: "translateY(-1px)" },
          "50%": { transform: "translateY(2px)" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
        "pu-rise": "pu-rise 0.55s cubic-bezier(0.2, 0.8, 0.2, 1) both",
        "pu-rise-lg": "pu-rise-lg 0.6s cubic-bezier(0.2, 0.8, 0.2, 1) both",
        "pu-fade": "pu-fade 0.4s ease-out both",
        "pu-spin": "pu-spin 48s linear infinite",
        "pu-spin-reverse": "pu-spin-reverse 36s linear infinite",
        "pu-pulse": "pu-pulse 2.2s ease-in-out infinite",
        "pu-ring-pulse": "pu-ring-pulse 0.9s ease-out forwards",
        "pu-breathe": "pu-breathe 3.8s ease-in-out infinite",
        "pu-hint": "pu-hint 1.4s ease-in-out infinite",
      },
    },
  },
  plugins: [tailwindcssAnimate],
} satisfies Config;
