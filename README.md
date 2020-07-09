# Why?

I needed an excuse to make something in Zig (this was my first project in it)
and coincidentally needed a way to see my hard drive usage without waiting for
Windows to calculate it.

I end up using it probably at least a few times a week so it's been useful.

## Usage

Open the app, see how much disk space you have left. Click on the entries to
open the disk in the file explorer.

## Internal libs

I might pull the small internal library used here out into a library of its own
but that would either be something I do because I need it elsewhere or because
someone else makes a neat case for it.

If one were so inclined they could add the entire package as a dependency and
just point the package declaration at `disk.zig` (I think?) to use it as a lib.
