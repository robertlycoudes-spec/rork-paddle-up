/**
 * Production OAuth return: exchanges `?code=` for tokens, then returns to
 * settings. (The preview popup flow never hits this route.)
 */

import { useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";

import { Splash } from "@/pages/Splash";
import { useCloud } from "@/state/CloudProvider";

export default function AuthCallback() {
  const { exchangeCode } = useCloud();
  const navigate = useNavigate();
  const ran = useRef<boolean>(false);

  useEffect(() => {
    if (ran.current) return;
    ran.current = true;
    const code = new URLSearchParams(window.location.search).get("code");
    if (!code) {
      navigate("/", { replace: true });
      return;
    }
    void exchangeCode(code).finally(() => navigate("/settings", { replace: true }));
  }, [exchangeCode, navigate]);

  return <Splash />;
}
