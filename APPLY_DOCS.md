# Apply the documentation overlay

Extract this archive over the root of the `rpi5-minimal` checkout.

```bash
cd "$HOME/GitHub/raspi-img"
git switch rpi5-minimal
unzip -o /path/to/raspi-img-rpi5-docs-overlay.zip -d .
```

Review:

```bash
git status --short
git diff --check
git diff -- README.md README-RPI5.md docs/
```

Commit:

```bash
git add README.md README-RPI5.md docs/ APPLY_DOCS.md

git commit -m \
    "docs: add complete Raspberry Pi 5 image documentation"

git push origin rpi5-minimal
```
