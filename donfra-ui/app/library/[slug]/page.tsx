import LessonDetailClient from "./LessonDetailClient";

export default async function LessonDetailPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  return <LessonDetailClient slug={slug} />;
}
