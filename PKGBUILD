pkgname=plasma6-wallpapers-wallshift-advanced
pkgver=0.4.1
pkgrel=1
pkgdesc='KDE Plasma 6 image and video wallpaper rotation with editable animated transitions'
arch=('any')
url='https://github.com/asikeida/PlasmaWallShift-Advanced'
license=('GPL-3.0-or-later')
depends=('glib2' 'plasma-workspace' 'qt6-declarative' 'qt6-multimedia')
optdepends=('ffmpegthumbs: show cached video thumbnails in the settings page'
            'kdotool: use the global cursor as the radial transition origin')
makedepends=('qt6-shadertools')

build() {
  make -C "$startdir" all
}

package() {
  install -d "$pkgdir/usr/share/plasma/wallpapers"
  cp -a "$startdir/io.github.asikeida.wallshiftadvanced" \
    "$pkgdir/usr/share/plasma/wallpapers/io.github.asikeida.wallshiftadvanced"

  install -Dm755 "$startdir/tools/wallshift-next" \
    "$pkgdir/usr/bin/wallshift-next"
  install -d "$pkgdir/usr/share/kwin/scripts"
  cp -a "$startdir/tools/kwin-script/io.github.asikeida.wallshiftadvanced.next" \
    "$pkgdir/usr/share/kwin/scripts/io.github.asikeida.wallshiftadvanced.next"
  install -Dm644 "$startdir/tools/systemd/wallshift-next.service" \
    "$pkgdir/usr/lib/systemd/user/wallshift-next.service"

  install -Dm644 "$startdir/LICENSE" \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
