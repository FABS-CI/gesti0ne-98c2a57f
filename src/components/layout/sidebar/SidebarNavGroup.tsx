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
