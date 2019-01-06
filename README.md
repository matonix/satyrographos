# Satyrographos
A naive package manager for SATySFi.

_WARNING: Command line interfaces except for `satyrographos install` are EXPERIMENTAL and subject to change and removal._

It composes files under `~/.opam/<ocaml-version>/share/satysfi/<package>` installed by OPAM and copy them into ``~/.satysfi/dist`.
It also sets up environments so that SATySFi can use system fonts. See Section [Install System Fonts](#Install-System-Fonts).

Satyrographos simplifies installation of SATySFi. For example, @zr-tex8r’s [`make-satysfi.sh`](https://gist.github.com/zr-tex8r/0ab0d24255ecf631692c1f0cbc5ca026) will be like this.

```sh
#!/bin/bash
set -eux

sudo apt -y update
sudo apt -y install build-essential git m4 unzip curl ruby

yes '' | sh <(curl -sL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)

opam init --auto-setup --comp 4.06.0 --disable-sandboxing
eval $(opam env)
opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git
opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git
opam update

# opam pin add https://github.com/na4zagin3/satyrographos.git # run this line if you want to try the latest Satyrographos

opam install -y satysfi
opam install -y satyrographos

satyrographos install
```

If you want to use the latest version, you can pin this repository like this.

```
opam pin add https://github.com/na4zagin3/satyrographos.git
```

## Install System Fonts
_This feature is still experimental and interface would be changed later._

If your machine has configured with [Fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/), i.e., using Mac or Linux Desktop Environment, Satyrographos can configure so that SATySFi can use fonts installed in your system.

You can add `-system-font-prefix <system-font-name-prefix>` option to tell Satyrographos gather system fonts and set up SATySFi sees those font with prefix `<system-font-name-prefix>`.

For example, the following command installs system fonts with prefix `system:`.

```
$ satyrographos install -system-font-prefix 'system:'
```

Then you can use system fonts, for example, Arial as `system:Arial`. (Technically, a font will have a SATySFi name which consists of the given prefix and the font's PostScript name. This behavior would be changed in near future.)

```
@require: stdjabook

let-inline ctx \set-non-cjk-font name it =
  let ctx =
    ctx |> set-font Latin (name, 1., 0.)
        |> set-font OtherScript (name, 1., 0.)
  in
  read-inline ctx it

let-inline ctx \set-cjk-font name it =
  let ctx =
    ctx |> set-font HanIdeographic (name, 1., 0.)
        |> set-font Kana (name, 1., 0.)
  in
  read-inline ctx it
in

document (|
  title = {System Fonts};
  author = {\@na4zagin3};
  show-title = true;
  show-toc = false;
|) '<
  +p {
    ABCDabcd
    \set-non-cjk-font(`system:Tahoma-Bold`){ABCDabcd}
  }
  +p {
    あいうえお漢字
    \set-cjk-font(`system:HiraKakuStd-W8`){あいうえお漢字}
  }
>

```

## How Does It Works?
Satyrographos links all files under `~/.opam/<ocaml-version>/share/satysfi/<package>` and  `~/.satyrographos/packages/<package>` into `~/.satysfi/dist`.

Satyrographos also does duplication detection and hash file merging, `satyrographos install` behaves as
```sh
$ cp -r "$(opam var share)"/share/satysfi/*/* ~/.satysfi/dist
$ cp -r ~/.satyrographos/packages/*/* ~/.satysfi/dist
```

With `-system-font-prefix <system-font-name-prefix>`, Satyrograph query system fonts with `fc-list` and installs those fonts too.

## Register Libraries
You can add a new library for SATySFi as an OPAM library or a directory under `~/.satyrographos`.

In this section, we are going to register a new library `great-package` like this.
```
- ~/src/
  - great-package/
    - hash/
      - fonts.satysfi-hash
    - fonts/
      - interesting-font.ttf
    - packages/
      - your-great.package.satyh
```

### OPAM Package
Create a new package which installs the file into `<prefix>/usr/share/satysfi/great-package/packages/your-great-package.satyh`.

Examples:
- SATySFi-fonts-theano: https://github.com/na4zagin3/SATySFi-fonts-theano
- SATySFi-grcnum: https://github.com/na4zagin3/SATySFi-grcnum

### Local Directory (EXPERIMENTAL)
Register your local library with `satyrographos pin add <local-dir>`.
```
$ satyrographos pin add ~/src/great-package
$ satyrographos install
```
