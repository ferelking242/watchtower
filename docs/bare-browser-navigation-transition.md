# Bare Browser navigation transition

## Status

Not implemented: the available repositories do not include enough source
material to reproduce the Bare Browser transition faithfully.

## What was checked

- The Watchtower repository and the `watchtower-extensions` repository.
- `docs/build-constraints.md`, `docs/patches.md`, and `patches/` in both
  repositories.
- References to Bare Browser, patch 0109, and “Leave the navigation blur
  transition off”.

None of the referenced Bare Browser documentation or patch files are present.
The available remotes are Watchtower and Watchtower Extensions; neither is the
Bare Browser source repository. The only `0109` matches are unrelated extension
catalogue IDs.

## Information still needed

To implement this safely, provide the Bare Browser repository or the exact
upstream commit, including patch 0109 and the Chromium/navigation source it
refers to. The affected Watchtower screen or route must also be identified if
it is not clear from that source.

Until then, no FadeTransition, SlideTransition, or navigation-blur behavior has
been added. Choosing one without the source would not verify the requested
behavior and could reintroduce the reported white flash.
