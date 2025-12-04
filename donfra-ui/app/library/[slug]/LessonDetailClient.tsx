"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { API_BASE } from "@/lib/api";

type Lesson = {
  ID: number;
  Slug: string;
  Title: string;
  Markdown?: string;
  Excalidraw?: any;
};

const API_ROOT = API_BASE

export default function LessonDetailClient({ slug }: { slug: string }) {
  const router = useRouter();

  const [lesson, setLesson] = useState<Lesson | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        setError(null);
        const res = await fetch(`${API_ROOT}/lessons/${slug}`);
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`);
        setLesson({
          ID: data.ID ?? data.id,
          Slug: data.Slug ?? data.slug ?? slug,
          Title: data.Title ?? data.title ?? slug,
          Markdown: data.Markdown ?? data.markdown ?? "",
          Excalidraw: data.Excalidraw ?? data.excalidraw,
        });
      } catch (err: any) {
        setError(err?.message || "Failed to load lesson");
        setLesson(null);
      } finally {
        setLoading(false);
      }
    })();
  }, [slug]);

  return (
    <main style={{ padding: "32px", fontFamily: "sans-serif", color: "#eee", background: "#0b0c0c", minHeight: "100vh" }}>
      <div style={{ marginBottom: 10, color: "#ccc" }}>
        <button
          onClick={() => router.push("/library")}
          style={{ background: "none", border: "none", padding: 0, color: "#f4d18c", cursor: "pointer", textDecoration: "underline" }}
        >
          Library
        </button>
        <span style={{ margin: "0 8px" }}>/</span>
        <span>{slug}</span>
      </div>
      <h1 style={{ marginTop: 0, marginBottom: 12 }}>Lesson Detail</h1>
      {loading && <div>Loading…</div>}
      {error && !loading && <div style={{ color: "#f88" }}>{error}</div>}
      {!loading && !error && lesson && (
        <div style={{ border: "1px solid #333", borderRadius: 8, padding: 12, background: "#0f1211" }}>
          <h2 style={{ marginTop: 0 }}>{lesson.Title || lesson.Slug}</h2>
          <p style={{ color: "#888", marginTop: 4, marginBottom: 12 }}>Slug: {lesson.Slug} · ID: {lesson.ID}</p>
          <div
            style={{
              whiteSpace: "pre-wrap",
              lineHeight: 1.6,
              borderTop: "1px solid #333",
              paddingTop: 10,
              color: "#ddd",
            }}
          >
            {lesson.Markdown || "No content"}
          </div>
          <h4 style={{ marginTop: 16, marginBottom: 6 }}>Excalidraw (raw JSON)</h4>
          <pre
            style={{
              background: "#0b0c0c",
              border: "1px solid #222",
              borderRadius: 6,
              padding: 12,
              color: "#ccc",
              whiteSpace: "pre-wrap",
              wordBreak: "break-word",
            }}
          >
{JSON.stringify(lesson.Excalidraw, null, 2)}
          </pre>
        </div>
      )}
    </main>
  );
}
