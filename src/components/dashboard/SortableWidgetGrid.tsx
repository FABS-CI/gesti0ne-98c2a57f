import { GripVertical } from "lucide-react";
import {
  DndContext,
  PointerSensor,
  KeyboardSensor,
  useSensor,
  useSensors,
  closestCenter,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  arrayMove,
  rectSortingStrategy,
  sortableKeyboardCoordinates,
  useSortable,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";

import type { WidgetId } from "@/lib/dashboard-widgets";
import { WidgetCard } from "./WidgetCard";

type Props = {
  visible: WidgetId[];
  editMode: boolean;
  onReorder: (next: WidgetId[]) => void;
};

export default function SortableWidgetGrid({ visible, editMode, onReorder }: Props) {
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  const onDragEnd = (e: DragEndEvent) => {
    const { active, over } = e;
    if (!over || active.id === over.id) return;
    const oldIdx = visible.indexOf(active.id as WidgetId);
    const newIdx = visible.indexOf(over.id as WidgetId);
    if (oldIdx < 0 || newIdx < 0) return;
    onReorder(arrayMove(visible, oldIdx, newIdx));
  };

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
      <SortableContext items={visible} strategy={rectSortingStrategy}>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {visible.map((id) => (
            <SortableWidget key={id} id={id} editMode={editMode} />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  );
}

function SortableWidget({ id, editMode }: { id: WidgetId; editMode: boolean }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id,
    disabled: !editMode,
  });

  return (
    <WidgetCard
      ref={setNodeRef}
      id={id}
      editMode={editMode}
      style={{
        transform: CSS.Transform.toString(transform),
        transition,
        opacity: isDragging ? 0.6 : 1,
      }}
      className={isDragging ? "ring-2 ring-primary" : ""}
      dragHandle={
        <button
          type="button"
          {...attributes}
          {...listeners}
          className="cursor-grab active:cursor-grabbing text-muted-foreground hover:text-foreground"
          aria-label="Déplacer"
        >
          <GripVertical className="h-4 w-4" />
        </button>
      }
    />
  );
}
