import { Link } from "@tanstack/react-router";
import type { Group, Item } from "./nav-data";

export function SidebarNavItem({
  item,
  group,
  active,
  activeText,
}: {
  item: Item;
  group: Group;
  active: boolean;
  activeText: string;
}) {
  const Icon = item.icon;
  return (
    <li>
      <Link
        to={item.url}
        className="sidebar-nav-item"
        style={{
          display: "flex",
          alignItems: "center",
          gap: "12px",
          padding: "12px 14px",
          minHeight: "44px",
          borderRadius: "10px",
          fontSize: "15px",
          fontWeight: active ? 600 : 500,
          color: active ? activeText : "#CBD5E1",
          background: active ? group.grad : "transparent",
          boxShadow: active ? `0 2px 10px ${group.shadow}` : "none",
          transition: "all 0.15s",
          textDecoration: "none",
          lineHeight: 1.35,
        }}
        onMouseEnter={(e) => {
          if (!active) {
            e.currentTarget.style.background = `${group.color}30`;
            e.currentTarget.style.color = "#FFFFFF";
            e.currentTarget.style.boxShadow = `inset 5px 0 0 ${group.color}`;
          }
        }}
        onMouseLeave={(e) => {
          if (!active) {
            e.currentTarget.style.background = "transparent";
            e.currentTarget.style.color = "#CBD5E1";
            e.currentTarget.style.boxShadow = "none";
          }
        }}
      >
        <Icon style={{ width: "20px", height: "20px", flexShrink: 0 }} />
        <span className="truncate">{item.title}</span>
        {active && (
          <span
            aria-hidden
            className="ml-auto h-2 w-2 shrink-0 rounded-full"
            style={{ background: "#FFFFFF" }}
          />
        )}
      </Link>
    </li>
  );
}
