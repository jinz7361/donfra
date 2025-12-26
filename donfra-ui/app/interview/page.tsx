"use client";

import { useEffect, useState, useCallback, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import CodePad from "@/components/CodePad";
import { api } from "@/lib/api";

function InterviewContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>("");
  const [roomId, setRoomId] = useState<string>("");

  useEffect(() => {
    const joinRoom = async () => {
      try {
        // Get invite token from URL query params
        const token = searchParams.get("token");

        if (!token) {
          setError("Missing invite token. Please use a valid invite link.");
          setLoading(false);
          return;
        }

        // Join the room via API
        const response = await fetch("/api/interview/join", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ invite_token: token }),
          credentials: "include", // Important for cookies
        });

        if (!response.ok) {
          const errorData = await response.json().catch(() => ({}));
          throw new Error(errorData.error || `Failed to join room: ${response.status}`);
        }

        const data = await response.json();
        setRoomId(data.room_id);
        setLoading(false);
      } catch (err: any) {
        console.error("Error joining room:", err);
        setError(err.message || "Failed to join interview room");
        setLoading(false);
      }
    };

    joinRoom();
  }, [searchParams]);

  const handleExit = useCallback(() => {
    router.push("/");
  }, [router]);

  if (loading) {
    return (
      <div style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        height: "100vh",
        flexDirection: "column",
        gap: "16px"
      }}>
        <div style={{ fontSize: "18px", color: "#666" }}>Joining interview room...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        height: "100vh",
        flexDirection: "column",
        gap: "16px"
      }}>
        <div style={{ fontSize: "18px", color: "#e74c3c", marginBottom: "8px" }}>
          ❌ {error}
        </div>
        <button
          onClick={() => router.push("/")}
          style={{
            padding: "8px 16px",
            backgroundColor: "#3498db",
            color: "white",
            border: "none",
            borderRadius: "4px",
            cursor: "pointer",
            fontSize: "14px"
          }}
        >
          Go Home
        </button>
      </div>
    );
  }

  // Successfully joined - render CodePad with the room_id
  return <CodePad onExit={handleExit} roomId={roomId} />;
}

export default function InterviewPage() {
  return (
    <Suspense
      fallback={
        <div style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          height: "100vh",
          flexDirection: "column",
          gap: "16px"
        }}>
          <div style={{ fontSize: "18px", color: "#666" }}>Loading...</div>
        </div>
      }
    >
      <InterviewContent />
    </Suspense>
  );
}
