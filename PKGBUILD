pkgname=plasma6-wallpapers-wallshift-advanced
pkgver=0.2.0
pkgrel=1
pkgdesc='KDE Plasma 6 wallpaper rotation plugin with editable animated transitions'
arch=('any')
url='https://github.com/asikeida/PlasmaWallShift-Advanced'
license=('GPL-3.0-or-later')
depends=('glib2' 'plasma-workspace' 'qt6-declarative')
optdepends=('kdotool: use the global cursor as the radial transition origin')
makedepends=('qt6-shadertools')

build() {
  make -C "$startdir" all
}

package() {
  install -d "$pkgdir/usr/share/plasma/wallpapers"
  cp -a "$startdir/io.github.asikeida.wallshiftadvanced" \
    "$pkgdir/usr/share/plasma/wallpapers/io.github.asikeida.wallshiftadvanced"

  install -Dm755 "$startdir/io.github.asikeida.wallshiftadvanced/contents/tools/wallshift-next" \
    "$pkgdir/usr/bin/wallshift-next"
  install -Dm644 "$startdir/io.github.asikeida.wallshiftadvanced/contents/tools/io.github.asikeida.wallshiftadvanced.next.desktop" \
    "$pkgdir/usr/share/applications/io.github.asikeida.wallshiftadvanced.next.desktop"

  install -Dm644 "$startdir/LICENSE" \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
