# Jump Scare assets

Drop your two files directly in this folder, using these exact names:

- `jumpscare.png`: the fullscreen image shown during the Jump Scare troll action
- `jumpscare.mp3`: the sound that plays alongside it

Nothing else needs to change. `App.tsx`'s `JumpscareOverlay` already references
these filenames. Anything in this `public/` folder is copied as-is into
`web/dist/` on build (Vite's static-asset convention), so after adding the
files just run `npm run build` again and restart the resource.

If a different image format is easier to source (e.g. `.jpg` / `.gif`) or a
different audio format (`.ogg` / `.wav`), rename the file to match and update
the two `src` paths in `JumpscareOverlay` (in `web/App.tsx`) to match the new
extension.
