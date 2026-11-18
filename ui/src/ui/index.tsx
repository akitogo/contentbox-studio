/**
 * Studio's UI building blocks (Tailwind). Every screen uses these, so the look stays consistent.
 */
import clsx, { type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { CircleAlert, CircleCheck, Info, Loader2, X } from 'lucide-react'
import {
  useEffect,
  useRef,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react'

/** Class names; later Tailwind classes win over earlier ones (e.g. a w-56 passed in over the default w-full) */
export const cx = (...classes: ClassValue[]) => twMerge(clsx(classes))

/* ---------- Buttons ---------- */

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger'
export type ButtonSize = 'sm' | 'md'

const BUTTON_VARIANTS: Record<ButtonVariant, string> = {
  primary: 'border-transparent bg-primary-600 text-white shadow-sm hover:bg-primary-700 hover:text-white',
  secondary: 'border-slate-300 bg-white text-slate-700 shadow-sm hover:bg-slate-50 hover:text-slate-900',
  ghost: 'border-transparent bg-transparent text-slate-600 hover:bg-slate-100 hover:text-slate-900',
  danger: 'border-red-200 bg-white text-red-600 shadow-sm hover:bg-red-50 hover:text-red-700',
}

/** Classes of a button, also for links that look like buttons */
export function buttonClass(variant: ButtonVariant = 'secondary', size: ButtonSize = 'md', className?: string) {
  return cx(
    'inline-flex shrink-0 cursor-pointer items-center justify-center gap-1.5 rounded-md border font-medium whitespace-nowrap no-underline transition-colors',
    'focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-1 focus-visible:outline-none',
    'disabled:pointer-events-none disabled:opacity-50',
    size === 'sm' ? 'h-7 px-2 text-xs' : 'h-9 px-3.5 text-sm',
    BUTTON_VARIANTS[variant],
    className,
  )
}

export function Button({
  variant = 'secondary',
  size = 'md',
  className,
  type = 'button',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; size?: ButtonSize }) {
  return <button type={type} className={buttonClass(variant, size, className)} {...props} />
}

/** Square button with an icon; label is required for screen readers */
export function IconButton({
  label,
  active = false,
  className,
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { label: string; active?: boolean }) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      aria-pressed={props['aria-pressed'] ?? (active || undefined)}
      className={cx(
        'inline-flex size-7 shrink-0 cursor-pointer items-center justify-center rounded-md text-slate-500 transition-colors',
        'hover:bg-slate-100 hover:text-slate-900 focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:outline-none',
        'disabled:pointer-events-none disabled:opacity-40',
        active && 'bg-primary-50 text-primary-700',
        className,
      )}
      {...props}
    >
      {children}
    </button>
  )
}

/* ---------- Form controls ---------- */

const CONTROL =
  'w-full rounded-md border border-slate-300 bg-white text-sm text-slate-900 shadow-xs placeholder:text-slate-400 ' +
  'focus:border-primary-500 focus:ring-2 focus:ring-primary-500/20 focus:outline-none ' +
  'disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500 read-only:bg-slate-50'

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={cx(CONTROL, 'h-9 px-3', className)} {...props} />
}

export function Select({ className, children, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select className={cx(CONTROL, 'h-9 pr-8 pl-3', className)} {...props}>
      {children}
    </select>
  )
}

export function Textarea({ className, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={cx(CONTROL, 'px-3 py-2', className)} {...props} />
}

export function Checkbox({ label, className, ...props }: InputHTMLAttributes<HTMLInputElement> & { label: ReactNode }) {
  return (
    <label className={cx('inline-flex cursor-pointer items-center gap-2 text-sm text-slate-700', className)}>
      <input type="checkbox" className="size-4 rounded border-slate-300 accent-primary-600" {...props} />
      {label}
    </label>
  )
}

/** Label, control, help text and error in one block */
export function Field({
  label,
  htmlFor,
  help,
  error,
  children,
}: {
  label: ReactNode
  htmlFor?: string
  help?: ReactNode
  error?: ReactNode
  children: ReactNode
}) {
  return (
    <div className="grid gap-1.5">
      <label htmlFor={htmlFor} className="text-sm font-medium text-slate-700">
        {label}
      </label>
      {children}
      {help && <p className="text-xs text-slate-500">{help}</p>}
      {error && <p className="text-xs text-red-600">{error}</p>}
    </div>
  )
}

/* ---------- Display ---------- */

export type BadgeTone = 'neutral' | 'success' | 'warning' | 'danger' | 'info' | 'primary'

const BADGE_TONES: Record<BadgeTone, string> = {
  neutral: 'bg-slate-100 text-slate-600 ring-slate-500/15',
  success: 'bg-emerald-50 text-emerald-700 ring-emerald-600/20',
  warning: 'bg-amber-50 text-amber-800 ring-amber-600/20',
  danger: 'bg-red-50 text-red-700 ring-red-600/15',
  info: 'bg-sky-50 text-sky-700 ring-sky-600/20',
  primary: 'bg-primary-50 text-primary-700 ring-primary-600/20',
}

export function Badge({ tone = 'neutral', className, children }: { tone?: BadgeTone; className?: string; children: ReactNode }) {
  return (
    <span className={cx('inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap ring-1 ring-inset', BADGE_TONES[tone], className)}>
      {children}
    </span>
  )
}

export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return <section className={cx('rounded-lg border border-slate-200 bg-white shadow-sm', className)}>{children}</section>
}

export function Spinner({ className }: { className?: string }) {
  return <Loader2 className={cx('size-4 animate-spin text-slate-400', className)} aria-hidden />
}

export function Loading({ children = 'Loading…' }: { children?: ReactNode }) {
  return (
    <div className="flex items-center justify-center gap-2 py-16 text-slate-500" role="status">
      <Spinner />
      {children}
    </div>
  )
}

export type AlertTone = 'info' | 'success' | 'warning' | 'danger'

const ALERT_TONES: Record<AlertTone, { box: string; Icon: typeof Info }> = {
  info: { box: 'border-sky-200 bg-sky-50 text-sky-900', Icon: Info },
  success: { box: 'border-emerald-200 bg-emerald-50 text-emerald-900', Icon: CircleCheck },
  warning: { box: 'border-amber-200 bg-amber-50 text-amber-900', Icon: CircleAlert },
  danger: { box: 'border-red-200 bg-red-50 text-red-900', Icon: CircleAlert },
}

export function Alert({
  tone = 'info',
  children,
  onClose,
  className,
}: {
  tone?: AlertTone
  children: ReactNode
  onClose?: () => void
  className?: string
}) {
  const { box, Icon } = ALERT_TONES[tone]
  return (
    <div role={tone === 'danger' ? 'alert' : 'status'} className={cx('flex items-start gap-2 rounded-md border px-3 py-2 text-sm', box, className)}>
      <Icon className="mt-0.5 size-4 shrink-0" aria-hidden />
      <div className="min-w-0 flex-1">{children}</div>
      {onClose && (
        <button type="button" onClick={onClose} aria-label="Dismiss" className="cursor-pointer opacity-60 hover:opacity-100">
          <X className="size-4" />
        </button>
      )}
    </div>
  )
}

/* ---------- Dialog ---------- */

export function Dialog({
  title,
  onClose,
  children,
  footer,
  size = 'md',
}: {
  title: ReactNode
  onClose: () => void
  children: ReactNode
  footer?: ReactNode
  size?: 'md' | 'lg'
}) {
  const panel = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => event.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    panel.current?.querySelector<HTMLElement>('input, select, textarea, button:not([data-dialog-close])')?.focus()
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div className="fixed inset-0 z-[1000] flex items-center justify-center bg-slate-900/40 p-4" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        className={cx('flex max-h-[calc(100vh-4rem)] w-full flex-col rounded-xl bg-white shadow-xl', size === 'lg' ? 'max-w-4xl' : 'max-w-lg')}
      >
        <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
          <h2 className="text-base font-semibold text-slate-900">{title}</h2>
          <IconButton label="Close" onClick={onClose} data-dialog-close>
            <X className="size-4" />
          </IconButton>
        </div>
        <div className="min-h-0 flex-1 overflow-auto px-5 py-4">{children}</div>
        {footer && <div className="flex justify-end gap-2 border-t border-slate-200 bg-slate-50 px-5 py-3 rounded-b-xl">{footer}</div>}
      </div>
    </div>
  )
}
