pkgname=jappeos_installer
pkgver=0.0.8
_tag=dev-v0.0.8
pkgrel=1
pkgdesc="Installer app for JappeOS."
arch=('x86_64')
url="https://github.com/JappeOS/jappeos_installer"
license=('GPL-3.0')
depends=('glibc' 'gtk3')
makedepends=('git' 'clang' 'cmake' 'ninja')
source=("$pkgname-$pkgver.tar.gz::https://github.com/JappeOS/jappeos_installer/archive/refs/tags/$_tag.tar.gz")
sha256sums=('SKIP')

build() {
  cd "$srcdir/$pkgname-$_tag"
  flutter build linux --release
}

package() {
  cd "$srcdir/$pkgname-$_tag/build/linux/x64/release/bundle"

  # Install to /opt
  install -dm755 "$pkgdir/opt/$pkgname"
  cp -r * "$pkgdir/opt/$pkgname"

  # Symlink executable to /usr/bin
  install -dm755 "$pkgdir/usr/bin"
  ln -s "/opt/$pkgname/$pkgname" "$pkgdir/usr/bin/$pkgname"

  # Install desktop entry
  install -Dm644 "$srcdir/$pkgname-$_tag/jappeos-installer.desktop" \
    "$pkgdir/usr/share/applications/jappeos-installer.desktop"
}