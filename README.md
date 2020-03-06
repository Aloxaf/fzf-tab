# zsh-ls-colors

![Demo screenshot](https://raw.githubusercontent.com/xPMo/zsh-ls-colors/image/demo.png)

A zsh library to use `LS_COLORS` in scripts or other plugins.

For a simple demo, see the `demo` script in this repo.

For more advanced usage,
instructions are located at top of the source files for `from-mode` and `from-name`.
If a use case isn't adequately covered,
please open an issue!

## Using zsh-ls-colors in a plugin

You can use this as a submodule or a subtree.

### submodule:

```sh
# Add (only once)
git submodule add git://github.com/xPMo/zsh-ls-colors.git ls-colors
git commit -m 'Add ls-colors as submodule'

# Update
cd ls-colors
git fetch
git checkout origin/master
cd ..
git commit ls-colors -m 'Update ls-colors to latest'
```

### Subtree:

```sh
# Initial add
git subtree add --prefix=ls-colors/ --squash -m 'Add ls-colors as a subtree' \
	git://github.com/xPMo/zsh-ls-colors.git master

# Update
git subtree pull --prefix=ls-colors/ --squash -m 'Update ls-colors to latest' \
	git://github.com/xPMo/zsh-ls-colors.git master 


# Or, after adding a remote:
git remote add ls-colors git://github.com/xPMo/zsh-ls-colors.git

# Initial add
git subtree add --prefix=ls-colors/ --squash -m 'Add ls-colors as a subtree' ls-colors master

# Update
git subtree pull --prefix=ls-colors/ --squash -m 'Update ls-colors to latest' ls-colors master 
```

### Function namespacing

Since functions are a public namespace,
this plugin allows you to customize the preifix for your plugin:

```zsh
# load functions as my-lscolors::{init,match-by,from-name,from-mode}
source ${0:h}/ls-colors/ls-colors.zsh my-lscolors
```

### Parameter namespacing

While indirect parameter expansion exists with `${(P)var}`,
it doesn't play nicely with array parameters.

There are multiple strategies to prevent unnecessary re-parsing:

```zsh
# Call once when loading.
# Pollutes global namespace but prevents re-parsing
ls-color::init
```

```zsh
# Don't call init at all and only use ::match-by.
# Doesn't pollute global namespace but reparses LS_COLORS on every call
ls-color::match-by $file lstat
```

```zsh
# Initialize within a scope with local parameters.
# Best for not polluting global namespace when multiple filenames need to be parsed.
(){
	local -A namecolors modecolors
	ls-color::init

	for arg; do
		...
	done
}
```

```zsh
# Serialize:
typeset -g LS_COLORS_CACHE_FILE=$(mktemp)
(){
	local -A namecolors modecolors
	ls-color::init
	typeset -p modecolors namecolors >| $LS_COLORS_CACHE_FILE
	zcompile $LS_COLORS_CACHE_FILE
}

my-function(){
	local -A namecolors modecolors
	source $LS_COLORS_CACHE_FILE

	...
}
```

