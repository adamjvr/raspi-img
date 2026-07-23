# Apply this ZIP over your existing fork

```bash
cd ~/GitHub/raspi-img
git status
git switch -c rpi5-minimal
unzip -o ~/Downloads/raspi-img-rpi5-minimal-overlay.zip -d .
make lint
git add -A
git commit -m "Add minimal Raspberry Pi 5 image support"
git push -u origin rpi5-minimal
```

Then run:

```bash
make deps
make configure
make release
```
