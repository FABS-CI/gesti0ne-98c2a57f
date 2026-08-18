import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/colisage/historical')({
  component: RouteComponent,
})

function RouteComponent() {
  return <div>Hello "/_authenticated/colisage/historical"!</div>
}
