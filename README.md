# asdfcli

Very simple CLI tool to use [asdf](https://asdf-vm.com/), written in Bash

## 💡 Why ?

I find `asdf` quite tedious to use.

Hence I wanted to make it a bit more interactive, using [fzf](https://github.com/junegunn/fzf)

### 🙏 Requested Binaries

- [asdf](https://github.com/asdf-vm/asdf)
- [fzf](https://github.com/junegunn/fzf)

### ✨ Try it out without installing

```bash
source <(curl -s https://raw.githubusercontent.com/rbobillot/asdfcli/refs/heads/main/asdfcli.bash)
```

### 🎬 Demo

![preview](./misc/asdfcli_demo.gif)

### 🚀 Install

To install `asdfcli.bash` and automatically configure your shell,
run the following command in your terminal:

```bash
curl -sL https://raw.githubusercontent.com/rbobillot/asdfcli/refs/heads/main/install.bash | bash
```

### 🗑️ Uninstall

```bash
curl -sL https://raw.githubusercontent.com/rbobillot/asdfcli/refs/heads/main/install.bash | bash -s -- --uninstall
```
