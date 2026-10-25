"use client";

import { FormEvent, useState } from "react";
import { getSupabaseBrowserClient } from "../../lib/supabase-browser";

export default function LoginPage() {
  const [mode, setMode] = useState<"signup" | "signin">("signup");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setMessage("");
    setError("");

    try {
      const supabase = getSupabaseBrowserClient();
      if (mode === "signup") {
        const { data, error: authError } = await supabase.auth.signUp({ email: email.trim(), password });
        if (authError) throw authError;
        if (!data.session) {
          setMessage("تم إنشاء طلب التسجيل. افحص بريدك الإلكتروني واضغط رابط التأكيد، ثم ارجع وسجّل الدخول.");
          return;
        }
      } else {
        const { error: authError } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
        if (authError) throw authError;
      }

      const { error: workspaceError } = await supabase.rpc("create_my_workspace", { workspace_name: "Beyond the Known" });
      if (workspaceError) throw workspaceError;
      setMessage("تم تسجيل الدخول وتجهيز مساحة العمل. سيتم تحويلك إلى التطبيق…");
      window.location.href = "/";
    } catch (err) {
      setError(err instanceof Error ? err.message : "حدث خطأ غير متوقع. حاول مرة أخرى.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="shell" dir="rtl">
      <header className="top">
        <div className="mark">BK</div>
        <div>
          <p className="eyebrow">SCIENCE · HISTORY · DISCOVERY</p>
          <h1>Beyond the Known</h1>
          <p className="muted">مساحة عمل المحتوى الذكي</p>
        </div>
      </header>
      <section className="hero" style={{ justifyContent: "center" }}>
        <div style={{ width: "100%", maxWidth: 480 }}>
          <p className="eyebrow gold">SECURE WORKSPACE</p>
          <h2 style={{ fontSize: 34 }}>{mode === "signup" ? "إنشاء حساب المالك" : "تسجيل الدخول"}</h2>
          <p className="heroText">ابدأ بحسابك الخاص. لن يتم نشر أي محتوى تلقائيًا؛ موافقتك الصريحة على النسخة النهائية شرط أساسي.</p>
          <form onSubmit={handleSubmit} style={{ display: "grid", gap: 14 }}>
            <label style={{ display: "grid", gap: 7 }}>
              <span>البريد الإلكتروني</span>
              <input required type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} style={fieldStyle} />
            </label>
            <label style={{ display: "grid", gap: 7 }}>
              <span>كلمة المرور (8 أحرف على الأقل)</span>
              <input required minLength={8} type="password" autoComplete={mode === "signup" ? "new-password" : "current-password"} value={password} onChange={(e) => setPassword(e.target.value)} style={fieldStyle} />
            </label>
            {error && <p role="alert" style={{ color: "#ff9a9a", lineHeight: 1.6 }}>{error}</p>}
            {message && <p role="status" style={{ color: "#d5b36a", lineHeight: 1.6 }}>{message}</p>}
            <button className="primary" type="submit" disabled={busy} style={{ border: 0, cursor: busy ? "wait" : "pointer", font: "inherit" }}>
              {busy ? "جارٍ التنفيذ…" : mode === "signup" ? "إنشاء الحساب" : "تسجيل الدخول"}
            </button>
          </form>
          <p style={{ color: "var(--muted)", marginTop: 20 }}>
            {mode === "signup" ? "عندك حساب بالفعل؟ " : "ما عندك حساب؟ "}
            <button type="button" onClick={() => { setMode(mode === "signup" ? "signin" : "signup"); setError(""); setMessage(""); }} style={{ background: "none", border: 0, color: "var(--gold)", cursor: "pointer", font: "inherit", textDecoration: "underline" }}>
              {mode === "signup" ? "سجّل الدخول" : "أنشئ حسابًا"}
            </button>
          </p>
        </div>
      </section>
      <p className="muted">ملاحظة: لا تشارك كلمة مرورك أو مفاتيح Supabase مع أي شخص.</p>
    </main>
  );
}

const fieldStyle: React.CSSProperties = {
  width: "100%",
  padding: "13px 14px",
  background: "#080d18",
  border: "1px solid var(--line)",
  borderRadius: 10,
  color: "var(--text)",
  font: "inherit",
  outlineOffset: 2,
};
