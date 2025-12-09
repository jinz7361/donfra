import EditLessonClient from "./EditLessonClient";

export default async function EditLessonPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  return <EditLessonClient slug={slug} />;
}
