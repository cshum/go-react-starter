import { createRootRoute, Link, Outlet } from '@tanstack/react-router'

export const rootRoute = createRootRoute({
  component: RootLayout,
})

function RootLayout() {
  return (
    <div className='mx-auto max-w-3xl p-6'>
      <header className='mb-6 flex items-baseline justify-between border-b border-slate-200 pb-3'>
        <Link to='/' className='text-lg font-semibold text-slate-900'>
          Assets
        </Link>
        <span className='text-xs text-slate-400'>interview-kit</span>
      </header>
      <main>
        <Outlet />
      </main>
    </div>
  )
}
