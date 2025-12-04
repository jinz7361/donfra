"use client";

import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { API_BASE } from "@/lib/api";

type Lesson = {
  ID: number;
  Slug: string;
  Title: string;
  Markdown?: string;
  Excalidraw?: any;
};

const API_ROOT = API_BASE || "http://localhost/api";

export default function LibraryPage() {
  return (
    <Suspense fallback={<main style={{ padding: 32, color: "#eee" }}>Loading…</main>}>
      <LibraryInner />
    </Suspense>
  );
}

function LibraryInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const selectedSlug = searchParams.get("slug") || "";

  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [loadingList, setLoadingList] = useState(true);
  const [listError, setListError] = useState<string | null>(null);

  const [detail, setDetail] = useState<Lesson | null>(null);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch(`${API_ROOT}/lessons`);
        const data = await res.json();
        if (!Array.isArray(data)) throw new Error("Unexpected response");
        setLessons(data);
      } catch (err: any) {
        setListError(err?.message || "Failed to load lessons");
      } finally {
        setLoadingList(false);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!selectedSlug) {
      setDetail(null);
      return;
    }
    (async () => {
      try {
        setLoadingDetail(true);
        setDetailError(null);
        const res = await fetch(`${API_ROOT}/lessons/${selectedSlug}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        setDetail({
          ID: data.ID ?? data.id,
          Slug: data.Slug ?? data.slug,
          Title: data.Title ?? data.title,
          Markdown: data.Markdown ?? data.markdown ?? "",
          Excalidraw: data.Excalidraw ?? data.excalidraw,
        });
      } catch (err: any) {
        setDetailError(err?.message || "Failed to load lesson detail");
        setDetail(null);
      } finally {
        setLoadingDetail(false);
      }
    })();
  }, [selectedSlug]);

  return (
    <main style={{ padding: "32px", fontFamily: "sans-serif", color: "#eee", background: "#0b0c0c", minHeight: "100vh" }}>
      <h1 style={{ marginBottom: 12 }}>Lesson Library</h1>
      <p style={{ color: "#ccc", marginBottom: 16 }}>Click a slug to view details.</p>

      <section style={{ marginBottom: 24 }}>
        {loadingList && <div>Loading lessons…</div>}
        {listError && <div style={{ color: "#f88" }}>{listError}</div>}
        {!loadingList && !listError && (
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ textAlign: "left", borderBottom: "1px solid #444" }}>
                <th style={{ padding: "8px 6px", width: "80px" }}>ID</th>
                <th style={{ padding: "8px 6px" }}>Slug</th>
              </tr>
            </thead>
            <tbody>
              {lessons.map((lesson) => (
                <tr key={lesson.Slug} style={{ borderBottom: "1px solid #222" }}>
                  <td style={{ padding: "8px 6px", color: "#aaa" }}>{lesson.ID}</td>
                  <td style={{ padding: "8px 6px" }}>
                    <button
                      onClick={() => router.push(`/library?slug=${lesson.Slug}`)}
                      style={{ background: "none", border: "none", color: "#f4d18c", cursor: "pointer", textDecoration: "underline" }}
                    >
                      {lesson.Slug}
                    </button>
                  </td>
                </tr>
              ))}
              {lessons.length === 0 && (
                <tr>
                  <td colSpan={2} style={{ padding: "8px 6px", color: "#aaa" }}>
                    No lessons found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </section>

      <section style={{ marginTop: 24 }}>
        {selectedSlug && (
          <>
            <div style={{ marginBottom: 10, color: "#ccc" }}>
              <a href="/library" style={{ color: "#f4d18c", textDecoration: "underline" }}>Library</a>
              <span style={{ margin: "0 8px" }}>/</span>
              <span>{selectedSlug}</span>
            </div>
            <h2 style={{ marginBottom: 10 }}>Lesson Detail</h2>
          </>
        )}
        {loadingDetail && selectedSlug && <div>Loading detail…</div>}
        {detailError && selectedSlug && <div style={{ color: "#f88" }}>{detailError}</div>}
        {!loadingDetail && !detailError && detail && selectedSlug && (
          <div style={{ border: "1px solid #333", borderRadius: 8, padding: 12, background: "#0f1211" }}>
            <h3 style={{ marginTop: 0 }}>{detail.Title || detail.Slug}</h3>
            <p style={{ color: "#888", marginTop: 4, marginBottom: 12 }}>Slug: {detail.Slug} · ID: {detail.ID}</p>
            <div
              style={{
                whiteSpace: "pre-wrap",
                lineHeight: 1.6,
                borderTop: "1px solid #333",
                paddingTop: 10,
                color: "#ddd",
              }}
            >
              {detail.Markdown || "No content"}
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
{JSON.stringify(detail.Excalidraw, null, 2)}
            </pre>
          </div>
        )}
        {!selectedSlug && (
          <div style={{ color: "#888" }}>Select a lesson to view its details.</div>
        )}
      </section>
    </main>
  );
}
