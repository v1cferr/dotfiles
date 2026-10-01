// GitHub Pages serves this file for any path it cannot find, which is the one route the static
// export cannot enumerate.
import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="mx-auto flex flex-1 flex-col items-center justify-center gap-4 p-8 text-center">
      <h1 className="text-2xl font-semibold">This page does not exist</h1>
      <p className="text-fd-muted-foreground">
        It may have been renamed, or it may never have been written.
      </p>
      <Link className="text-fd-primary underline underline-offset-4" href="/">
        Back to the start
      </Link>
    </div>
  );
}
