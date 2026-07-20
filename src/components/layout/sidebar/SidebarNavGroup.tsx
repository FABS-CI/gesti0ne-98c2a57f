import { ChevronDown, ChevronRight, Folder } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import type { Group, Item } from "./nav-data";
import { SidebarNavItem } from "./SidebarNavItem";

type Section = { name: string | null; items: Item[] };

function groupBySection(items: Item[]): Section[] {
  const sections: Section[] = [];
  const index = new Map<string, Section>();
  for (const item of items) {
    const key = item.section ?? "__flat__";
    let bucket = index.get(key);
    if (!bucket) {
      bucket = { name: item.section ?? null, items: [] };
      index.set(key, bucket);
      sections.push(bucket);
    }
    bucket.items.push(item);
  }
  return sections;
}

export function SidebarNavGroup({
  group,
  isOpen,
  isActive,
  currentPath,
  onToggle,
}: {
  group: Group;
  isOpen: boolean;
  isActive: boolean;
  currentPath: string;
  onToggle: () => void;
}) {
  const activeText = group.activeText ?? "#FFFFFF";
  const GroupIcon = group.groupIcon;

  return (
    <li>
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full items-center justify-between gap-2 text-left transition-all duration-200"
        style={{
          padding: "12px 14px",
          borderRadius: "14px",
          background: isActive ? group.grad : isOpen ? group.light : "transparent",
          boxShadow: isActive
            ? `0 4px 14px ${group.shadow}`
            : isOpen
              ? `inset 4px 0 0 ${group.color}`
              : "none",
        }}
        onMouseEnter={(e) => {
          if (!isActive) {
            e.currentTarget.style.background = `${group.color}28`;
            e.currentTarget.style.boxShadow = `0 4px 12px ${group.shadow}`;
          }
        }}
        onMouseLeave={(e) => {
          if (!isActive) {
            e.currentTarget.style.background = "transparent";
            e.currentTarget.style.boxShadow = "none";
          }
        }}
      >
        <span className="flex min-w-0 items-center gap-3">
          <span
            className="flex shrink-0 items-center justify-center rounded-xl"
            style={{
              width: "38px",
              height: "38px",
              backgroundColor: isActive
                ? group.activeText
                  ? "rgba(17,24,39,0.12)"
                  : "rgba(255,255,255,0.18)"
                : group.light,
              transition: "background 0.2s",
            }}
          >
            <GroupIcon
              style={{
                width: "22px",
                height: "22px",
                color: isActive ? activeText : group.color,
                transition: "color 0.2s",
              }}
            />
          </span>
          <span
            className="truncate"
            style={{
              fontSize: "15px",
              fontWeight: 700,
              color: isActive ? activeText : isOpen ? group.color : "#E2E8F0",
              letterSpacing: "0.01em",
              lineHeight: 1.3,
              transition: "color 0.2s",
            }}
          >
            {group.label}
          </span>
        </span>
        <ChevronDown
          style={{
            width: "16px",
            height: "16px",
            flexShrink: 0,
            color: isActive ? activeText : isOpen ? group.color : "rgba(255,255,255,0.25)",
            transform: isOpen ? "rotate(180deg)" : "rotate(0deg)",
            transition: "transform 0.25s ease, color 0.2s",
          }}
        />
      </button>

      <div
        style={{
          overflow: "hidden",
          maxHeight: isOpen ? "900px" : "0px",
          opacity: isOpen ? 1 : 0,
          transition: "max-height 0.3s cubic-bezier(0.4,0,0.2,1), opacity 0.22s ease",
        }}
      >
        <ul
          className="mb-1.5 mt-1.5 space-y-1"
          style={{
            marginLeft: "22px",
            paddingLeft: "12px",
            borderLeft: `2px solid ${group.color}30`,
          }}
        >
          <NavSections
            group={group}
            currentPath={currentPath}
            activeText={activeText}
            parentOpen={isOpen}
          />

        </ul>
      </div>
    </li>
  );
}

const SECTION_STORAGE_PREFIX = "fabs.sidebar.section.";

function NavSections({
  group,
  currentPath,
  activeText,
  parentOpen,
}: {
  group: Group;
  currentPath: string;
  activeText: string;
  parentOpen: boolean;
}) {
  const sections = useMemo(() => groupBySection(group.items), [group.items]);
  const hasSections = sections.some((s) => s.name !== null);

  if (!hasSections) {
    return (
      <>
        {group.items.map((item) => (
          <SidebarNavItem
            key={item.title}
            item={item}
            group={group}
            active={!!item.ready && currentPath === item.url}
            activeText={activeText}
          />
        ))}
      </>
    );
  }

  return (
    <>
      {sections.map((section) =>
        section.name === null ? (
          section.items.map((item) => (
            <SidebarNavItem
              key={item.title}
              item={item}
              group={group}
              active={!!item.ready && currentPath === item.url}
              activeText={activeText}
            />
          ))
        ) : (
          <SubSection
            key={section.name}
            groupLabel={group.label}
            name={section.name}
            items={section.items}
            group={group}
            currentPath={currentPath}
            activeText={activeText}
            parentOpen={parentOpen}
          />
        ),
      )}
    </>
  );
}

function SubSection({
  groupLabel,
  name,
  items,
  group,
  currentPath,
  activeText,
  parentOpen,
}: {
  groupLabel: string;
  name: string;
  items: Item[];
  group: Group;
  currentPath: string;
  activeText: string;
  parentOpen: boolean;
}) {
  const storageKey = `${SECTION_STORAGE_PREFIX}${groupLabel}::${name}`;
  const containsActive = items.some((i) => i.ready && currentPath === i.url);

  const [open, setOpen] = useState<boolean>(() => {
    if (typeof window === "undefined") return containsActive;
    const raw = window.localStorage.getItem(storageKey);
    if (raw === "1") return true;
    if (raw === "0") return false;
    return containsActive;
  });

  useEffect(() => {
    if (containsActive) setOpen(true);
  }, [containsActive]);

  const toggle = () => {
    setOpen((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(storageKey, next ? "1" : "0");
      } catch {
        /* ignore */
      }
      return next;
    });
  };

  return (
    <li>
      <button
        type="button"
        onClick={toggle}
        aria-expanded={open}
        className="flex w-full items-center gap-2 text-left transition-colors"
        style={{
          padding: "8px 10px",
          borderRadius: "8px",
          background: open ? `${group.color}18` : "transparent",
          color: containsActive ? "#FFFFFF" : open ? group.color : "#94A3B8",
          fontSize: "12px",
          fontWeight: 700,
          letterSpacing: "0.06em",
          textTransform: "uppercase",
        }}
      >
        {open ? (
          <ChevronDown style={{ width: 14, height: 14, flexShrink: 0 }} />
        ) : (
          <ChevronRight style={{ width: 14, height: 14, flexShrink: 0 }} />
        )}
        <Folder style={{ width: 14, height: 14, flexShrink: 0 }} />
        <span className="truncate">{name}</span>
        <span
          className="ml-auto shrink-0"
          style={{ fontSize: 11, opacity: 0.7, fontWeight: 600 }}
        >
          {items.length}
        </span>
      </button>
      <div
        style={{
          overflow: "hidden",
          maxHeight: parentOpen && open ? "900px" : "0px",
          opacity: parentOpen && open ? 1 : 0,
          transition: "max-height 0.25s cubic-bezier(0.4,0,0.2,1), opacity 0.18s ease",
        }}
      >
        <ul
          className="mt-1 space-y-1"
          style={{
            marginLeft: "10px",
            paddingLeft: "10px",
            borderLeft: `1px dashed ${group.color}40`,
          }}
        >
          {items.map((item) => (
            <SidebarNavItem
              key={item.title}
              item={item}
              group={group}
              active={!!item.ready && currentPath === item.url}
              activeText={activeText}
            />
          ))}
        </ul>
      </div>
    </li>
  );
}
